library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart is
port (
  clk    : in  std_logic;
  reset  : in  std_logic;
  strobe : in  std_logic;
  byte0  : in  std_logic_vector( 7 downto 0 );
  byte1  : in  std_logic_vector( 7 downto 0 );
  byte2  : in  std_logic_vector( 7 downto 0 );
  byte3  : in  std_logic_vector( 7 downto 0 );
  byte4  : in  std_logic_vector( 7 downto 0 );
  byte5  : in  std_logic_vector( 7 downto 0 );
  txd    : out std_logic
  );
end entity uart;

-- 100M/9600baud = 10416 = 'h28b0 this is the number of clock cycles for
-- which a bit is held on the serial line.
--
-- a single byte is sent serially as 10 bits (1 start, 8 data, 1 stop)
-- 10 bits are transmitted in 10417*10 clocks
-- 100 MHz / 104170 = 960 bytes/sec = 240 dwords/sec
-- i.e. a new dword can be loaded in every 1/240 sec = 4.1 ms

-- as long as the input data rate does not exceed 1 dword in 4.1 ms, the
-- serial port will be fast enough

architecture rtl of uart is

signal busy_r0      : std_logic;
signal tx_data_r    : std_logic_vector( 58 downto 0 );
signal bit_timer_r0 : unsigned( 13 downto 0 );
signal bit_count_r0 : unsigned( 5 downto 0 );

constant BAUD_9600  : unsigned( 13 downto 0 ) := "10" & X"8b0";

begin

   p_serial_tx_r: process( clk, reset )
   begin
      if reset = '1' then
         busy_r0      <= '0';
         tx_data_r    <= (others => '1'); -- drive the output high
         bit_timer_r0 <= (others => '0');
         bit_count_r0 <= (others => '0');

      elsif rising_edge( clk ) then

         if busy_r0 = '0' then

            if strobe = '1' then
               busy_r0      <= '1';
               tx_data_r    <= byte5 & "01" & byte4 & "01" & byte3 & "01" & byte2 & "01" & byte1 & "01" & byte0 & '0';
               bit_timer_r0 <= BAUD_9600;
               bit_count_r0 <= "111011"; -- 60 - 1
            end if;

         else
            if bit_timer_r0 = 0 then -- current bit is done

               -- shift the byte out LSB first - i.e. right shift
               tx_data_r    <= '1' & tx_data_r( tx_data_r'high downto 1 );
               bit_timer_r0 <= BAUD_9600;

               if bit_count_r0 = 0 then -- 60th bit has been sent

                  busy_r0      <= '0';
               else
                  bit_count_r0 <= bit_count_r0 - 1;

               end if;
            else
               bit_timer_r0 <= bit_timer_r0 - 1;
            end if;

         end if;
      end if;
   end process p_serial_tx_r;

   txd <= tx_data_r( 0 );

end rtl;
