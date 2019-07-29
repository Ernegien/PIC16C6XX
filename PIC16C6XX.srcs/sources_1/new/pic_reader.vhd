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

use work.pic_package.all;

-- reference: https://www.ics.uci.edu/~jmoorkan/vhdlref/vhdl.html

entity pic_reader is
    Port ( 
            clk : in    STD_LOGIC := '0';

            -- read control
            btn_three : in  STD_LOGIC := '0';  -- reset
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

    signal clk_pic, clk_btn, clk_uart : std_logic := '0';
    signal readCommandRequest, nextAddressCommandRequest, reset : std_logic := '0';
    signal current_command : pic_command := s_none;
    
begin

    -- pic commands
    process
        variable readCommandSent, nextAddressCommandSent : boolean := false;
        begin
            wait until rising_edge(clk_pic);
                
                -- only read once per button press
                if readCommandRequest = '1' and not readCommandSent then
                    current_command <= s_read_data;
                end if; 
                readCommandSent := readCommandRequest = '1';
                
                -- only increment once per button press
                if nextAddressCommandRequest = '1' and not nextAddressCommandSent then
                    current_command <= s_next_address;
                end if;
                nextAddressCommandSent := nextAddressCommandRequest = '1';
                
                if current_command /= s_none then
                    current_command <= s_none;
                end if;
                
    end process;

    -- TODO: uart tx
    process
    
        begin
            wait until rising_edge(clk_uart);


    end process;

    pic_clk_out: clock_divider
        generic map(CLK_FREQ => CLK_FREQ, target_freq => CLK_PIC_FREQ) 
        port map(clk => clk, clk_out => clk_pic);
        
    btn_clk_out: clock_divider
        generic map(CLK_FREQ => CLK_FREQ, target_freq => CLK_BTN_FREQ)
        port map(clk => clk, clk_out => clk_btn);
        
    uart_clk_out: clock_divider
        generic map(CLK_FREQ => CLK_FREQ, target_freq => CLK_UART_FREQ)
        port map(clk => clk, clk_out => clk_uart);
    
    btn3_toggle: btn_debounce
        port map (clk_btn, btn_three, OPEN, reset);
        
    btn2_out: btn_debounce
        port map (clk_btn, btn_two, readCommandRequest, OPEN);
        
    btn1_out: btn_debounce
        port map (clk_btn, btn_one, nextAddressCommandRequest, OPEN);

    pic_test: pic16c6xx
        port map (clk_pic, reset, current_command, pic_clk, pic_vdd, pic_vpp, pic_data);

end Behavioral;
