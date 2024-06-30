-- IEEE Floating Point to Integer Converter (Double Precision)
-- Copyright (C) Jonathan P Dawson 2014
-- 2014-01-11

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity double_to_float is
    Port (
        clk         : in  STD_LOGIC;
        rst         : in  STD_LOGIC;
        input_a     : in  STD_LOGIC_VECTOR(63 downto 0);
        input_a_stb : in  STD_LOGIC;
        input_a_ack : out STD_LOGIC;
        output_z    : out STD_LOGIC_VECTOR(31 downto 0);
        output_z_stb: out STD_LOGIC;
        output_z_ack: in  STD_LOGIC
    );
end double_to_float;

architecture Behavioral of double_to_float is
    type state_type is (get_a, unpack, denormalise, put_z);
    signal state : state_type := get_a;
    
    signal s_input_a_ack : STD_LOGIC := '0';
    signal s_output_z_stb : STD_LOGIC := '0';
    signal s_output_z : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    
    signal a : STD_LOGIC_VECTOR(63 downto 0) := (others => '0');
    signal z : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal z_e : STD_LOGIC_VECTOR(10 downto 0) := (others => '0');
    signal z_m : STD_LOGIC_VECTOR(23 downto 0) := (others => '0');
    signal guard : STD_LOGIC := '0';
    signal round : STD_LOGIC := '0';
    signal sticky : STD_LOGIC := '0';

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
                            state <= unpack;
                        end if;

                    when unpack =>
                        z(31) <= a(63);
                        state <= put_z;
                        if a(62 downto 52) = 0 then
                            z(30 downto 23) <= (others => '0');
                            z(22 downto 0) <= (others => '0');
                        elsif unsigned(a(62 downto 52)) < 897 then
                            z(30 downto 23) <= (others => '0');
                            z_m <= '1' & a(51 downto 29);
                            z_e <= a(62 downto 52);
                            guard <= a(28);
                            round <= a(27);
                            sticky <= (a(26 downto 0) /= 0);
                            state <= denormalise;
                        elsif a(62 downto 52) = 2047 then
                            z(30 downto 23) <= (others => '1');
                            z(22 downto 0) <= (others => '0');
                            if a(51 downto 0) /= 0 then
                                z(22) <= '1';
                            end if;
                        elsif unsigned(a(62 downto 52)) > 1150 then
                            z(30 downto 23) <= (others => '1');
                            z(22 downto 0) <= (others => '0');
                        else
                            z(30 downto 23) <= std_logic_vector(unsigned(a(62 downto 52)) - 1023 + 127);
                            if a(28) = '1' and (a(27) = '1' or a(26 downto 0) /= 0) then
                                z(22 downto 0) <= std_logic_vector(unsigned(a(51 downto 29)) + 1);
                            else
                                z(22 downto 0) <= a(51 downto 29);
                            end if;
                        end if;

                    when denormalise =>
                        if z_e = 897 or (z_m = 0 and guard = '0') then
                            state <= put_z;
                            z(22 downto 0) <= z_m;
                            if guard = '1' and (round = '1' or sticky = '1') then
                                z(22 downto 0) <= std_logic_vector(unsigned(z_m) + 1);
                            end if;
                        else
                            z_e <= std_logic_vector(unsigned(z_e) + 1);
                            z_m <= '0' & z_m(23 downto 1);
                            guard <= z_m(0);
                            round <= guard;
                            sticky <= sticky or round;
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
