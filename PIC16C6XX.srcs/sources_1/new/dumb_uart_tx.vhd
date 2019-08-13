----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/20/2019 09:28:37 PM
-- Design Name: 
-- Module Name: dumb_uart_tx - Behavioral
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

use work.pic_package.all;

-- TODO: rename to basic_uart_tx or something

-- 8 data bits, 1 stop bit, no parity
entity dumb_uart_tx is
Port ( 
    clk : in            STD_LOGIC := '0';
    rst : in            STD_LOGIC := '0';

    -- uart signals
    data_in : in        STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
    send_data : in     STD_LOGIC := '0';     -- sends data_in down the tx line when true and in an idle state
    
    tx : out            STD_LOGIC := '1';   -- uart tx line is high by default
    is_idle : out      STD_LOGIC := '1'
);
end dumb_uart_tx;

architecture Behavioral of dumb_uart_tx is
  
    type uart_state is(s_start, s_data, s_stop, s_idle);
    signal state : uart_state := s_idle;
    
begin

    uart_state_machine: process
        constant UART_DATA_WIDTH : integer := 8;
        variable data_counter : integer range 0 to UART_DATA_WIDTH := 0;
    begin
        wait until rising_edge(clk);
    
        -- synchronous reset
        if rst = '1' then
            state <= s_idle;
        end if;
    
        -- default idle state is tied high
        tx <= '1';

        case state is
        
            when s_start =>
                tx <= '0';
                state <= s_data;
                
            when s_data =>

                if data_counter = UART_DATA_WIDTH then
                    state <= s_stop;
                else
                    tx <= data_in(data_counter);
                    data_counter := data_counter + 1;
                end if;
                
            when s_stop =>
                state <= s_idle;

            when s_idle =>
                data_counter := 0;
                
                if send_data = '1' then
                    state <= s_start;
                end if;
                
        end case;

    end process;
    
    is_idle <= '1' when state = s_idle else '0';
    
end Behavioral;
