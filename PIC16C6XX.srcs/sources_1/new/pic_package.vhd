----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/26/2019 11:39:16 PM
-- Design Name: 
-- Module Name: pic_package - Behavioral
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

package pic_package is

    -- TODO: break up into separate packages, rename pic_package to pic_defs?
    
    -- TODO: consider subtypes like these...
    constant BITS_PER_BYTE : integer := 8;
    subtype uint4_t is integer range 0 to 15;
    subtype uint8_t is integer range 0 to 255;

    -- clock frequencies
    constant CLK_FREQ : integer := 125000000;   -- Pynq Z2 hardware clock frequency
    constant CLK_PIC_FREQ : integer := 2000000; -- TODO: try power-glitching against different frequencies
    constant CLK_BTN_FREQ : integer := 1000;    -- millisecond resolution
    constant CLK_UART_FREQ : integer := 115200;
 
    -- estimates (truncates any remainder) the number of clock cycles in a given period of time based on the specified clock frequency
    -- NOTE: if clock frequency isn't specified, assumes main driving clock is the target
    function clocksFromTime (
        duration : in time;
        clock_freq_hz : in integer := CLK_FREQ
    ) return integer;
    
    -- pic properties
    constant PIC_COMMAND_WIDTH : integer := 6;
    constant PIC_DATA_WIDTH : integer := 14;
    constant PIC_DATA_READBACK_WIDTH : integer := 16;
    constant PIC_MAX_ADDRESS : integer := 16#2007#;
    -- TODO: pic code size, pic config address, pic config size?
    constant PIC_LOAD_CONFIG_COMMAND : STD_LOGIC_VECTOR (PIC_COMMAND_WIDTH-1 downto 0) := "000000";
    constant PIC_LOAD_DATA_COMMAND : STD_LOGIC_VECTOR (PIC_COMMAND_WIDTH-1 downto 0) := "000010";   -- not implemented
    constant PIC_READ_DATA_COMMAND : STD_LOGIC_VECTOR (PIC_COMMAND_WIDTH-1 downto 0) := "000100"; 
    constant PIC_NEXT_ADDRESS_COMMAND : STD_LOGIC_VECTOR (PIC_COMMAND_WIDTH-1 downto 0) := "000110";
    constant PIC_BEGIN_PROGRAM_COMMAND : STD_LOGIC_VECTOR (PIC_COMMAND_WIDTH-1 downto 0) := "001000";   -- not implemented
    constant PIC_END_PROGRAM_COMMAND : STD_LOGIC_VECTOR (PIC_COMMAND_WIDTH-1 downto 0) := "001110";   -- not implemented
             
    constant VPP_DELAY_CLOCKS : integer := clocksFromTime(12us, CLK_PIC_FREQ);  -- time to wait before enabling vpp
    constant SETUP_DELAY_CLOCKS : integer := clocksFromTime(2us, CLK_PIC_FREQ); -- time to wait after enabling vpp before sending commands
    constant COMMAND_DELAY_CLOCKS : integer := clocksFromTime(1us, CLK_PIC_FREQ);
    constant RESET_CLOCKS : integer := clocksFromTime(10ms, CLK_PIC_FREQ);          -- minimum time to hold reset for
    
    type pic_state is(s_setup, s_idle, s_read_command, s_delay, s_read_data, s_load_config, s_next_address, s_reset);
    type pic_command is(s_none, s_read_data, s_load_config, s_next_address);

    function binary_nibble_to_hex_ascii (
        binary : in integer range 0 to 15
    ) return integer;
    
    COMPONENT pic_uart_fifo
      PORT (
        rst : IN STD_LOGIC;
        wr_clk : IN STD_LOGIC;
        rd_clk : IN STD_LOGIC;
        din : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
        wr_en : IN STD_LOGIC;
        rd_en : IN STD_LOGIC;
        dout : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
        full : OUT STD_LOGIC;
        empty : OUT STD_LOGIC;
        wr_rst_busy : OUT STD_LOGIC;
        rd_rst_busy : OUT STD_LOGIC
      );
    END COMPONENT;
   
    component btn_debounce is
    GENERIC (
        CONSTANT delay : integer := clocksFromTime(20ms, CLK_BTN_FREQ));    -- be sure to pass in a 1KHz clock into the debounce port map
    Port ( clk 		  : in  STD_LOGIC;            -- the input clock
           input 	  : in  STD_LOGIC;            -- the input button signal
           output     : out  STD_LOGIC;           -- the debounced button output signal
           toggle     : inout  STD_LOGIC := '0'); -- the debounced toggle output signal
    end component btn_debounce;
    
    component clock_divider is
    GENERIC (
        CONSTANT clk_freq : integer;  -- the input clock frequency
        CONSTANT target_freq : integer);       -- the target divided clock frequency
        Port (
                clk 		  : in  STD_LOGIC; -- the input clock
                clk_out     : inout  STD_LOGIC := '0');   -- the divided clock output  
    end component clock_divider;

    component dumb_uart_tx is
    Port ( 
        clk : in            STD_LOGIC := '0';
        rst : in            STD_LOGIC := '0';
    
        -- uart signals
        data_in : in        STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
        send_data : in     STD_LOGIC := '0';     -- sends data_in down the tx line when true as long as is_idle is also true at the time
        
        tx : out            STD_LOGIC := '1';   -- uart tx line is high by default
        is_idle : out      STD_LOGIC := '1'
    );
    end component dumb_uart_tx;

    component pic16c6xx is
        Port (
                clk : in            STD_LOGIC := '0';
                rst : in            STD_LOGIC := '0';   

                command: in         pic_command := s_none;

                -- pic signals
                pic_clk : out       STD_LOGIC := '0';
                pic_vdd : out       STD_LOGIC := '0';
                pic_vpp : out       STD_LOGIC := '0';
                pic_data : inout    STD_LOGIC := '0';
                
                data_out : out      STD_LOGIC_VECTOR (PIC_DATA_WIDTH-1 downto 0) := (others => '0');
                data_ready : out    STD_LOGIC := '0';
                
                is_idle : out       STD_LOGIC := '1');
    end component pic16c6xx;
    
end package pic_package;
 
package body pic_package is

    function clocksFromTime (
        duration : in time;
        clock_freq_hz : in integer := CLK_FREQ
    ) return integer is
    begin
        return clock_freq_hz  / (1sec / duration);
    end function clocksFromTime;

    -- TODO: consider working with vectors instead of integers to avoid caller castings   
    function binary_nibble_to_hex_ascii (
        binary : in integer range 0 to 15
    ) return integer is
        variable ascii : integer range 0 to 255;
    begin
    
        -- TODO: more efficient conversion?
        case binary is
            when 0 => ascii := 48;  -- "0"
            when 1 => ascii := 49;  -- "1"
            when 2 => ascii := 50;  -- "2"
            when 3 => ascii := 51;  -- "3"
            when 4 => ascii := 52;  -- "4"
            when 5 => ascii := 53;  -- "5"
            when 6 => ascii := 54;  -- "6"
            when 7 => ascii := 55;  -- "7"
            when 8 => ascii := 56;  -- "8"
            when 9 => ascii := 57;  -- "9"
            when 10 => ascii := 65;  -- "A"
            when 11 => ascii := 66;  -- "B"
            when 12 => ascii := 67;  -- "C"
            when 13 => ascii := 68;  -- "D"
            when 14 => ascii := 69;  -- "E"
            when 15 => ascii := 70;  -- "F"
        end case;
        
        return ascii;
    end function binary_nibble_to_hex_ascii;
    
end package body pic_package;