-- Integer to IEEE Floating Point Converter (Double Precision)
-- Copyright (C) Jonathan P Dawson 2013
-- 2013-12-12

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity float_to_double is
    Port (
        clk         : in  STD_LOGIC;
        rst         : in  STD_LOGIC;
        input_a     : in  STD_LOGIC_VECTOR(31 downto 0);
        input_a_stb : in  STD_LOGIC;
        input_a_ack : out STD_LOGIC;
        output_z    : out STD_LOGIC_VECTOR(63 downto 0);
        output_z_stb: out STD_LOGIC;
        output_z_ack: in  STD_LOGIC
    );
end float_to_double;

architecture Behavioral of float_to_double is
    type state_type is (get_a, convert_0, normalise_0, put_z);
    signal state : state_type := get_a;
    
    signal s_input_a_ack : STD_LOGIC := '0';
    signal s_output_z_stb : STD_LOGIC := '0';
    signal s_output_z : STD_LOGIC_VECTOR(63 downto 0) := (others => '0');
    
    signal z : STD_LOGIC_VECTOR(63 downto 0) := (others => '0');
    signal z_e : STD_LOGIC_VECTOR(10 downto 0) := (others => '0');
    signal z_m : STD_LOGIC_VECTOR(52 downto 0) := (others => '0');
    signal a : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');

begin
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= get_a;
                s_input_a_ack <= '0';
                s_output_z_stb <= '0';
            else
                case state is
                    when get_a =>
                        s_input_a_ack <= '1';
                        if s_input_a_ack = '1' and input_a_stb = '1' then
                            a <= input_a;
                            s_input_a_ack <= '0';
                            state <= convert_0;
                        end if;

                    when convert_0 =>
                        z(63) <= a(31);
                        z(62 downto 52) <= std_logic_vector(unsigned(a(30 downto 23)) - 127 + 1023);
                        z(51 downto 0) <= a(22 downto 0) & "00000000000000000000000000000";
                        if a(30 downto 23) = 255 then
                            z(62 downto 52) <= "11111111111";
                        end if;
                        state <= put_z;
                        if a(30 downto 23) = 0 then
                            if a(22 downto 0) /= "00000000000000000000000" then
                                state <= normalise_0;
                                z_e <= "01110000001";
                                z_m <= '0' & a(22 downto 0) & "00000000000000000000000000000";
                            end if;
                            z(62 downto 52) <= (others => '0');
                        end if;

                    when normalise_0 =>
                        if z_m(52) = '1' then
                            z(62 downto 52) <= z_e;
                            z(51 downto 0) <= z_m(51 downto 0);
                            state <= put_z;
                        else
                            z_m <= z_m(51 downto 0) & '0';
                            z_e <= std_logic_vector(unsigned(z_e) - 1);
                        end if;

                    when put_z =>
                        s_output_z_stb <= '1';
                        s_output_z <= z;
                        if s_output_z_stb = '1' and output_z_ack = '1' then
                            s_output_z_stb <= '0';
                            state <= get_a;
                        end if;
                end case;
            end if;
        end if;
    end process;

    input_a_ack <= s_input_a_ack;
    output_z_stb <= s_output_z_stb;
    output_z <= s_output_z;

end Behavioral;
