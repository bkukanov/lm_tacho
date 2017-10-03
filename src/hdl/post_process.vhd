library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity post_process is
port (
  clk       : in  std_logic;
  reset     : in  std_logic;
  strobe    : in  std_logic;
  rev_count : in  unsigned( 23 downto 0 );
  sigma     : in  unsigned( 15 downto 0 );
  rpm       : in  std_logic;
  byte0     : out std_logic_vector( 7 downto 0 );
  byte1     : out std_logic_vector( 7 downto 0 );
  byte2     : out std_logic_vector( 7 downto 0 );
  byte3     : out std_logic_vector( 7 downto 0 );
  byte4     : out std_logic_vector( 7 downto 0 );
  byte5     : out std_logic_vector( 7 downto 0 );
  sseg_an   : out std_logic_vector( 3 downto 0 );
  sseg_ca   : out std_logic_vector( 7 downto 0 )
  );
end post_process;

-- converts the binary input 2^13-1 = 8191 max to 4 digit decimal by repeated
-- subtraction. worst case would be 7999 decimal requiring 7 cycles for the
-- thousands, 9 for hundreds and 9 for tens 7+9+9 = 25 clocks.

-- the decimal digits are time multiplexed onto the cathode and relevant anode
-- of the seven segment display is powered up

-- the binary value of the rev_count is output in 6 bytes to the uart

architecture rtl of post_process is

  type digit_type is array (natural range <>) of unsigned( 3 downto 0 );

  signal htz_sigma_r0 : unsigned( 20 downto 0 );
  signal htz_sigma_r1 : unsigned( 12 downto 0 );
  signal htz_sigma_r2 : unsigned( 12 downto 0 );
  signal htz_anode_r2 : std_logic_vector( 3 downto 0 );
  signal htz_digit_r2 : digit_type( 3 downto 0 );

  signal rpm_sigma_r0 : unsigned( 20 downto 0 );
  signal rpm_sigma_r1 : unsigned( 12 downto 0 );
  signal rpm_sigma_r2 : unsigned( 12 downto 0 );
  signal rpm_anode_r2 : std_logic_vector( 3 downto 0 );
  signal rpm_digit_r2 : digit_type( 3 downto 0 );

  signal timer_r0 : unsigned( 19 downto 0 );

  type seven_segment_lut_type is array (0 to 9) of std_logic_vector( 7 downto 0 );
  constant seven_segment_lut : seven_segment_lut_type :=
    ("11000000",  -- 0 MSB is decimal point - turn it off
     "11111001",  -- 1
     "10100100",  -- 2
     "10110000",  -- 3
     "10011001",  -- 4
     "10010010",  -- 5
     "10000010",  -- 6
     "11111000",  -- 7
     "10000000",  -- 8
     "10010000"); -- 9

