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
    constant PIC_LOAD_DATA_COMMAND : STD_LOGIC_VECTOR (PIC_COMMAND_WIDTH-1 downto 0) := "000010";
    constant PIC_READ_DATA_COMMAND : STD_LOGIC_VECTOR (PIC_COMMAND_WIDTH-1 downto 0) := "000100"; 
    constant PIC_NEXT_ADDRESS_COMMAND : STD_LOGIC_VECTOR (PIC_COMMAND_WIDTH-1 downto 0) := "000110";
             
    constant VPP_DELAY_CLOCKS : integer := clocksFromTime(12us, CLK_PIC_FREQ);  -- time to wait before enabling vpp
    constant SETUP_DELAY_CLOCKS : integer := clocksFromTime(2us, CLK_PIC_FREQ); -- time to wait after enabling vpp before sending commands
    constant COMMAND_DELAY_CLOCKS : integer := clocksFromTime(1us, CLK_PIC_FREQ);
    
    type pic_state is(s_setup, s_idle, s_read_command, s_delay, s_read_data, s_next_address, s_reset);
    type pic_command is(s_none, s_read_data, s_next_address);
  
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
                
                data_ready : out    STD_LOGIC := '0');
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
    
end package body pic_package;