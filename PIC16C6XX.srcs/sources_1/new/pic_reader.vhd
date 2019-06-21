----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/12/2019 05:32:46 PM
-- Design Name: 
-- Module Name: pic_reader - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

-- reference: https://www.ics.uci.edu/~jmoorkan/vhdlref/vhdl.html

entity pic_reader is
    Port ( 
            clk : in    STD_LOGIC := '0';

            -- status output
            led_three :   out     STD_LOGIC;  -- programming mode activated
            
            -- read control
            btn_three : in  STD_LOGIC := '0';  -- toggle programming mode
            btn_two : in   STD_LOGIC := '0';  -- start read (send read command)
            btn_one : in    STD_LOGIC := '0';  -- next address (send next address command)

            -- signals
            pic_vdd : out   STD_LOGIC;
            pic_vpp : out   STD_LOGIC;
            pic_clk : out   STD_LOGIC;
            pic_data : inout    STD_LOGIC := '0'
         );
end pic_reader;

architecture Behavioral of pic_reader is

    constant clk_freq : integer := 125000000;   -- Pynq Z2 hardware clock frequency
    constant clk_pic_freq : integer := 2000000; -- TODO: try power-glitching against different frequencies
    constant clk_btn_freq : integer := 1000;    -- millisecond resolution
    constant clk_uart_freq : integer := 115200;
    
    -- estimates (truncates any remainder) the number of clock cycles in a given period of time based on the specified clock frequency
    -- NOTE: if clock frequency isn't specified, assumes main driving clock is the target
    function clocksFromTime (
        duration : in time;
        clock_freq_hz : in integer := clk_freq
    ) return integer is
    begin
        return clock_freq_hz  / (1sec / duration);
    end function clocksFromTime;
    
    signal clk_pic, clk_btn, clk_uart : std_logic := '0';

    signal vddEnabled, vppEnabled : std_logic := '0';   -- power states, TODO: vddReady (initially true, set to false until disabled for a certain period of time to give the chip time to power down entirely before it can be powered on again)    

    signal readCommandRequest, nextAddressCommandRequest : std_logic := '0';
    signal programmingAddress : integer range 0 to 16#2007# := 0;   -- 14-bit word index
    
    signal picClockOutputEnabled : std_logic := '0';
    signal pic_data_buffered : STD_LOGIC := '0';
    signal read_ready : std_logic := '0';   -- indicates whether or not data is ready to be read
    -- TODO: data_available to indicate ready to be sent via uart
            
    component btn_debounce is
    GENERIC (
        CONSTANT delay : integer := clocksFromTime(20ms, clk_btn_freq));    -- be sure to pass in a 1KHz clock into the debounce port map
    Port ( clk 		  : in  STD_LOGIC;            -- the input clock
           input 	  : in  STD_LOGIC;            -- the input button signal
           output     : out  STD_LOGIC;           -- the debounced button output signal
           toggle     : inout  STD_LOGIC := '0'); -- the debounced toggle output signal
    end component btn_debounce;
    
    component clock_divider is
    GENERIC (
        CONSTANT clk_freq : integer;  -- the input clock frequency
        CONSTANT target_freq : integer);       -- the target divided clock frequency
        Port ( clk 		  : in  STD_LOGIC; -- the input clock
               clk_out     : inout  STD_LOGIC := '0');   -- the divided clock output  
    end component clock_divider;

    constant DATA_WIDTH : integer := 14;
    signal data : STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0) := (others => '0');

