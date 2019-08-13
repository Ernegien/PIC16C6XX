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

use work.pic_package.all;

-- reference: https://www.ics.uci.edu/~jmoorkan/vhdlref/vhdl.html

entity pic_reader is
    Port ( 
            clk : in    STD_LOGIC := '0';
            rst : in  STD_LOGIC := '0';  -- reset

            -- read control
            btn_two : in   STD_LOGIC := '0';  -- start read (send read command)
            btn_one : in    STD_LOGIC := '0';  -- next address (send next address command)

            -- signals
            pic_vdd : out   STD_LOGIC;
            pic_vpp : out   STD_LOGIC;
            pic_clk : out   STD_LOGIC;
            pic_data : inout    STD_LOGIC := '0';
            uart_tx_data : out  STD_LOGIC := '1'
         );
end pic_reader;

architecture Behavioral of pic_reader is

    signal clk_pic, clk_btn, clk_uart : std_logic := '0';
    signal readCommandRequest, nextAddressCommandRequest, reset : std_logic := '0';

    -- pic state 
    signal current_command : pic_command := s_none;
    signal pic_data_ready : std_logic := '0';   -- indicates data is ready to be read from the pic
    signal pic_data_word : STD_LOGIC_VECTOR (PIC_DATA_WIDTH-1 downto 0) := (others => '0');
    signal pic_is_idle : std_logic := '1';
    
    -- uart state
    signal uart_data_in : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
    signal uart_send_data : std_logic := '0';
    signal uart_is_idle : std_logic := '1';

    -- pic->uart fifo state
    signal fifo_empty : std_logic := '1';
    signal fifo_read_en : std_logic := '0';
    signal fifo_data_out : STD_LOGIC_VECTOR (PIC_DATA_WIDTH-1 downto 0) := (others => '0');
    signal fifo_full : std_logic := '0';

