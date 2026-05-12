library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mouseTop is
    port (
        CLOCK_50 : in std_logic;

        KEY  : in std_logic_vector(3 downto 0);
        SW   : in std_logic_vector(9 downto 0);
        LEDR : out std_logic_vector(9 downto 0);

        HEX0 : out std_logic_vector(6 downto 0);
        HEX1 : out std_logic_vector(6 downto 0);
        HEX2 : out std_logic_vector(6 downto 0);
        HEX3 : out std_logic_vector(6 downto 0);
        HEX4 : out std_logic_vector(6 downto 0);
        HEX5 : out std_logic_vector(6 downto 0);

        PS2_CLK : inout std_logic;
        PS2_DAT : inout std_logic;

        VGA_R  : out std_logic_vector(3 downto 0);
        VGA_G  : out std_logic_vector(3 downto 0);
        VGA_B  : out std_logic_vector(3 downto 0);
        VGA_HS : out std_logic;
        VGA_VS : out std_logic
    );
end mouseTop;

architecture rtl of mouseTop is

    signal clk25 : std_logic := '0';
    signal reset : std_logic;

    signal pixel_row    : std_logic_vector(9 downto 0);
    signal pixel_column : std_logic_vector(9 downto 0);

    signal mouse_row : std_logic_vector(9 downto 0);
    signal mouse_col : std_logic_vector(9 downto 0);

    signal left_btn  : std_logic;
    signal right_btn : std_logic;

    signal red_sig   : std_logic;
    signal green_sig : std_logic;
    signal blue_sig  : std_logic;

    signal vga_red_1   : std_logic;
    signal vga_green_1 : std_logic;
    signal vga_blue_1  : std_logic;

    signal player_on : std_logic;

    signal char_addr : std_logic_vector(5 downto 0);
    signal font_row  : std_logic_vector(2 downto 0);
    signal font_col  : std_logic_vector(2 downto 0);
    signal text_bit  : std_logic;
    signal text_on   : std_logic;

    signal mode_select : integer range 0 to 3 := 0;
    signal key3_prev   : std_logic := '1';

    type sprite_rom_t is array (0 to 18) of std_logic_vector(31 downto 0);

constant PLAYER_SPRITE : sprite_rom_t := (
    "00000000000011111111110000000000",
    "00000000000010000000010000000000",
    "00000000000100000000010000000000",
    "00000000000100000101111000000000",
    "00000000000100000101110000000000",
    "00000000000100000001110000000000",
    "00000000000010000001110000000000",
    "00000000000011110001110000000000",
    "00000000000011000001110000000000",
    "00000000000111100010000000000000",
    "00000000000111001001110000000000",
    "00000000000111001001100000000000",
    "00000000000111011111000000000000",
    "00000000000111011111000000000000",
    "00000000000111001001000000000000",
    "00000000000111111001000000000000",
    "00000000000001110010000000000000",
    "00000000000000111100000000000000",
    "00000000000000111100000000000000"
);

    function hex7seg(x : std_logic_vector(3 downto 0)) return std_logic_vector is
    begin
        case x is
            when "0000" => return "1000000";
            when "0001" => return "1111001";
            when "0010" => return "0100100";
            when "0011" => return "0110000";
            when "0100" => return "0011001";
            when "0101" => return "0010010";
            when "0110" => return "0000010";
            when "0111" => return "1111000";
            when "1000" => return "0000000";
            when "1001" => return "0010000";
            when "1010" => return "0001000";
            when "1011" => return "0000011";
            when "1100" => return "1000110";
            when "1101" => return "0100001";
            when "1110" => return "0000110";
            when others => return "0001110";
        end case;
    end function;

