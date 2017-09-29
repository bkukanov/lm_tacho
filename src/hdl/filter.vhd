library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity filter is
port (
  clk          : in  std_logic;
  reset        : in  std_logic;
  strobe       : in  std_logic;
  rev_count    : in  unsigned( 20 downto 0 );
  sigma        : out unsigned( 15 downto 0 )
  );
end entity filter;

-- the sampling strobe fires every 250 ms, so the gap between events is
-- multiplied by 4 to get a value in Hertz. however, the samples are
-- also output as the average of the last 8 samples (2 seconds worth)
-- making the output value in Hertz: sum(deltas)/8 * 4 = sum(deltas)/2

architecture rtl of filter is
  signal count_r0  : unsigned( 20 downto 0 );
  signal delta     : unsigned( 20 downto 0 );
  type delta_type is array (7 downto 0) of unsigned( 12 downto 0 );
  signal delta_r   : delta_type;
  signal sigma01   : unsigned( 13 downto 0 );
  signal sigma23   : unsigned( 13 downto 0 );
  signal sigma45   : unsigned( 13 downto 0 );
  signal sigma67   : unsigned( 13 downto 0 );
  signal sigma0123 : unsigned( 14 downto 0 );
  signal sigma4567 : unsigned( 14 downto 0 );
begin

  delta <= rev_count - count_r0;

  p_filter_r: process( clk, reset )
  begin
    if reset = '1' then
      count_r0 <= (others => '0');
      delta_r  <= (others => (others => '0'));
      sigma    <= (others => '0');

    elsif rising_edge( clk ) then

      if strobe = '1' then
         count_r0              <= rev_count;
         delta_r( 0 )          <= delta( 12 downto 0 );
         delta_r( 7 downto 1 ) <= delta_r( 6 downto 0 ); -- shift register
      end if;

      -- register the 3 deep adder tree for timing
      --
      sigma <= resize( sigma0123, 16) + sigma4567;

    end if;
  end process p_filter_r;

  -- sum the 8 deltas in a log(8) = 3 deep tree to help the synthesis tool
  --
  sigma01   <= resize( delta_r( 0 ), 14) + delta_r( 1 );
  sigma23   <= resize( delta_r( 2 ), 14) + delta_r( 3 );
  sigma45   <= resize( delta_r( 4 ), 14) + delta_r( 5 );
  sigma67   <= resize( delta_r( 6 ), 14) + delta_r( 7 );
  --
  sigma0123 <= resize( sigma01, 15) + sigma23;
  sigma4567 <= resize( sigma45, 15) + sigma67;

end rtl;
