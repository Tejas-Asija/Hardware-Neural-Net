library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity neural_net is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        -- Output 0 to 9.
        -- "1111" means not ready.
        -- "1110" means calculating.
        digit        : out std_logic_vector(3 downto 0);
        digit_valid  : out std_logic;
        -- Image memblock
        addr_img     : out std_logic_vector(9 downto 0);
        val_img      : in  std_logic;
        -- Weights, bias memblock
        addr_const   : out std_logic_vector(15 downto 0);
        val_const    : in  signed(15 downto 0);
        -- Intermediate value memblock
        -- Read
        addr_inter   : out std_logic_vector(6 downto 0);
        val_inter    : in  signed(63 downto 0);
        -- Write
        addr_out     : out std_logic_vector(6 downto 0);
        out_valid    : out std_logic;
        -- Debug start
        -- debug state
        -- debug i
        -- debug j
        -- Debug end
        val_out      : out signed(63 downto 0)
    );
end neural_net;

architecture behavioral of neural_net is
    type state_type is (S_IDLE, S_FIRST, S_SECOND, S_COMP);
    signal state, next_state           : state_type;
    signal i, next_i                   : std_logic_vector(5 downto 0);
    signal j, next_j                   : std_logic_vector(9 downto 0);
    signal next_digit                  : std_logic_vector(3 downto 0);
    signal next_digit_valid            : std_logic;
    signal next_addr_img               : std_logic_vector(9 downto 0);
    signal next_addr_const             : std_logic_vector(15 downto 0);
    signal next_addr_inter             : std_logic_vector(6 downto 0);
    signal next_addr_out               : std_logic_vector(6 downto 0);
    signal next_out_valid              : std_logic;
    signal next_val_out                : signed(63 downto 0);

    constant l1w_idx  : integer := 0;
    constant l2w_idx  : integer := 50176;
    constant l1b_idx  : integer := 50816;
    constant l2b_idx  : integer := 50880;
    constant inter_idx: integer := 64;