begin

    reset <= not key(0);

    process(CLOCK_50)
    begin
        if rising_edge(CLOCK_50) then
            clk25 <= not clk25;
        end if;
    end process;

   







	-- KEY3 counts up to show that the button works << MAP THIS TO TEXT OR SOMETHING LATER>>
    process(clk25, reset)
    begin
        if reset = '1' then
            mode_select <= 0;
            key3_prev <= '1';
        elsif rising_edge(clk25) then
            key3_prev <= KEY(3);

            if key3_prev = '1' and KEY(3) = '0' then
                if mode_select = 3 then
                    mode_select <= 0;
                else
                    mode_select <= mode_select + 1;
                end if;
            end if;
        end if;
    end process;
	 
	 
	 
	 
	 

    mouse_inst : entity work.MOUSE
        port map (
            clock_25Mhz         => clk25,
            reset               => reset,
            mouse_data          => PS2_DAT,
            mouse_clk           => PS2_CLK,
            left_button         => left_btn,
            right_button        => right_btn,
            mouse_cursor_row    => mouse_row,
            mouse_cursor_column => mouse_col
        );

    char_inst : entity work.char_rom
        port map (
            character_address => char_addr,
            font_row          => font_row,
            font_col          => font_col,
            clock             => clk25,
            rom_mux_output    => text_bit
        );

    process(pixel_column, pixel_row, mouse_col, mouse_row)
        variable px : integer;
        variable py : integer;
        variable mx : integer;
        variable my : integer;
        variable sx : integer;
        variable sy : integer;
    begin
        px := to_integer(unsigned(pixel_column));
        py := to_integer(unsigned(pixel_row));
        mx := to_integer(unsigned(mouse_col));
        my := to_integer(unsigned(mouse_row));

        player_on <= '0';

        if (px >= mx) and (px < mx + 32) and
           (py >= my) and (py < my + 32) then

            sx := px - mx;
            sy := py - my;

            if PLAYER_SPRITE(sy)(31 - sx) = '1' then
                player_on <= '1';
            end if;
        end if;
    end process;

    -- BIG TEXT: each 8x8 font pixel becomes 2x2 pixels, so text is 16 high.
    process(pixel_column, pixel_row, mode_select)
        variable px  : integer;
        variable py  : integer;
        variable rx  : integer;
        variable ry  : integer;
        variable idx : integer;
    begin
        px := to_integer(unsigned(pixel_column));
        py := to_integer(unsigned(pixel_row));

        text_on   <= '0';
        char_addr <= "000000";
        font_row  <= "000";
        font_col  <= "000";

        if (px >= 40) and (px < 184) and -- 9 px wide?
           (py >= 40) and (py < 56) then

            rx := px - 40;
            ry := py - 40;

            idx := rx / 16;

            font_col <= std_logic_vector(to_unsigned((rx mod 16) / 2, 3));
            font_row <= std_logic_vector(to_unsigned(ry / 2, 3));

            text_on <= '1';

 
                  -- Always display: VHDL FANS
						case idx is
								when 0 => char_addr <= "010110"; -- V
								when 1 => char_addr <= "001000"; -- H
								when 2 => char_addr <= "000100"; -- D
								when 3 => char_addr <= "001100"; -- L
								when 4 => char_addr <= "100000"; -- SPACE
								when 5 => char_addr <= "000110"; -- F
								when 6 => char_addr <= "000001"; -- A
    							when 7 => char_addr <= "001110"; -- N
								when 8 => char_addr <= "010011"; -- S
								when others => text_on <= '0';
                    end case;
        end if;
    end process;

    red_sig   <= player_on or (text_on and text_bit);
    green_sig <= (left_btn and player_on) or (text_on and text_bit);
    blue_sig  <= right_btn and player_on;

    
	 
	 -- VGA STUFF HERE
	 vga_inst : entity work.VGA_SYNC
        port map (
            clock_25Mhz    => clk25,
            red            => red_sig,
            green          => green_sig,
            blue           => blue_sig,
            red_out        => vga_red_1,
            green_out      => vga_green_1,
            blue_out       => vga_blue_1,
            horiz_sync_out => VGA_HS,
            vert_sync_out  => VGA_VS,
            pixel_row      => pixel_row,
            pixel_column   => pixel_column
        );

    VGA_R <= (others => vga_red_1);
    VGA_G <= (others => vga_green_1);
    VGA_B <= (others => vga_blue_1);

    HEX0 <= hex7seg(mouse_col(3 downto 0));
    HEX1 <= hex7seg(mouse_col(7 downto 4));
    HEX2 <= hex7seg(mouse_row(3 downto 0));
    HEX3 <= hex7seg(mouse_row(7 downto 4));
    HEX4 <= hex7seg(std_logic_vector(to_unsigned(mode_select, 4)));
    HEX5 <= hex7seg(SW(3 downto 0));

    LEDR <= SW;

end rtl;