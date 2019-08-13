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

-- assumes it's always powered on except during reset state

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
    pic_data : inout    STD_LOGIC := '0';
    
    data_out : out      STD_LOGIC_VECTOR (PIC_DATA_WIDTH-1 downto 0) := (others => '0');
    data_ready : out    STD_LOGIC := '0';    -- indicates data_out ready to be read
    
    is_idle : out       STD_LOGIC := '1'
);
end pic16c6xx;

architecture Behavioral of pic16c6xx is
    
    signal vppEnabled : std_logic := '0';

    signal readCommandRequest, nextAddressCommandRequest : std_logic := '0';
    
    --pragma synthesis_off
      signal programmingAddress : integer range 0 to PIC_MAX_ADDRESS := 0;   -- 14-bit word index
    --pragma synthesis_on
    
    signal picClockOutputEnabled : std_logic := '0';
    signal pic_data_buffered : STD_LOGIC := '0';
    
    shared variable current_state, next_state : pic_state := s_setup;
begin

    -- controls the pic state
    pic_state_machine: process

        variable commandCounter : integer range 0 to PIC_COMMAND_WIDTH := 0;
        variable vppDelayCounter : integer range 0 to VPP_DELAY_CLOCKS := 0;
        variable setupDelayCounter : integer range 0 to SETUP_DELAY_CLOCKS := 0;
        variable delayCounter : integer range 0 to COMMAND_DELAY_CLOCKS := 0;
        variable readDataCounter : integer range 0 to PIC_DATA_READBACK_WIDTH := 0;
        variable resetCounter : integer range 0 to RESET_CLOCKS := 0;
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
            data_ready <= '0';
    
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
                        data_ready <= '1';  -- inform upstream data can be read the next cycle            
                    else
                        data_out(readDataCounter - 1) <= pic_data;  -- TODO: verify proper indexing

                        --pragma synthesis_off
                          data_out(readDataCounter - 1) <= '1'; -- used for testing only
                        --pragma synthesis_on

                        picClockOutputEnabled <= '1';
                        readDataCounter := readDataCounter + 1;
                    end if;
    
                when s_load_config =>
                
                    -- TODO: use to test chip readback in protected mode, the config is always unprotected - if that fails then it's time to reset the chip
                
                when s_next_address =>
                
                    -- TODO: verify next address is valid? (0-0xFFF for 4K flashes, 0x2000-0x2007)  PIC_MAX_ADDRESS
                
                    if commandCounter = PIC_COMMAND_WIDTH then
                        commandCounter := 0;
                        
                        --pragma synthesis_off
                          programmingAddress <= programmingAddress + 1;
                        --pragma synthesis_on  

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
                        when others =>
                            -- don't change state
                    end case;
                    
                when s_reset =>    
                
                    -- hold reset state for at least 10ms before continuing with setup to give the chip enough time to fully discharge
                    if resetCounter = RESET_CLOCKS then
                        resetCounter := 0;
                        current_state := s_setup;
                                            
                        --pragma synthesis_off
                          programmingAddress <= 0;
                        --pragma synthesis_on                     
                    else
                        resetCounter := resetCounter + 1;
                    end if;
                
                    vppEnabled <= '0';

            end case;

    end process;

    -- output signal drivers
    pic_vdd <= not rst;
    pic_vpp <= vppEnabled;  -- TODO: external mosfet driving VDD+4.5V for actual VPP
    pic_clk <= clk when picClockOutputEnabled = '1' else '0';
    pic_data <= pic_data_buffered;

    is_idle <= '1' when current_state = s_idle else '0';

end Behavioral;
