LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY PROJECT_CONFIG;
USE PROJECT_CONFIG.TYPES.ALL;

ENTITY top IS
    PORT (
        CLOCK_50 : IN STD_LOGIC;

        KEY  : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        SW   : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        LEDR : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);

        HEX0 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        HEX1 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        HEX2 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        HEX3 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        HEX4 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        HEX5 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);

        PS2_CLK : INOUT STD_LOGIC;
        PS2_DAT : INOUT STD_LOGIC;

        VGA_R  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        VGA_G  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        VGA_B  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        VGA_HS : OUT STD_LOGIC;
        VGA_VS : OUT STD_LOGIC
    );
END top;

ARCHITECTURE rtl OF top IS
    -- Divide the DE0 50 MHz clock down to the 25 MHz VGA pixel clock.
    SIGNAL clk25 : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC;

    -- Current VGA pixel from the hardware VGA controller.
    SIGNAL screen_pos : SCREEN;

    SIGNAL pixel_row    : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL pixel_column : STD_LOGIC_VECTOR(9 DOWNTO 0);

    -- Mouse coordinates are named as screen column/row for the draw code.
    SIGNAL mouse_row : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL mouse_col : STD_LOGIC_VECTOR(9 DOWNTO 0);

    SIGNAL left_btn  : STD_LOGIC;
    SIGNAL right_btn : STD_LOGIC;

    SIGNAL key1_pressed : STD_LOGIC;
    SIGNAL key2_pressed : STD_LOGIC;

    SIGNAL ball_red   : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL ball_green : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL ball_blue  : STD_LOGIC_VECTOR(3 DOWNTO 0);

    SIGNAL red_sig   : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL green_sig : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL blue_sig  : STD_LOGIC_VECTOR(3 DOWNTO 0);

    SIGNAL vga_red_4   : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL vga_green_4 : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL vga_blue_4  : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL vga_vsync_1 : STD_LOGIC;

    -- Per-pixel masks for overlays drawn on top of the ball scene.
    SIGNAL player_on : STD_LOGIC;
    SIGNAL title_on  : STD_LOGIC;

    -- KEY3 cycles this value; HEX4 shows it as a quick button sanity check.
    SIGNAL mode_select : INTEGER RANGE 0 TO 3 := 0;
    SIGNAL key3_prev   : STD_LOGIC := '1';

    -- Scientist cursor bitmap: 1 means draw the cursor at that pixel.
    CONSTANT PLAYER_WIDTH  : INTEGER := 21;
    CONSTANT PLAYER_HEIGHT : INTEGER := 33;
    TYPE sprite_rom_t IS ARRAY (0 TO PLAYER_HEIGHT - 1) OF STD_LOGIC_VECTOR(PLAYER_WIDTH - 1 DOWNTO 0);

    CONSTANT PLAYER_SPRITE : sprite_rom_t := (
        "111100000000000000000",
        "100000000000000000000",
        "101000111111111000000",
        "100011000000000110000",
        "000100000000000001100",
        "001000000000000000010",
        "001000000000000000001",
        "001000101000000000010",
        "001000101001111111100",
        "001000101001000000100",
        "001000101001000000100",
        "001000101001000000100",
        "000100000001000000100",
        "000010001001000000100",
        "000010001001000000100",
        "000111000000100000100",
        "001001000000011111100",
        "001001111000000000010",
        "001001100100000000010",
        "001001000100000000100",
        "001001000110000001000",
        "001001000111000010000",
        "001001001011111100000",
        "001001001000111100000",
        "001001001000000100000",
        "001001000100000100000",
        "001011000100000100000",
        "000111100100000100000",
        "000000111000000100000",
        "000000100000001000000",
        "000000100000010000000",
        "000000011111100000000",
        "000000011111100000000"
    );

    FUNCTION hex7seg(x : STD_LOGIC_VECTOR(3 DOWNTO 0)) RETURN STD_LOGIC_VECTOR IS BEGIN
        -- Seven-segment outputs are active low on the DE0-CV board.
        CASE x IS
            WHEN "0000" => RETURN "1000000";
            WHEN "0001" => RETURN "1111001";
            WHEN "0010" => RETURN "0100100";
            WHEN "0011" => RETURN "0110000";
            WHEN "0100" => RETURN "0011001";
            WHEN "0101" => RETURN "0010010";
            WHEN "0110" => RETURN "0000010";
            WHEN "0111" => RETURN "1111000";
            WHEN "1000" => RETURN "0000000";
            WHEN "1001" => RETURN "0010000";
            WHEN "1010" => RETURN "0001000";
            WHEN "1011" => RETURN "0000011";
            WHEN "1100" => RETURN "1000110";
            WHEN "1101" => RETURN "0100001";
            WHEN "1110" => RETURN "0000110";
            WHEN OTHERS => RETURN "0001110";
        END CASE;
    END FUNCTION hex7seg;

    FUNCTION title_row(char_index : INTEGER; row_index : INTEGER) RETURN STD_LOGIC_VECTOR IS BEGIN
        -- Tiny 5x7 bitmap font for "VHDL FANS".
        CASE char_index IS
            -- V
            WHEN 0 =>
                CASE row_index IS
                    WHEN 0 => RETURN "10001";
                    WHEN 1 => RETURN "10001";
                    WHEN 2 => RETURN "10001";
                    WHEN 3 => RETURN "10001";
                    WHEN 4 => RETURN "10001";
                    WHEN 5 => RETURN "01010";
                    WHEN OTHERS => RETURN "00100";
                END CASE;
            -- H
            WHEN 1 =>
                CASE row_index IS
                    WHEN 0 => RETURN "10001";
                    WHEN 1 => RETURN "10001";
                    WHEN 2 => RETURN "10001";
                    WHEN 3 => RETURN "11111";
                    WHEN 4 => RETURN "10001";
                    WHEN 5 => RETURN "10001";
                    WHEN OTHERS => RETURN "10001";
                END CASE;
            -- D
            WHEN 2 =>
                CASE row_index IS
                    WHEN 0 => RETURN "11110";
                    WHEN 1 => RETURN "10001";
                    WHEN 2 => RETURN "10001";
                    WHEN 3 => RETURN "10001";
                    WHEN 4 => RETURN "10001";
                    WHEN 5 => RETURN "10001";
                    WHEN OTHERS => RETURN "11110";
                END CASE;
            -- L
            WHEN 3 =>
                CASE row_index IS
                    WHEN 0 => RETURN "10000";
                    WHEN 1 => RETURN "10000";
                    WHEN 2 => RETURN "10000";
                    WHEN 3 => RETURN "10000";
                    WHEN 4 => RETURN "10000";
                    WHEN 5 => RETURN "10000";
                    WHEN OTHERS => RETURN "11111";
                END CASE;
            -- Space
            WHEN 4 =>
                RETURN "00000";
            -- F
            WHEN 5 =>
                CASE row_index IS
                    WHEN 0 => RETURN "11111";
                    WHEN 1 => RETURN "10000";
                    WHEN 2 => RETURN "10000";
                    WHEN 3 => RETURN "11110";
                    WHEN 4 => RETURN "10000";
                    WHEN 5 => RETURN "10000";
                    WHEN OTHERS => RETURN "10000";
                END CASE;
            -- A
            WHEN 6 =>
                CASE row_index IS
                    WHEN 0 => RETURN "01110";
                    WHEN 1 => RETURN "10001";
                    WHEN 2 => RETURN "10001";
                    WHEN 3 => RETURN "11111";
                    WHEN 4 => RETURN "10001";
                    WHEN 5 => RETURN "10001";
                    WHEN OTHERS => RETURN "10001";
                END CASE;
            -- N
            WHEN 7 =>
                CASE row_index IS
                    WHEN 0 => RETURN "10001";
                    WHEN 1 => RETURN "11001";
                    WHEN 2 => RETURN "10101";
                    WHEN 3 => RETURN "10011";
                    WHEN 4 => RETURN "10001";
                    WHEN 5 => RETURN "10001";
                    WHEN OTHERS => RETURN "10001";
                END CASE;
            -- S
            WHEN 8 =>
                CASE row_index IS
                    WHEN 0 => RETURN "01111";
                    WHEN 1 => RETURN "10000";
                    WHEN 2 => RETURN "10000";
                    WHEN 3 => RETURN "01110";
                    WHEN 4 => RETURN "00001";
                    WHEN 5 => RETURN "00001";
                    WHEN OTHERS => RETURN "11110";
                END CASE;
            WHEN OTHERS =>
                RETURN "00000";
        END CASE;
    END FUNCTION title_row;
