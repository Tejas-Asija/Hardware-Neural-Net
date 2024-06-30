-- Clock Divisor: Divides input clock by 2^2 (25MHz) and 2^22
-- [in]  clk:   input of 100MHz clock.
-- [out] clk2:  output clk divided by 2^2 (25MHz).
-- [out] clk22: output clk divided by 2^22.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity clock_divisor is
    Port (
        clk     : in  STD_LOGIC;
        clk2    : out STD_LOGIC;
        clk22   : out STD_LOGIC
    );
end clock_divisor;

architecture Behavioral of clock_divisor is
    signal num : STD_LOGIC_VECTOR(21 downto 0) := (others => '0');
    signal next_num : STD_LOGIC_VECTOR(21 downto 0);
begin
    process(clk)
    begin
        if rising_edge(clk) then
            num <= next_num;
        end if;
    end process;

    next_num <= num + 1;

    clk2 <= num(1);
    clk22 <= num(21);
end Behavioral;


-- Clock Divider: Divides input clock by 2^n (parameterized)
-- [in]  clk:   input clock.
-- [out] CLK_DIV: output clock divided by 2^n.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity clock_divider is
    Generic (
        n : integer := 26
    );
    Port (
        clk     : in  STD_LOGIC;
        CLK_DIV : out STD_LOGIC
    );
end clock_divider;

architecture Behavioral of clock_divider is
    signal c : STD_LOGIC_VECTOR(n-1 downto 0) := (others => '0');
begin
    process(clk)
    begin
        if rising_edge(clk) then
            c <= c + 1;
        end if;
    end process;

    CLK_DIV <= c(n-1);
end Behavioral;
