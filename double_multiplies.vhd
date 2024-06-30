-- IEEE Floating Point Multiplier (Double Precision)
-- Copyright (C) Jonathan P Dawson 2014
-- 2014-01-10

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity double_multiplier is
    Port (
        clk         : in  STD_LOGIC;
        rst         : in  STD_LOGIC;
        input_a     : in  STD_LOGIC_VECTOR(63 downto 0);
        input_a_stb : in  STD_LOGIC;
        input_a_ack : out STD_LOGIC;
        input_b     : in  STD_LOGIC_VECTOR(63 downto 0);
        input_b_stb : in  STD_LOGIC;
        input_b_ack : out STD_LOGIC;
        output_z    : out STD_LOGIC_VECTOR(63 downto 0);
        output_z_stb: out STD_LOGIC;
        output_z_ack: in  STD_LOGIC
    );
end double_multiplier;

architecture Behavioral of double_multiplier is
    type state_type is (
        get_a, get_b, unpack, special_cases, normalise_a, 
        normalise_b, multiply_0, multiply_1, normalise_1, 
        normalise_2, round, pack, put_z
    );
    
    signal state : state_type := get_a;
    
    signal s_input_a_ack : STD_LOGIC := '0';
    signal s_input_b_ack : STD_LOGIC := '0';
    signal s_output_z_stb : STD_LOGIC := '0';
    signal s_output_z : STD_LOGIC_VECTOR(63 downto 0) := (others => '0');
    
    signal a, b, z : STD_LOGIC_VECTOR(63 downto 0) := (others => '0');
    signal a_m, b_m, z_m : STD_LOGIC_VECTOR(52 downto 0) := (others => '0');
    signal a_e, b_e, z_e : STD_LOGIC_VECTOR(12 downto 0) := (others => '0');
    signal a_s, b_s, z_s : STD_LOGIC := '0';
    signal guard, round_bit, sticky : STD_LOGIC := '0';
    signal product : STD_LOGIC_VECTOR(107 downto 0) := (others => '0');

