----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/20/2019 10:58:10 PM
-- Design Name: 
-- Module Name: pic16c6xx - Behavioral
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

use work.pic_package.all;

-- assumes it's always powered on except during setup state (during init or reset)

-- https://web.archive.org/web/20190728230058/http://ww1.microchip.com/downloads/en/DeviceDoc/30605D.pdf
entity pic16c6xx is
Port ( 
    clk : in            STD_LOGIC := '0';
    rst : in            STD_LOGIC := '0';   

    command : in        pic_command := s_none;

    -- pic signals
    pic_clk : out       STD_LOGIC := '0';
    pic_vdd : out       STD_LOGIC := '0';
    pic_vpp : out       STD_LOGIC := '0';
    pic_data : inout    STD_LOGIC := '0'
    
    -- TODO: should this be the caller's responsibility? will probably be easier to just internalize it...
    -- data output from a read_data command
    --data : out          STD_LOGIC_VECTOR (14-1 downto 0) := (others => '0'); -- TODO: DATA_WIDTH constant via package import
    --data_available : out STD_LOGIC := '0'
);
end pic16c6xx;

architecture Behavioral of pic16c6xx is
    
    signal vddEnabled, vppEnabled : std_logic := '0';   -- power states, TODO: vddReady (initially true, set to false until disabled for a certain period of time to give the chip time to power down entirely before it can be powered on again)    

    signal readCommandRequest, nextAddressCommandRequest : std_logic := '0';
    signal programmingAddress : integer range 0 to 16#2007# := 0;   -- 14-bit word index
    
    signal picClockOutputEnabled : std_logic := '0';
    signal pic_data_buffered : STD_LOGIC := '0';
    signal read_ready : std_logic := '0';   -- indicates whether or not data is ready to be read
    -- TODO: data_available to indicate ready to be sent via uart
            
    signal data : STD_LOGIC_VECTOR (PIC_DATA_WIDTH-1 downto 0) := (others => '0');    
    
    shared variable current_state, next_state : pic_state := s_setup;

begin

    -- controls the pic state
    pic_state_machine: process

        variable commandCounter : integer range 0 to PIC_COMMAND_WIDTH := 0;
        variable vppDelayCounter : integer range 0 to VPP_DELAY_CLOCKS := 0;
        variable setupDelayCounter : integer range 0 to SETUP_DELAY_CLOCKS := 0;
        variable delayCounter : integer range 0 to COMMAND_DELAY_CLOCKS := 0;
        variable readDataCounter : integer range 0 to PIC_DATA_READBACK_WIDTH := 0;
        variable readCommandSent, nextAddressCommandSent : boolean := false;

        begin
            wait until rising_edge(clk);

            -- synchronous reset
            if rst = '1' then
                current_state := s_reset;
            end if;

            -- defaults unless otherwise specified
            pic_data_buffered <= 'Z';
            picClockOutputEnabled <= '0';
            read_ready <= '0';
    
            case current_state is
            
                when s_setup =>
    
                    if vppEnabled = '0' then
                    
                        -- wait to enable vpp
                        if vppDelayCounter = VPP_DELAY_CLOCKS then
                            vppEnabled <= '1';
                            vppDelayCounter := 0;
                        else
                            vppDelayCounter := vppDelayCounter + 1;
                        end if;
                        
                    else
                    
                        -- wait to release drive on data line
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
    
                -- data is returned by clocking 16 cycles (start bit, 14-bits of data, stop bit)
                when s_read_data =>
    
                    if readDataCounter = 0 then
                        picClockOutputEnabled <= '1';
                        readDataCounter := readDataCounter + 1;           
                    elsif readDataCounter = PIC_DATA_READBACK_WIDTH - 1 then
                        picClockOutputEnabled <= '1';
                        pic_data_buffered <= '0';   -- prevents data line from bounching after PIC goes into high impedence mode
                        readDataCounter := readDataCounter + 1;
                    elsif readDataCounter = PIC_DATA_READBACK_WIDTH then
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
                
                when s_delay =>
                
                    if delayCounter = COMMAND_DELAY_CLOCKS then
                        delayCounter := 0;
                        current_state := next_state;
                    else
                        delayCounter := delayCounter + 1;
                    end if;
        
                -- listen for state change requests
                when s_idle =>
                
                    case command is
                        when s_read_data =>
                            current_state := s_read_command;  
                        when s_next_address =>
                            current_state := s_next_address;
                        when s_none =>
                            -- don't change state
                    end case;
                    
                when s_reset =>    
                    vppEnabled <= '0';
                    current_state := s_setup;
                    programmingAddress <= 0;
            end case;

    end process;

    -- reads pic data if it's ready to be received
    process
            variable dataCounter : integer range 0 to PIC_DATA_WIDTH := 0;
        begin

            wait until falling_edge(clk);

            if read_ready = '0' or dataCounter = PIC_DATA_WIDTH then
                dataCounter := 0;
            else
                -- TODO: read directly into uart? should probably run uart at full clock speed and divide inside for target baud rate
                data(dataCounter) <= '1';   -- pic_data
                dataCounter := dataCounter + 1;
            end if;
            
            -- TODO: set another state signal when data (byte) is ready to be sent via uart
            
    end process;

    -- output signal drivers
    pic_vdd <= not rst;
    pic_vpp <= vppEnabled;  -- TODO: external mosfet driving VDD+4.5V for actual VPP
    pic_clk <= clk when picClockOutputEnabled = '1' else '0';
    pic_data <= pic_data_buffered;

end Behavioral;