BEGIN
    -- DE0 pushbuttons are active low, so invert them at the boundary.
    reset <= NOT KEY(0);
    key1_pressed <= NOT KEY(1);
    key2_pressed <= NOT KEY(2);

    pixel_column <= STD_LOGIC_VECTOR(TO_UNSIGNED(screen_pos.pixel_x, pixel_column'LENGTH));
    pixel_row <= STD_LOGIC_VECTOR(TO_UNSIGNED(screen_pos.pixel_y, pixel_row'LENGTH));

    PROCESS (CLOCK_50) BEGIN
        IF RISING_EDGE(CLOCK_50) THEN
            clk25 <= NOT clk25;
        END IF;
    END PROCESS;

    PROCESS (clk25, reset) BEGIN
        IF reset = '1' THEN
            mode_select <= 0;
            key3_prev <= '1';
        ELSIF RISING_EDGE(clk25) THEN
            key3_prev <= KEY(3);

            -- Detect one press, not every clock cycle while KEY3 is held.
            IF key3_prev = '1' AND KEY(3) = '0' THEN
                IF mode_select = 3 THEN
                    mode_select <= 0;
                ELSE
                    mode_select <= mode_select + 1;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    mouse_inst : ENTITY work.mouse
        PORT MAP (
            clock_25Mhz  => clk25,
            reset        => reset,
            mouse_data   => PS2_DAT,
            mouse_clk    => PS2_CLK,
            left_button  => left_btn,
            right_button => right_btn,
            out_mouse_x  => mouse_col,
            out_mouse_y  => mouse_row
        );

    ball_inst : ENTITY work.bouncy_ball
        PORT MAP (
            pb1          => key1_pressed,
            pb2          => key2_pressed,
            clk          => clk25,
            vert_sync    => vga_vsync_1,
            pixel_row    => pixel_row,
            pixel_column => pixel_column,
            mouse_x      => mouse_col,
            mouse_y      => mouse_row,
            mouse_left   => left_btn,
            mouse_right  => right_btn,
            red          => ball_red,
            green        => ball_green,
            blue         => ball_blue
        );

    PROCESS (pixel_column, pixel_row, mouse_col, mouse_row)
        VARIABLE px : INTEGER;
        VARIABLE py : INTEGER;
        VARIABLE mx : INTEGER;
        VARIABLE my : INTEGER;
        VARIABLE sx : INTEGER;
        VARIABLE sy : INTEGER;
    BEGIN
        px := TO_INTEGER(UNSIGNED(pixel_column));
        py := TO_INTEGER(UNSIGNED(pixel_row));
        mx := TO_INTEGER(UNSIGNED(mouse_col));
        my := TO_INTEGER(UNSIGNED(mouse_row));

        player_on <= '0';

        IF (px >= mx) AND (px < mx + PLAYER_WIDTH) AND
           (py >= my) AND (py < my + PLAYER_HEIGHT) THEN
            sx := px - mx;
            sy := py - my;

            IF PLAYER_SPRITE(sy)(PLAYER_WIDTH - 1 - sx) = '1' THEN
                player_on <= '1';
            END IF;
        END IF;
    END PROCESS;

    PROCESS (pixel_column, pixel_row)
        VARIABLE px        : INTEGER;
        VARIABLE py        : INTEGER;
        VARIABLE rx        : INTEGER;
        VARIABLE ry        : INTEGER;
        VARIABLE char_idx  : INTEGER;
        VARIABLE glyph_col : INTEGER;
        VARIABLE glyph_row : INTEGER;
        VARIABLE glyph     : STD_LOGIC_VECTOR(4 DOWNTO 0);
    BEGIN
        px := TO_INTEGER(UNSIGNED(pixel_column));
        py := TO_INTEGER(UNSIGNED(pixel_row));

        title_on <= '0';

        -- Draw each 5x7 font pixel as a 2x2 block with blank columns between letters.
        IF (px >= 40) AND (px < 148) AND
           (py >= 40) AND (py < 54) THEN
            rx := px - 40;
            ry := py - 40;
            char_idx := rx / 12;
            glyph_col := (rx MOD 12) / 2;
            glyph_row := ry / 2;

            IF glyph_col < 5 THEN
                glyph := title_row(char_idx, glyph_row);

                IF glyph(4 - glyph_col) = '1' THEN
                    title_on <= '1';
                END IF;
            END IF;
        END IF;
    END PROCESS;

    PROCESS (ball_red, ball_green, ball_blue, player_on, title_on, left_btn, right_btn) BEGIN
        -- Overlay order: title first, then mouse cursor, then the ball/background scene.
        IF title_on = '1' THEN
            red_sig <= x"F";
            green_sig <= x"F";
            blue_sig <= x"F";
        ELSIF player_on = '1' THEN
            red_sig <= x"F";
            green_sig <= (OTHERS => left_btn);
            blue_sig <= (OTHERS => right_btn);
        ELSE
            red_sig <= ball_red;
            green_sig <= ball_green;
            blue_sig <= ball_blue;
        END IF;
    END PROCESS;

    vga_inst : ENTITY work.vga
        PORT MAP (
            clock_25MHz => clk25,
            r_in        => red_sig,
            g_in        => green_sig,
            b_in        => blue_sig,
            r_out       => vga_red_4,
            g_out       => vga_green_4,
            b_out       => vga_blue_4,
            hsync       => VGA_HS,
            vsync       => vga_vsync_1,
            in_screen   => OPEN,
            screen      => screen_pos
        );

    VGA_VS <= vga_vsync_1;

    -- Drive the full 4-bit VGA DAC.
    VGA_R <= vga_red_4;
    VGA_G <= vga_green_4;
    VGA_B <= vga_blue_4;

    -- Debug display: low nibbles of mouse X/Y, KEY3 mode, and switch state.
    HEX0 <= hex7seg(mouse_col(3 DOWNTO 0));
    HEX1 <= hex7seg(mouse_col(7 DOWNTO 4));
    HEX2 <= hex7seg(mouse_row(3 DOWNTO 0));
    HEX3 <= hex7seg(mouse_row(7 DOWNTO 4));
    HEX4 <= hex7seg(STD_LOGIC_VECTOR(TO_UNSIGNED(mode_select, 4)));
    HEX5 <= hex7seg(SW(3 DOWNTO 0));

    LEDR <= SW;
END rtl;