begin


  p_bcd_r: process( clk, reset )
  begin
    if reset = '1' then
      htz_sigma_r0 <= (others => '0');
      htz_sigma_r1 <= (others => '0');
      htz_sigma_r2 <= (others => '0');
      htz_digit_r2 <= (others => (others => '0'));
      htz_anode_r2 <= (others => '0');

      rpm_sigma_r0 <= (others => '0');
      rpm_sigma_r1 <= (others => '0');
      rpm_sigma_r2 <= (others => '0');
      rpm_digit_r2 <= (others => (others => '0'));
      rpm_anode_r2 <= (others => '0');

      timer_r0 <= (others => '0');

      byte0 <= (others => '0');
      byte1 <= (others => '0');
      byte2 <= (others => '0');
      byte3 <= (others => '0');
      byte4 <= (others => '0');
      byte5 <= (others => '0');

    elsif rising_edge( clk ) then

      -- there are huge gaps between strobes - easily time to calculate the
      -- decimal digits from the binary input before the next strobe
      --
      if strobe = '1' then

        -- the 8 samples represent 2 secs at 250 ms sampling, so divide by two
        -- output sum(deltas)/8 * 4 = sum(deltas)/2 with rounding at bit 0
        htz_sigma_r0 <= resize( sigma, 21 ) + 1;
        htz_sigma_r1 <= htz_sigma_r0( 13 downto 1 );
        htz_sigma_r2 <= htz_sigma_r1;
        htz_digit_r2 <= (others => (others => '0'));

        byte0 <= std_logic_vector(rev_count(  7 downto  0 ));
        byte1 <= std_logic_vector(rev_count( 15 downto  8 ));
        byte2 <= std_logic_vector(rev_count( 23 downto 16 ));
        byte3 <= (others => '0');            -- might drop \r\n and use 'h00
        byte4 <= "00001101";                                    -- 'h0d = CR
        byte5 <= "00001010";                                    -- 'h0a = LF

        if htz_sigma_r1 >= 10 then
          htz_anode_r2 <= "0011"; -- 2 digits lit
        else
          htz_anode_r2 <= "0001"; -- only the bottom digit lit
        end if;

        -- RPM is just Hertz * 60
        -- the true value could be displayed by taking snapshots of the rev count
        -- at minute intervals and differencing those, but that isn't of great
        -- practical use
        --
        -- output sum(deltas)/8 * 4 * 60 = sum(deltas) * 30
        rpm_sigma_r0 <= (sigma & "00000") - (sigma & '0'); -- 30n = 32n - 2n
        rpm_sigma_r1 <= rpm_sigma_r0( 12 downto 0 );
        rpm_sigma_r2 <= rpm_sigma_r1;
        rpm_digit_r2 <= (others => (others => '0'));

        if rpm_sigma_r1 >= 1000 then
          rpm_anode_r2 <= "1111"; -- all digits will be lit
        elsif rpm_sigma_r1 >= 100 then
          rpm_anode_r2 <= "0111"; -- 3 digits lit
        elsif rpm_sigma_r1 >= 10 then
          rpm_anode_r2 <= "0011"; -- 2 digits lit
        else
          rpm_anode_r2 <= "0001"; -- only the bottom digit lit
        end if;

      else -- repeatedly subtract from the captured value until done

        if htz_sigma_r2 >= 10 then

          htz_sigma_r2      <= htz_sigma_r2 - 10;
          htz_digit_r2( 1 ) <= htz_digit_r2( 1 ) + 1;
        else
          htz_digit_r2( 0 ) <= htz_sigma_r2( 3 downto 0 ); -- final remainder is <= 9

        end if;

        if rpm_sigma_r2 >= 1000 then

          rpm_sigma_r2      <= rpm_sigma_r2 - 1000;
          rpm_digit_r2( 3 ) <= rpm_digit_r2( 3 ) + 1;

        elsif rpm_sigma_r2 >= 100 then

          rpm_sigma_r2      <= rpm_sigma_r2 - 100;
          rpm_digit_r2( 2 ) <= rpm_digit_r2( 2 ) + 1;

        elsif rpm_sigma_r2 >= 10 then

          rpm_sigma_r2      <= rpm_sigma_r2 - 10;
          rpm_digit_r2( 1 ) <= rpm_digit_r2( 1 ) + 1;

        else
          rpm_digit_r2( 0 ) <= rpm_sigma_r2( 3 downto 0 ); -- final remainder is <= 9
        end if;

      end if;

      timer_r0 <= timer_r0 + 1; -- free running timer used to mux out the digits

    end if;
  end process p_bcd_r;

  p_display_mux: process( rpm, timer_r0, htz_digit_r2, htz_anode_r2, rpm_digit_r2, rpm_anode_r2 )
     variable anode : std_logic_vector( 3 downto 0 );
     variable digit : digit_type( 3 downto 0 );
  begin
    if rpm = '0' then
       anode := htz_anode_r2;
       digit := htz_digit_r2;
    else
       anode := rpm_anode_r2;
       digit := rpm_digit_r2;
    end if;

    case timer_r0( 19 downto 18 ) is
      -- the seven segment display anode is active low so use a final not
      when "11" =>
        sseg_an <= not( "1000" and anode );
        sseg_ca <= seven_segment_lut( to_integer( digit( 3 )));
      when "10" =>
        sseg_an <= not( "0100" and anode );
        sseg_ca <= seven_segment_lut( to_integer( digit( 2 )));
      when "01" =>
        sseg_an <= not( "0010" and anode );
        sseg_ca <= seven_segment_lut( to_integer( digit( 1 )));
      when others =>
        sseg_an <= not( "0001" and anode );
        sseg_ca <= seven_segment_lut( to_integer( digit( 0 )));
    end case;
  end process p_display_mux;

end rtl;