begin

    process
    
        constant PIC_COMMAND_WIDTH : integer := 6;
        constant PIC_LOAD_DATA_COMMAND : STD_LOGIC_VECTOR (PIC_COMMAND_WIDTH-1 downto 0) := "000010";
        constant PIC_READ_DATA_COMMAND : STD_LOGIC_VECTOR (PIC_COMMAND_WIDTH-1 downto 0) := "000100"; 
        constant PIC_NEXT_ADDRESS_COMMAND : STD_LOGIC_VECTOR (PIC_COMMAND_WIDTH-1 downto 0) := "000110";
                    
        constant VPP_DELAY_CLOCKS : integer := clocksFromTime(12us, clk_pic_freq);  -- time to wait before enabling vpp
        constant SETUP_DELAY_CLOCKS : integer := clocksFromTime(2us, clk_pic_freq); -- time to wait after enabling vpp before sending commands
        constant COMMAND_DELAY_CLOCKS : integer := clocksFromTime(1us, clk_pic_freq);
        
        variable commandCounter : integer range 0 to PIC_COMMAND_WIDTH := 0;
        variable vppDelayCounter : integer range 0 to VPP_DELAY_CLOCKS := 0;
        variable setupDelayCounter : integer range 0 to SETUP_DELAY_CLOCKS := 0;
        variable delayCounter : integer range 0 to COMMAND_DELAY_CLOCKS := 0;
        
        constant readDataWidth : integer := 16;
        variable readDataCounter : integer range 0 to readDataWidth := 0;

        type state is(s_setup, s_idle, s_read_command, s_delay, s_read_data, s_next_address, s_reset);
        variable current_state, next_state : state := s_setup;

        variable readCommandSent, nextAddressCommandSent : boolean := false;

    begin
        wait until rising_edge(clk_pic);

        -- defaults unless otherwise specified
        pic_data_buffered <= 'Z';
        picClockOutputEnabled <= '0';
        read_ready <= '0';

        case current_state is
        
            when s_setup =>

                -- wait to enable vpp
                if vddEnabled = '1' and vppEnabled = '0' then
                    if vppDelayCounter = VPP_DELAY_CLOCKS then
                        vppEnabled <= '1';
                        vppDelayCounter := 0;
                    else
                        vppDelayCounter := vppDelayCounter + 1;
                    end if;
                end if;
                
                -- wait to release drive on data line
                if vppEnabled = '1' then
                    if setupDelayCounter = SETUP_DELAY_CLOCKS then
                        current_state := s_idle;
                        setupDelayCounter := 0;
                    else
                        setupDelayCounter := setupDelayCounter + 1;
                    end if;                     
                end if;

                -- drive clock (defaulted in process start) and data low
                pic_data_buffered <= '0';
             
            when s_read_command =>
            
                if commandCounter = PIC_COMMAND_WIDTH then
                    commandCounter := 0;
                    current_state := s_delay;
                    next_state := s_read_data;
                else
                    pic_data_buffered <= PIC_READ_DATA_COMMAND(commandCounter);
                    picClockOutputEnabled <= '1';
                    commandCounter := commandCounter + 1;
                end if;

            when s_read_data =>

                if readDataCounter = 0 then
                    picClockOutputEnabled <= '1';
                    readDataCounter := readDataCounter + 1;           
                elsif readDataCounter = readDataWidth - 1 then
                    picClockOutputEnabled <= '1';
                    pic_data_buffered <= '0';   -- prevents data line from bounching after PIC goes into high impedence mode
                    readDataCounter := readDataCounter + 1;
                elsif readDataCounter = readDataWidth then
                    readDataCounter := 0;
                    current_state := s_idle;            
                else
                    read_ready <= '1';
                    picClockOutputEnabled <= '1';
                    readDataCounter := readDataCounter + 1;
                end if;

            when s_next_address =>
            
                -- TODO: verify next address is valid? (0-0xFFF for 4K flashes, 0x2000-0x2007)
            
                if commandCounter = PIC_COMMAND_WIDTH then
                    commandCounter := 0;
                    programmingAddress <= programmingAddress + 1;
                    current_state := s_delay;
                    next_state := s_idle; 
                else
                    pic_data_buffered <= PIC_NEXT_ADDRESS_COMMAND(commandCounter);
                    picClockOutputEnabled <= '1';
                    commandCounter := commandCounter + 1;
                end if;
            
            -- 2us target
            when s_delay =>
            
                if delayCounter = COMMAND_DELAY_CLOCKS then
                    delayCounter := 0;
                    current_state := next_state;
                else
                    delayCounter := delayCounter + 1;
                end if;
    
            -- listen for state change requests
            when s_idle =>
            
                -- only read once per button press
                if readCommandRequest = '1' and not readCommandSent then
                    current_state := s_read_command;
                end if; 
                readCommandSent := readCommandRequest = '1';
                
                -- only increment once per button press
                if nextAddressCommandRequest = '1' and not nextAddressCommandSent then
                    current_state := s_next_address;
                end if;
                nextAddressCommandSent := nextAddressCommandRequest = '1';
                
            when s_reset =>    
                vppEnabled <= '0';
                current_state := s_setup;
                programmingAddress <= 0;
        end case;

        -- reset if powered off
        if not vddEnabled = '1' and current_state /= s_setup then
            current_state := s_reset;
        end if;

    end process;
    
    -- reads pic data if it's ready to be received
    process
            variable dataCounter : integer range 0 to DATA_WIDTH := 0;
        begin

            wait until falling_edge(clk_pic);

            if read_ready = '0' or dataCounter = DATA_WIDTH then
                dataCounter := 0;
            else
                -- TODO: read directly into uart? should probably run uart at full clock speed and divide inside for target baud rate
                data(dataCounter) <= '1';   -- pic_data
                dataCounter := dataCounter + 1;
            end if;
            
            -- TODO: set another state signal when data (byte) is ready to be sent via uart
            
    end process;

    -- TODO: uart tx
    process
    
        begin
            wait until rising_edge(clk_uart);


    end process;

    -- TODO: automated driver process
    
    -- map buttons to debounced output signals
    btn3_toggle: btn_debounce port map (clk=>clk_btn, input=>btn_three, output=>OPEN, toggle=>vddEnabled);
    btn2_out: btn_debounce port map (clk=>clk_btn, input=>btn_two, output=>readCommandRequest, toggle=>OPEN);
    btn1_out: btn_debounce port map (clk=>clk_btn, input=>btn_one, output=>nextAddressCommandRequest, toggle=>OPEN);
    
    -- TODO: externalize component definitions into packages and use them up top
    --btn3_toggle: btn_debounce generic map ( 1 ) port map (clk_btn, btn_three, OPEN, vddEnabled);
    
    pic_clk_out: clock_divider generic map(clk_freq => clk_freq, target_freq=>clk_pic_freq) port map(clk=>clk, clk_out=>clk_pic);
    btn_clk_out: clock_divider generic map(clk_freq=>clk_freq, target_freq=>clk_btn_freq) port map(clk=>clk, clk_out=>clk_btn);
    uart_clk_out: clock_divider generic map(clk_freq=>clk_freq, target_freq=>clk_uart_freq) port map(clk=>clk, clk_out=>clk_uart);

    -- output signal drivers
    pic_vdd <= vddEnabled;
    pic_vpp <= vppEnabled;  -- TODO: external mosfet driving VDD+4.5V for actual VPP
    led_three <= vppEnabled; 
    pic_clk <= clk_pic when picClockOutputEnabled = '1' else '0';
    pic_data <= pic_data_buffered;

end Behavioral;