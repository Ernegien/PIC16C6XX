----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/24/2019 12:46:30 AM
-- Design Name: 
-- Module Name: clock_divider - Behavioral
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

entity clock_divider is
GENERIC (
	CONSTANT clk_freq : integer;  -- the input clock frequency
	CONSTANT target_freq : integer);       -- the target divided clock frequency
    Port ( clk 		  : in  STD_LOGIC; -- the input clock
           clk_out     : inout  STD_LOGIC := '0');   -- the divided clock output  
end clock_divider;

architecture Behavioral of clock_divider is
begin

	process
	   constant divider : integer := (clk_freq / target_freq) / 2;  -- the clock divider
	   variable counter : integer range 0 to divider := divider;   -- sets range and counter max as optimizations
	begin
        wait until rising_edge(clk);
    
        if (counter = divider) then
            clk_out <= not clk_out;
            counter := 1;
        else
            counter := counter + 1;
        end if;
    end process;

end Behavioral;