begin
    process(clk, rst)
    begin
        if rst = '1' then
            state <= S_IDLE;
            i <= (others => '0');
            j <= (others => '0');
            digit <= "1111";
            digit_valid <= '0';
            addr_img <= (others => '0');
            addr_const <= (others => '0');
            addr_inter <= (others => '0');
            addr_out <= (others => '0');
            out_valid <= '0';
            val_out <= (others => '0');
        elsif rising_edge(clk) then
            state <= next_state;
            i <= next_i;
            j <= next_j;
            digit <= next_digit;
            digit_valid <= next_digit_valid;
            addr_img <= next_addr_img;
            addr_const <= next_addr_const;
            addr_inter <= next_addr_inter;
            addr_out <= next_addr_out;
            out_valid <= next_out_valid;
            val_out <= next_val_out;
        end if;
    end process;

    process(state, i, j, val_img, val_const, val_inter, val_out)
    begin
        next_state       <= state;
        next_i           <= i;
        next_j           <= j;
        next_digit       <= digit;
        next_digit_valid <= digit_valid;
        next_addr_img    <= addr_img;
        next_addr_const  <= addr_const;
        next_addr_inter  <= addr_inter;
        next_addr_out    <= addr_out;
        next_out_valid   <= '0';
        next_val_out     <= val_out;

        case state is
            when S_IDLE =>
                if i = 0 then
                    next_digit      <= "0000";
                    next_addr_img   <= "0000000001";
                    next_addr_const <= "0000000000000001";
                    next_i          <= std_logic_vector(unsigned(i) + 1);
                else
                    next_addr_img   <= "0000000010";
                    next_addr_const <= "0000000000000010";
                    next_i          <= (others => '0');
                    next_state      <= S_FIRST;
                end if;
            when S_FIRST =>
                if unsigned(j) /= 784 then
                    -- Determine next addresses.
                    if unsigned(j) = 781 then
                        next_addr_const <= std_logic_vector(to_unsigned(l1b_idx, 16) + unsigned(i));
                    elsif unsigned(j) = 782 then
                        next_addr_img   <= (others => '0');
                        next_addr_const <= std_logic_vector(to_unsigned((unsigned(i) + 1) * 784, 16));
                        next_addr_inter <= (others => '0');
                    elsif unsigned(j) = 783 then
                        next_addr_img   <= "0000000001";
                        next_addr_const <= std_logic_vector(to_unsigned((unsigned(i) + 1) * 784 + 1, 16));
                        next_addr_inter <= "0000001";
                    else
                        next_addr_img   <= std_logic_vector(unsigned(j) + 3);
                        next_addr_const <= std_logic_vector(to_unsigned(unsigned(i) * 784 + unsigned(j) + 3, 16));
                    end if;
                    -- Add weights.
                    if unsigned(j) = 0 then
                        next_val_out <= signed(resize(val_img, 64)) * resize(val_const, 64);
                    else
                        next_val_out <= val_out + signed(resize(val_img, 64)) * resize(val_const, 64);
                    end if;
                    next_j <= std_logic_vector(unsigned(j) + 1);
                else -- j = 784
                    next_addr_img   <= "0000000010";
                    next_addr_const <= std_logic_vector(to_unsigned((unsigned(i) + 1) * 784 + 2, 16));
                    next_addr_inter <= "00000010";
                    next_val_out    <= val_out + signed(resize(val_const, 64) * 4);
                    next_val_out    <= std_logic_vector(unsigned(val_out) = 63) ? signed((others => '0')) : val_out;
                    next_addr_out   <= std_logic_vector(to_unsigned(unsigned(i), 7));
                    next_out_valid  <= '1';
                    if unsigned(i) = 63 then
                        next_i      <= (others => '0');
                        next_j      <= (others => '0');
                        next_state  <= S_SECOND;
                    else
                        next_i      <= std_logic_vector(unsigned(i) + 1);
                        next_j      <= (others => '0');
                    end if;
                end if;
            when S_SECOND =>
                if unsigned(j) /= 64 then
                    -- Determine next addresses.
                    if unsigned(j) = 61 then
                        next_addr_const <= std_logic_vector(to_unsigned(l2b_idx, 16) + unsigned(i));
                    elsif unsigned(j) = 62 then
                        next_addr_inter <= (others => '0');
                        next_addr_const <= std_logic_vector(to_unsigned(l2w_idx, 16) + unsigned(i + 1) * 64);
                        if unsigned(i) = 9 then
                            next_addr_inter <= std_logic_vector(to_unsigned(inter_idx, 7));
                        end if;
                    elsif unsigned(j) = 63 then
                        next_addr_inter <= "0000001";
                        next_addr_const <= std_logic_vector(to_unsigned(l2w_idx, 16) + unsigned(i + 1) * 64 + 1);
                        if unsigned(i) = 9 then
                            next_addr_inter <= std_logic_vector(to_unsigned(inter_idx + 1, 7));
                        end if;
                    else
                        next_addr_inter <= std_logic_vector(unsigned(j) + 3);
                        next_addr_const <= std_logic_vector(to_unsigned(l2w_idx + unsigned(i) * 64 + unsigned(j) + 3, 16));
                    end if;
                    -- Add weights.
                    if unsigned(j) = 0 then
                        next_val_out <= val_inter * signed(resize(val_const, 64));
                    else
                        next_val_out <= val_out + val_inter * signed(resize(val_const, 64));
                    end if;
                    next_j <= std_logic_vector(unsigned(j) + 1);
                else -- j = 64
                    next_addr_inter <= "00000010";
                    next_addr_const <= std_logic_vector(to_unsigned(l2w_idx + unsigned(i + 1) * 64 + 2, 16));
                    if unsigned(i) = 9 then
                        next_addr_inter <= std_logic_vector(to_unsigned(inter_idx + 2, 7));
                    end if;
                    next_val_out <= val_out + signed(resize(val_const, 64));
                    next_addr_out <= std_logic_vector(to_unsigned(inter_idx + unsigned(i), 7));
                    next_out_valid <= '1';
                    if unsigned(i) = 9 then
                        next_i      <= (others => '0');
                        next_j      <= (others => '0');
                        next_state  <= S_COMP;
                    else
                        next_i      <= std_logic_vector(unsigned(i) + 1);
                        next_j      <= (others => '0');
                    end if;
                end if;
            when S_COMP =>
                if unsigned(i) /= 10 then
                    if unsigned(i) = 0 then
                        next_digit <= "0000";
                        next_val_out <= val_inter;
                    elsif val_out < val_inter then
                        next_digit <= std_logic_vector(unsigned(i));
                        next_val_out <= val_inter;
                    end if;
                    next_addr_inter <= std_logic_vector(to_unsigned(inter_idx + unsigned(i) + 3, 7));
                    next_i <= std_logic_vector(unsigned(i) + 1);
                else
                    next_digit_valid <= '1';
                end if;
            when others =>
                next_state <= S_IDLE;
        end case;
    end process;
end behavioral;
