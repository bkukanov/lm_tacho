library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tacho is
port (
  clk           : in  std_logic;         -- 100 MHz
  reset         : in  std_logic;
  sensor        : in  std_logic;
  rpm           : in  std_logic;
  rpm_led       : out std_logic;
  test_mode     : in  std_logic;
  test_mode_led : out std_logic;
  tx_data       : out std_logic;
  sseg_an       : out std_logic_vector( 3 downto 0 );
  sseg_ca       : out std_logic_vector( 7 downto 0 )
  );
end entity tacho;

architecture rtl of tacho is

  component tone_generator is
  port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    strobe250ms : out std_logic;
    test_tone   : out std_logic
    );
  end component tone_generator;

  signal strobe    : std_logic;
  signal test_tone : std_logic;

  component rev_counter is
  port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    test_mode   : in  std_logic;
    sensor      : in  std_logic;
    test_sensor : in  std_logic;
    rev_count   : out unsigned( 23 downto 0 )
    );
  end component rev_counter;

  signal rev_count : unsigned( 23 downto 0 );

  component filter is
  port (
    clk       : in  std_logic;
    reset     : in  std_logic;
    strobe    : in  std_logic;
    rev_count : in  unsigned( 23 downto 0 );
    sigma     : out unsigned( 15 downto 0 )
    );
  end component filter;

  signal sigma : unsigned( 15 downto 0 );

  component post_process is
  port (
    clk       : in  std_logic;
    reset     : in  std_logic;
    strobe    : in  std_logic;
    rev_count : in unsigned( 23 downto 0 );
    rpm       : in  std_logic;
    sigma     : in  unsigned( 15 downto 0 );
    -- uart
    byte0     : out std_logic_vector( 7 downto 0 );
    byte1     : out std_logic_vector( 7 downto 0 );
    byte2     : out std_logic_vector( 7 downto 0 );
    byte3     : out std_logic_vector( 7 downto 0 );
    byte4     : out std_logic_vector( 7 downto 0 );
    byte5     : out std_logic_vector( 7 downto 0 );
    -- seven segment display
    sseg_an   : out std_logic_vector( 3 downto 0 );
    sseg_ca   : out std_logic_vector( 7 downto 0 )
    );
  end component post_process;

  signal byte0 : std_logic_vector( 7 downto 0 );
  signal byte1 : std_logic_vector( 7 downto 0 );
  signal byte2 : std_logic_vector( 7 downto 0 );
  signal byte3 : std_logic_vector( 7 downto 0 );
  signal byte4 : std_logic_vector( 7 downto 0 );
  signal byte5 : std_logic_vector( 7 downto 0 );

  component uart is
  port (
    clk     : in  std_logic;
    reset   : in  std_logic;
    strobe  : in  std_logic;
    byte0   : in  std_logic_vector( 7 downto 0 );
    byte1   : in  std_logic_vector( 7 downto 0 );
    byte2   : in  std_logic_vector( 7 downto 0 );
    byte3   : in  std_logic_vector( 7 downto 0 );
    byte4   : in  std_logic_vector( 7 downto 0 );
    byte5   : in  std_logic_vector( 7 downto 0 );
    txd     : out std_logic
    );
  end component uart;

begin

  test_mode_led <= test_mode; -- active high. '1 lights the LED
  rpm_led       <= rpm;

  u0_tone_generator: tone_generator
  port map (
    clk         => clk,
    reset       => reset,
    strobe250ms => strobe,
    test_tone   => test_tone
    );

  u0_rev_counter: rev_counter
  port map (
    clk         => clk,
    reset       => reset,
    test_mode   => test_mode,
    sensor      => sensor,
    test_sensor => test_tone,
    rev_count   => rev_count
    );

  u0_filter: filter
  port map (
    clk       => clk,
    reset     => reset,
    strobe    => strobe,
    rev_count => rev_count,
    sigma     => sigma
    );

  u0_post_process: post_process
  port map (
    clk       => clk,
    reset     => reset,
    strobe    => strobe,
    rev_count => rev_count,
    sigma     => sigma,
    rpm       => rpm,
    byte0     => byte0,
    byte1     => byte1,
    byte2     => byte2,
    byte3     => byte3,
    byte4     => byte4,
    byte5     => byte5,
    sseg_an   => sseg_an,
    sseg_ca   => sseg_ca
    );

  u0_uart: uart
  port map (
    clk    => clk,
    reset  => reset,
    strobe => strobe,
    byte0  => byte0,
    byte1  => byte1,
    byte2  => byte2,
    byte3  => byte3,
    byte4  => byte4,
    byte5  => byte5,
    txd    => tx_data
    );

end rtl;
