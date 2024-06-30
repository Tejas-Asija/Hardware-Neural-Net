-- IEEE Floating Point Adder (Double Precision)
-- Copyright (C) Jonathan P Dawson 2013
-- 2013-12-12

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity double_adder is
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
end double_adder;

architecture Behavioral of double_adder is
    type state_type is (
        get_a, get_b, unpack, special_cases, align, 
        add_0, add_1, normalise_1, normalise_2, round, 
        pack, put_z
    );
    
    signal state : state_type := get_a;
    
    signal s_input_a_ack : STD_LOGIC := '0';
    signal s_input_b_ack : STD_LOGIC := '0';
    signal s_output_z_stb : STD_LOGIC := '0';
    signal s_output_z : STD_LOGIC_VECTOR(63 downto 0) := (others => '0');
    
    signal a, b, z : STD_LOGIC_VECTOR(63 downto 0) := (others => '0');
    signal a_m, b_m : STD_LOGIC_VECTOR(55 downto 0) := (others => '0');
    signal z_m : STD_LOGIC_VECTOR(52 downto 0) := (others => '0');
    signal a_e, b_e, z_e : STD_LOGIC_VECTOR(12 downto 0) := (others => '0');
    signal a_s, b_s, z_s : STD_LOGIC := '0';
    signal guard, round_bit, sticky : STD_LOGIC := '0';
    signal sum : STD_LOGIC_VECTOR(56 downto 0) := (others => '0');

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
                        a_m <= a(51 downto 0) & "000";
                        b_m <= b(51 downto 0) & "000";
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
                            z(63) <= a_s;
                            z(62 downto 52) <= "11111111111";
                            z(51 downto 0) <= (others => '0');
                            if unsigned(b_e) = 1024 and a_s /= b_s then
                                z(63) <= '1';
                                z(62 downto 52) <= "11111111111";
                                z(51) <= '1';
                                z(50 downto 0) <= (others => '0');
                            end if;
                            state <= put_z;
                        elsif unsigned(b_e) = 1024 then
                            z(63) <= b_s;
                            z(62 downto 52) <= "11111111111";
                            z(51 downto 0) <= (others => '0');
                            state <= put_z;
                        elsif (signed(a_e) = -1023 and a_m = "0000000000000000000000000000000000000000000000000000") and 
                              (signed(b_e) = -1023 and b_m = "0000000000000000000000000000000000000000000000000000") then
                            z(63) <= a_s and b_s;
                            z(62 downto 52) <= std_logic_vector(unsigned(b_e) + 1023);
                            z(51 downto 0) <= b_m(55 downto 3);
                            state <= put_z;
                        elsif signed(a_e) = -1023 and a_m = "0000000000000000000000000000000000000000000000000000" then
                            z(63) <= b_s;
                            z(62 downto 52) <= std_logic_vector(unsigned(b_e) + 1023);
                            z(51 downto 0) <= b_m(55 downto 3);
                            state <= put_z;
                        elsif signed(b_e) = -1023 and b_m = "0000000000000000000000000000000000000000000000000000" then
                            z(63) <= a_s;
                            z(62 downto 52) <= std_logic_vector(unsigned(a_e) + 1023);
                            z(51 downto 0) <= a_m(55 downto 3);
                            state <= put_z;
                        else
                            if signed(a_e) = -1023 then
                                a_e <= std_logic_vector(to_signed(-1022, 13));
                            else
                                a_m(55) <= '1';
                            end if;
                            if signed(b_e) = -1023 then
                                b_e <= std_logic_vector(to_signed(-1022, 13));
                            else
                                b_m(55) <= '1';
                            end if;
                            state <= align;
                        end if;

                    when align =>
                        if signed(a_e) > signed(b_e) then
                            b_e <= std_logic_vector(unsigned(b_e) + 1);
                            b_m <= '0' & b_m(55 downto 1);
                            b_m(0) <= b_m(0) or b_m(1);
                        elsif signed(a_e) < signed(b_e) then
                            a_e <= std_logic_vector(unsigned(a_e) + 1);
                            a_m <= '0' & a_m(55 downto 1);
                            a_m(0) <= a_m(0) or a_m(1);
                        else
                            state <= add_0;
                        end if;

                    when add_0 =>
                        z_e <= a_e;
                        if a_s = b_s then
                            sum <= std_logic_vector(unsigned('0' & a_m) + unsigned(b_m));
                            z_s <= a_s;
                        else
                            if unsigned(a_m) > unsigned(b_m) then
                                sum <= std_logic_vector(unsigned('0' & a_m) - unsigned(b_m));
                                z_s <= a_s;
                            else
                                sum <= std_logic_vector(unsigned('0' & b_m) - unsigned(a_m));
                                z_s <= b_s;
                            end if;
                        end if;
                        state <= add_1;

                    when add_1 =>
                        if sum(56) = '1' then
                            z_m <= sum(56 downto 4);
                            guard <= sum(3);
                            round_bit <= sum(2);
                            sticky <= sum(1) or sum(0);
                            z_e <= std_logic_vector(unsigned(z_e) + 1);
                        else
                            z_m <= sum(55 downto 3);
                            guard <= sum(2);
                            round_bit <= sum(1);
                            sticky <= sum(0);
                        end if;
                        state <= normalise_1;

                    when normalise_1 =>
                        if z_m(52) = '0' and signed(z_e) > -1022 then
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
