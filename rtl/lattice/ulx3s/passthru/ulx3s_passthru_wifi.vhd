-- (c)EMARD
-- License=BSD

-- module to bypass user input and usbserial to esp32 wifi

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.f32c_pack.all;

library ecp5u;
use ecp5u.components.all;

entity ulx3s_passthru_wifi is
  generic
  (
    C_dummy_constant: integer := 0
  );
  port
  (
  clk_25MHz: in std_logic;  -- main clock input from 25MHz clock source

  -- UART0 (FTDI USB slave serial)
  ftdi_rxd: out   std_logic;
  ftdi_txd: in    std_logic;
  -- FTDI additional signaling
  ftdi_ndtr: inout  std_logic;
  ftdi_ndsr: inout  std_logic;
  ftdi_nrts: inout  std_logic;
  ftdi_txden: inout std_logic;

  -- UART1 (WiFi serial)
  wifi_rxd: out   std_logic;
  wifi_txd: in    std_logic;
  -- WiFi additional signaling
  wifi_en: inout  std_logic := 'Z'; -- '0' will disable wifi by default
  wifi_gpio0: inout std_logic;
  wifi_gpio15: inout std_logic;
  wifi_gpio16: inout std_logic;

  -- Onboard blinky
  led: out std_logic_vector(7 downto 0);
  btn: in std_logic_vector(6 downto 0);
  sw: in std_logic_vector(1 to 4);
  oled_csn, oled_clk, oled_mosi, oled_dc, oled_resn: out std_logic;

  -- GPIO (some are shared with wifi and adc)
  gp, gn: inout std_logic_vector(27 downto 0);

  -- SHUTDOWN: logic '1' here will shutdown power on PCB >= v1.7.5
  shutdown: out std_logic := '0';

  -- Digital Video (differential outputs)
  --gpdi_dp, gpdi_dn: out std_logic_vector(2 downto 0);
  --gpdi_clkp, gpdi_clkn: out std_logic;

  -- Flash ROM (SPI0)
  flash_miso   : in      std_logic;
  flash_mosi   : out     std_logic;
  flash_clk    : out     std_logic;
  flash_csn    : out     std_logic;

  -- SD card (SPI1)
  sd_dat3_csn, sd_cmd_di, sd_dat0_do, sd_dat1_irq, sd_dat2: inout std_logic;
  sd_clk: out std_logic;
  sd_cdn, sd_wp: in std_logic
  );
end;

architecture Behavioral of ulx3s_passthru_wifi is
  signal clk: std_logic;
  signal R_blinky: std_logic_vector(26 downto 0);
  signal S_hspi_miso, S_hspi_mosi, S_hspi_sck, S_hspi_ss: std_logic;
  signal S_hspi_csn, S_hspi_dc, S_hspi_resn: std_logic;
  signal S_prog_in, S_prog_out: std_logic_vector(1 downto 0);
begin
  clk <= clk_25MHz;
  
  -- TX/RX passthru
  ftdi_rxd <= wifi_txd;
  wifi_rxd <= ftdi_txd;

  -- Programming logic
  -- SERIAL  ->  ESP32
  -- DTR RTS -> EN IO0
  --  1   1     1   1
  --  0   0     1   1
  --  1   0     0   1
  --  0   1     1   0
  S_prog_in <= ftdi_ndtr & ftdi_nrts;
  S_prog_out <= "01" when S_prog_in = "10" else
                "10" when S_prog_in = "01" else
                "11";
  wifi_en <= S_prog_out(1);
  wifi_gpio0 <= S_prog_out(0);
  
  -- OLED display passthru (using pins on J1 shared with wifi)
  S_hspi_miso <= gp(9); -- wifi gpio12
  S_hspi_mosi <= gn(9); -- wifi gpio13
  S_hspi_sck <= gn(10); -- wifi gpio14
  S_hspi_csn <= wifi_gpio15; -- wifi gpio15
  S_hspi_dc <= gp(11); -- wifi gpio25
  S_hspi_resn <= gn(11); -- wifi gpio26

  oled_csn <= S_hspi_csn;
  oled_clk <= S_hspi_sck;
  oled_mosi <= S_hspi_mosi;
  oled_dc <= S_hspi_dc;
  oled_resn <= S_hspi_resn;

  -- show OLED signals on the LEDs
  led(4 downto 0) <= S_hspi_csn & S_hspi_dc & S_hspi_resn & S_hspi_mosi & S_hspi_sck;
  
  -- Pushbuttons passthru (using pins on J1 shared with wifi)
  gp(12) <= btn(3); -- up 
  gn(12) <= btn(4); -- down
  gp(13) <= btn(5); -- left
  gn(13) <= btn(6); -- right

  -- clock alive blinky
  process(clk)
  begin
      if rising_edge(clk) then
        R_blinky <= R_blinky+1;
      end if;
  end process;
  led(7) <= R_blinky(R_blinky'high);

end Behavioral;