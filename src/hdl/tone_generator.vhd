library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tone_generator is
port (
  clk         : in  std_logic; -- 100 MHz
  reset       : in  std_logic;
  strobe250ms : out std_logic;
  test_tone   : out std_logic
  );
end entity tone_generator;

-- the 100 MHz input clock is divided down to 60 Hz
-- 60 then readily divides to give 5, 10, 15 and 20 Hz outputs

-- 60 Hz corresponds to a period of 16.67 ms
-- 16.67 ms/10 ns = 16.67/10 * 1e-3/1e-9 = 1.667 Mclocks @ 100 MHz
-- 1666667 - 1 = 'h196e6a

-- the single clock sampling strobe of 4 times/sec is generated every 250 ms
--    250 ms / 16.67 ms = 15 clocks

architecture rtl of tone_generator is

  signal counter60Hz_r0 : unsigned( 20 downto 0 );
  constant SIXTEENMS    : unsigned( 20 downto 0 ) := '1' & X"96e6a";

  signal counter4Hz_r0  : unsigned( 3 downto 0 );
  constant TICKS15      : unsigned( 3 downto 0 ) := "1110";

  signal counter4sec_r0 : unsigned( 3 downto 0 );
  constant TICKS16      : unsigned( 3 downto 0 ) := "1111";

  signal ring12_r     : std_logic_vector( 11 downto 0 );
  signal test_phase_r : std_logic_vector( 4 downto 0 );

begin

  test_tone <= ring12_r(11); -- top bit of the 12 deep ring

  p_tone_generator_reg: process( clk, reset )
  begin
    if reset = '1' then
      counter60Hz_r0 <= SIXTEENMS;
      counter4Hz_r0  <= TICKS15;
      counter4sec_r0 <= TICKS16;
      strobe250ms    <= '1';
      ring12_r       <= (others => '0');
      test_phase_r   <= (0 => '1', others => '0');

    elsif rising_edge( clk ) then

      strobe250ms <= '0';

      if counter60Hz_r0 = 0 then

        counter60Hz_r0 <= SIXTEENMS;

        -- this counter is a divide by 15 of 60 Hz. it generates the sample strobe
        --
        if counter4Hz_r0 = 0 then
          strobe250ms   <= '1';
          counter4Hz_r0 <= TICKS15; -- 14 is 15 ticks
        else
          counter4Hz_r0 <= counter4Hz_r0 - 1;
        end if;

        -- different test phases feed back to different points in the ring
        --
        case test_phase_r is
          when "00001" =>                   -- 0 Hz
            ring12_r <= (others => '0');

          when "00010" =>                   -- 5 Hz : feed back MSB to LSB
            ring12_r <= ring12_r( 10 downto 0 ) & ring12_r( 11 );

          when "00100" =>                   -- 10 Hz : top 6 bits
            ring12_r <= (others => '0');
            ring12_r( 11 downto 6 ) <= ring12_r( 10 downto 6 ) & ring12_r( 11 );

          when "01000" =>                   -- 15 Hz : top 4 bits
            ring12_r <= (others => '0');
            ring12_r( 11 downto 8 ) <= ring12_r( 10 downto 8 ) & ring12_r( 11 );

          when "10000" =>                   -- 20 Hz : top 3 bits
            ring12_r <= (others => '0');
            ring12_r( 11 downto 9 ) <= ring12_r( 10 downto 9 ) & ring12_r( 11 );

          when others => null;
       end case;

       -- put this after the other counter4Hz use because the ring12 setting on
       -- test phase change overrides the normal operattion of this ring
       --
       if counter4Hz_r0 = 0 then
         -- this counter is a divide by 16 of 4 Hz. it advances the test phase
         --
         if counter4sec_r0 = 0 then
           test_phase_r   <= test_phase_r( 3 downto 0 ) & test_phase_r( 4 );
           ring12_r       <= (others => '0');
           ring12_r( 11 ) <= '1';
           counter4sec_r0 <= TICKS16;
         else
           counter4sec_r0 <= counter4sec_r0 - 1;
         end if;
       end if;

      else
        counter60Hz_r0 <= counter60Hz_r0 - 1;
      end if;

    end if;
  end process p_tone_generator_reg;

end rtl;
