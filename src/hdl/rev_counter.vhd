library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rev_counter is
port (
  clk         : in  std_logic; -- 100 MHz
  reset       : in  std_logic;
  test_mode   : in  std_logic;
  sensor      : in  std_logic;
  test_sensor : in  std_logic;
  rev_count   : out unsigned( 23 downto 0 )
  );
end entity rev_counter;

-- the sensor input goes through an event detector which triggers on either a
-- 0 to 1 or 1 to 0 transition. the event triggers a 40 ms timer that then
-- blanks out any further (erroneous) triggers caused by relay bounce

architecture rtl of rev_counter is
  signal resync_event_r : std_logic_vector( 2 downto 0 );
  signal blanking_r0    : std_logic;

  -- 40 ms corresponds to 25 Hz or 1500 rpm this should be adequate as 1500
  -- rpm should be physically impossible to achieve
  -- 15 Hz or 900 rpm is physically achievable and corresponds to 67 ms
  -- which is comfortably above the blanking duration

  -- 40 ms / 10 ns = 40/10 * 1e-3/1e-9 = 4 Mclocks @ 100 MHz
  -- 4 M = 'b100 << 20 = 4*1024*1024*10 ns = 41.94 ms
  -- 23 bits but we count down to zero so 22 bits of all 1 will do it
  signal blanking_timer_r0   : unsigned( 21 downto 0 );
  constant BLANKING_DURATION : unsigned( 21 downto 0 ) := (others => '1'); -- 4*2^20 - 1

  -- overall rev count
  -- 24 hrs * 60 mins * 1500 rpm = 2.16 Mrev 'b10 << 20
  -- use 24 bits to save padding up to 3 bytes elsewhere
  signal rev_count_r0 : unsigned( 23 downto 0 );

begin

  rev_count <= rev_count_r0; -- 24 bit counter output

  p_rev_counter_reg: process( clk, reset )
  begin
    if reset = '1' then
      resync_event_r    <= (others => '0');
      rev_count_r0      <= (others => '0');
      blanking_r0       <= '0';
      blanking_timer_r0 <= (others => '0');

    elsif rising_edge( clk ) then

      if test_mode = '0' then
        resync_event_r(0) <= sensor;
      else
        resync_event_r(0) <= test_sensor;
      end if;

      resync_event_r(2 downto 1) <= resync_event_r(1 downto 0); -- shift reg

      if blanking_r0 = '0' then
        if resync_event_r(1) /= resync_event_r(2) then
          -- count the revolution event and enter blanking
          --
          rev_count_r0      <= rev_count_r0 + 1;
          blanking_r0       <= '1';
          blanking_timer_r0 <= BLANKING_DURATION;
        end if;
      else
        if blanking_timer_r0 = 0 then
          blanking_r0       <= '0';
        else
          blanking_timer_r0 <= blanking_timer_r0 - 1;
        end if;
      end if;

    end if;
  end process p_rev_counter_reg;

end rtl;
