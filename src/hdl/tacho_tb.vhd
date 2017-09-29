library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tacho_tb is
end entity tacho_tb;

architecture tb of tacho_tb is

  component tacho is
  port (
    clk           : in  std_logic;         -- 100 MHz
    reset         : in  std_logic;

  --sensor        : in  std_logic;

    rpm           : in  std_logic;
    rpm_led       : out std_logic;

    test_mode     : in  std_logic;
    test_mode_led : out std_logic;

  --tx_data       : out std_logic;

    sseg_an       : out std_logic_vector( 3 downto 0 );
    sseg_ca       : out std_logic_vector( 7 downto 0 )
    );
  end component tacho;

  signal clk       : std_logic := '1';
  signal reset     : std_logic := '1'; -- dev board buttons are active high when pushed
  signal test_mode : std_logic := '1'; -- switches are high too when in the up position
  signal rpm       : std_logic := '1';

begin

  clk <= not clk after 5 ns;

  process
  begin
     reset <= not reset after 50 ns;
     wait;
  end process;

  u0_tacho: tacho
  port map (
    clk           => clk,
    reset         => reset,

  --sensor        : in  std_logic;

    rpm           => rpm,
    rpm_led       => open,

    test_mode     => test_mode,
    test_mode_led => open,

  --tx_data       : out std_logic;

    sseg_an       => open,
    sseg_ca       => open
    );

end tb;