begin

    pic_driver: process
        variable readCommandSent, nextAddressCommandSent : boolean := false;
        begin
            wait until rising_edge(clk_pic);
                
                -- don't send read command if fifo_full
                if fifo_full = '0' then
                
                    -- only read once per button press
                    if readCommandRequest = '1' and not readCommandSent then
                        current_command <= s_read_data;
                    end if; 
                    readCommandSent := readCommandRequest = '1';   
                                 
                end if;

                -- only increment once per button press
                if nextAddressCommandRequest = '1' and not nextAddressCommandSent then
                    current_command <= s_next_address;
                end if;
                nextAddressCommandSent := nextAddressCommandRequest = '1';
                
                -- reset any command requests
                if current_command /= s_none then
                    current_command <= s_none;
                end if;

                -- NOTE: when pic_data_ready is set after a read command the outputted pic_data_word is automatically sent to the FIFO

                -- TODO: automate power glitch attack

    end process;

    -- TODO: eliminate magic numbers and clean everything up
    -- extracts data from fifo, converts to ascii hex, and sends out via uart
    uart_driver: process
    
            type uart_driver_state is(s_idle, s_send_byte, s_wait);
            variable nibbleCounter : integer range 0 to 4 := 0;
            variable state : uart_driver_state := s_idle;
            
        begin
            wait until rising_edge(clk_uart);

            -- defaults unless specified
            uart_send_data <= '0';
            fifo_read_en <= '0';
            
            case state is
            
                when s_idle =>

                    nibbleCounter := 0;
                        
                    -- read from fifo if data available
                    if fifo_empty = '0' then
                        fifo_read_en <= '1';
                        state := s_wait;
                    end if;

                when s_send_byte => -- data available in data_buffer from fifo to be sent out via uart
                
                    -- defaults unless otherwise specified
                    uart_send_data <= '1';  -- request uart send
                    state := s_wait;
                    
                    case nibbleCounter is
                    
                        when 0 =>
                            uart_data_in <= std_logic_vector(to_unsigned(binary_nibble_to_hex_ascii(to_integer(unsigned(fifo_data_out(13 downto 12)))), 8));
                        when 1 =>
                            uart_data_in <= std_logic_vector(to_unsigned(binary_nibble_to_hex_ascii(to_integer(unsigned(fifo_data_out(11 downto 8)))), 8));
                        when 2 =>
                            uart_data_in <= std_logic_vector(to_unsigned(binary_nibble_to_hex_ascii(to_integer(unsigned(fifo_data_out(7 downto 4)))), 8));
                        when 3 =>
                            uart_data_in <= std_logic_vector(to_unsigned(binary_nibble_to_hex_ascii(to_integer(unsigned(fifo_data_out(3 downto 0)))), 8));
                        when others =>
                            state := s_idle;
                            uart_send_data <= '0';
                    end case;

                    nibbleCounter := nibbleCounter + 1;

                when s_wait =>
                
                     if uart_is_idle = '1' and uart_send_data = '0' then
                        state := s_send_byte;
                     end if;

            end case;

    end process;

    pic_clk_out: clock_divider
        generic map (
            clk_freq => CLK_FREQ,
            target_freq => CLK_PIC_FREQ
        ) 
        port map (
            clk => clk,
            clk_out => clk_pic
        );
        
    btn_clk_out: clock_divider
        generic map (
            clk_freq => CLK_FREQ,
            target_freq => CLK_BTN_FREQ
        )
        port map (
            clk => clk,
            clk_out => clk_btn
        );
        
    uart_clk_out: clock_divider
        generic map (
            clk_freq => CLK_FREQ,
            target_freq => CLK_UART_FREQ
        )
        port map (
            clk => clk,
            clk_out => clk_uart
        );
    
    btn3_toggle: btn_debounce
        port map (
            clk => clk_btn,
            input => rst,
            output => OPEN,
            toggle => reset
        );
        
    btn2_out: btn_debounce
        port map (
            clk => clk_btn,
            input => btn_two,
            output => readCommandRequest,
            toggle => OPEN
        );
        
    btn1_out: btn_debounce
        port map (
            clk => clk_btn,
            input => btn_one,
            output => nextAddressCommandRequest,
            toggle => OPEN
        );
        
    uart_tx: dumb_uart_tx
        port map (
            clk => clk_uart,
            rst => rst,
            data_in => uart_data_in,
            send_data => uart_send_data,  
            tx => uart_tx_data,
            is_idle => uart_is_idle
        );

    pic_devce: pic16c6xx
        port map (
            clk => clk_pic,
            rst => reset, 
            command => current_command, 
            pic_clk => pic_clk,
            pic_vdd => pic_vdd, 
            pic_vpp => pic_vpp, 
            pic_data => pic_data, 
            data_out => pic_data_word,
            data_ready => pic_data_ready,
            is_idle => pic_is_idle
        );
    
    -- TODO: use simpler open-source MIT-compatible FIFO
    pic_serial_out : pic_uart_fifo
      PORT MAP (
        rst => rst,
        wr_clk => clk_pic,
        rd_clk => clk_uart,
        din => pic_data_word,       -- Data Input: The input data bus used when writing the FIFO.
        wr_en => pic_data_ready,    -- Write Enable: If the FIFO is not full, asserting this signal causes data (on din) to be written to the FIFO
        rd_en => fifo_read_en,  -- Read Enable: If the FIFO is not empty, asserting this signal causes data to be read from the FIFO (output on dout)
        dout => fifo_data_out,  -- Data Output: The output data bus is driven when reading the FIFO.
        full => fifo_full,
        empty => fifo_empty,   -- Empty Flag: When asserted, this signal indicates that the FIFO is empty. Read requests are ignored when the FIFO is empty, initiating a read while empty is not destructive to the FIFO.
        wr_rst_busy => OPEN,
        rd_rst_busy => OPEN
      );

end Behavioral;