begin
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= get_a;
                s_input_a_ack <= '0';
                s_input_b_ack <= '0';
                s_output_z_stb <= '0';
            else
                case state is
                    when get_a =>
                        s_input_a_ack <= '1';
                        if s_input_a_ack = '1' and input_a_stb = '1' then
                            a <= input_a;
                            s_input_a_ack <= '0';
                            state <= get_b;
                        end if;

                    when get_b =>
                        s_input_b_ack <= '1';
                        if s_input_b_ack = '1' and input_b_stb = '1' then
                            b <= input_b;
                            s_input_b_ack <= '0';
                            state <= unpack;
                        end if;

                    when unpack =>
                        a_m <= a(51 downto 0);
                        b_m <= b(51 downto 0);
                        a_e <= std_logic_vector(unsigned(a(62 downto 52)) - 1023);
                        b_e <= std_logic_vector(unsigned(b(62 downto 52)) - 1023);
                        a_s <= a(63);
                        b_s <= b(63);
                        state <= special_cases;

                    when special_cases =>
                        if (unsigned(a_e) = 1024 and a_m /= "0000000000000000000000000000000000000000000000000000") or 
                           (unsigned(b_e) = 1024 and b_m /= "0000000000000000000000000000000000000000000000000000") then
                            z(63) <= '1';
                            z(62 downto 52) <= "11111111111";
                            z(51) <= '1';
                            z(50 downto 0) <= (others => '0');
                            state <= put_z;
                        elsif unsigned(a_e) = 1024 then
                            z(63) <= a_s xor b_s;
                            z(62 downto 52) <= "11111111111";
                            z(51 downto 0) <= (others => '0');
                            if (signed(b_e) = -1023) and (b_m = "0000000000000000000000000000000000000000000000000000") then
                                z(63) <= '1';
                                z(62 downto 52) <= "11111111111";
                                z(51) <= '1';
                                z(50 downto 0) <= (others => '0');
                            end if;
                            state <= put_z;
                        elsif unsigned(b_e) = 1024 then
                            z(63) <= a_s xor b_s;
                            z(62 downto 52) <= "11111111111";
                            z(51 downto 0) <= (others => '0');
                            if (signed(a_e) = -1023) and (a_m = "0000000000000000000000000000000000000000000000000000") then
                                z(63) <= '1';
                                z(62 downto 52) <= "11111111111";
                                z(51) <= '1';
                                z(50 downto 0) <= (others => '0');
                            end if;
                            state <= put_z;
                        elsif (signed(a_e) = -1023) and (a_m = "0000000000000000000000000000000000000000000000000000") then
                            z(63) <= a_s xor b_s;
                            z(62 downto 0) <= (others => '0');
                            state <= put_z;
                        elsif (signed(b_e) = -1023) and (b_m = "0000000000000000000000000000000000000000000000000000") then
                            z(63) <= a_s xor b_s;
                            z(62 downto 0) <= (others => '0');
                            state <= put_z;
                        else
                            if signed(a_e) = -1023 then
                                a_e <= std_logic_vector(to_signed(-1022, 13));
                            else
                                a_m(52) <= '1';
                            end if;
                            if signed(b_e) = -1023 then
                                b_e <= std_logic_vector(to_signed(-1022, 13));
                            else
                                b_m(52) <= '1';
                            end if;
                            state <= normalise_a;
                        end if;

                    when normalise_a =>
                        if a_m(52) = '1' then
                            state <= normalise_b;
                        else
                            a_m <= a_m(51 downto 0) & '0';
                            a_e <= std_logic_vector(signed(a_e) - 1);
                        end if;

                    when normalise_b =>
                        if b_m(52) = '1' then
                            state <= multiply_0;
                        else
                            b_m <= b_m(51 downto 0) & '0';
                            b_e <= std_logic_vector(signed(b_e) - 1);
                        end if;

                    when multiply_0 =>
                        z_s <= a_s xor b_s;
                        z_e <= std_logic_vector(unsigned(a_e) + unsigned(b_e) + 1);
                        product <= std_logic_vector(unsigned(a_m) * unsigned(b_m) * 4);
                        state <= multiply_1;

                    when multiply_1 =>
                        z_m <= product(107 downto 55);
                        guard <= product(54);
                        round_bit <= product(53);
                        sticky <= (product(52 downto 0) /= "0000000000000000000000000000000000000000000000000000000");
                        state <= normalise_1;

                    when normalise_1 =>
                        if z_m(52) = '0' then
                            z_e <= std_logic_vector(signed(z_e) - 1);
                            z_m <= z_m(51 downto 0) & guard;
                            guard <= round_bit;
                            round_bit <= '0';
                        else
                            state <= normalise_2;
                        end if;

                    when normalise_2 =>
                        if signed(z_e) < -1022 then
                            z_e <= std_logic_vector(signed(z_e) + 1);
                            z_m <= '0' & z_m(52 downto 1);
                            guard <= z_m(0);
                            round_bit <= guard;
                            sticky <= sticky or round_bit;
                        else
                            state <= round;
                        end if;

                    when round =>
                        if guard = '1' and (round_bit = '1' or sticky = '1' or z_m(0) = '1') then
                            z_m <= std_logic_vector(unsigned(z_m) + 1);
                            if z_m = "11111111111111111111111111111111111111111111111111111" then
                                z_e <= std_logic_vector(unsigned(z_e) + 1);
                            end if;
                        end if;
                        state <= pack;

                    when pack =>
                        z(51 downto 0) <= z_m(51 downto 0);
                        z(62 downto 52) <= std_logic_vector(unsigned(z_e) + 1023);
                        z(63) <= z_s;
                        if signed(z_e) = -1022 and z_m(52) = '0' then
                            z(62 downto 52) <= (others => '0');
                        end if;
                        if signed(z_e) > 1023 then
                            z(51 downto 0) <= (others => '0');
                            z(62 downto 52) <= "11111111111";
                            z(63) <= z_s;
                        end if;
                        state <= put_z;

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
    input_b_ack <= s_input_b_ack;
    output_z_stb <= s_output_z_stb;
    output_z <= s_output_z;

end Behavioral;
