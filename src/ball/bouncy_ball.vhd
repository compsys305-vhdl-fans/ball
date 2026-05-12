LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.all;
USE  IEEE.STD_LOGIC_ARITH.all;
USE  IEEE.STD_LOGIC_SIGNED.all;


ENTITY bouncy_ball IS
	PORT (
		pb1, pb2, clk, vert_sync	: IN std_logic;
		pixel_row, pixel_column		: IN std_logic_vector(9 DOWNTO 0);
		mouse_x, mouse_y			: IN std_logic_vector(9 DOWNTO 0);
		mouse_left, mouse_right		: IN std_logic;
		red, green, blue 			: OUT std_logic
	);
END bouncy_ball;

architecture behavior of bouncy_ball is
	SIGNAL ball_on			: std_logic;
	SIGNAL mouse_on_ball	: std_logic;
	SIGNAL prev_mouse_left	: std_logic := '0';
	SIGNAL size 			: std_logic_vector(9 DOWNTO 0);  
	SIGNAL ball_y_pos		: std_logic_vector(9 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(240,10);
	SiGNAL ball_x_pos		: std_logic_vector(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(590,11);
	SIGNAL ball_y_motion	: std_logic_vector(9 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(2,10);
	SIGNAL ball_x_motion	: std_logic_vector(10 DOWNTO 0) := (OTHERS => '0');
	SIGNAL random_bits		: std_logic_vector(7 DOWNTO 0) := "10101101";
BEGIN
	size <= CONV_STD_LOGIC_VECTOR(8,10);
	-- ball_x_pos and ball_y_pos show the (x,y) for the centre of ball

	ball_on <= '1' when (
			-- x_pos - size <= pixel_column <= x_pos + size
			('0' & ball_x_pos <= '0' & pixel_column + size) and
			('0' & pixel_column <= '0' & ball_x_pos + size) and
			-- y_pos - size <= pixel_row <= y_pos + size
			('0' & ball_y_pos <= '0' & pixel_row + size) and
			('0' & pixel_row <= '0' & ball_y_pos + size)
		) else '0';

	mouse_on_ball <= '1' when (
			-- x_pos - size <= mouse_x <= x_pos + size
			(CONV_INTEGER('0' & mouse_x) + CONV_INTEGER('0' & size) >= CONV_INTEGER(ball_x_pos)) and
			(CONV_INTEGER('0' & mouse_x) <= CONV_INTEGER(ball_x_pos) + CONV_INTEGER('0' & size)) and
			-- y_pos - size <= mouse_y <= y_pos + size
			(CONV_INTEGER('0' & mouse_y) + CONV_INTEGER('0' & size) >= CONV_INTEGER('0' & ball_y_pos)) and
			(CONV_INTEGER('0' & mouse_y) <= CONV_INTEGER('0' & ball_y_pos) + CONV_INTEGER('0' & size))
		) else '0';


	-- Colours for pixel data on video signal
	-- Changing the background and ball colour by pushbuttons
	Red <= pb1;
	Green <= (not pb2) and (not ball_on);
	Blue <=  not ball_on;


	Move_Ball: process (vert_sync)
		variable next_x_motion : std_logic_vector(10 DOWNTO 0);
		variable next_y_motion : std_logic_vector(9 DOWNTO 0);
	begin
		-- Move ball once every vertical sync
		if (rising_edge(vert_sync)) then			
			next_x_motion := ball_x_motion;
			next_y_motion := ball_y_motion;

			-- Keep the random generator out of the all-zero lock-up state.
			if (random_bits = "00000000") then
				random_bits <= "10101101";
			else
				random_bits <= random_bits(6 DOWNTO 0) & (random_bits(7) xor random_bits(5) xor random_bits(4) xor random_bits(3));
			end if;

			-- Pick a new random diagonal direction when the left mouse button
			-- is clicked while the pointer is inside the ball.
			if (mouse_left = '1' and prev_mouse_left = '0' and mouse_on_ball = '1') then
				case random_bits(1 DOWNTO 0) is
					when "00" =>
						next_x_motion := CONV_STD_LOGIC_VECTOR(2,11);
						next_y_motion := CONV_STD_LOGIC_VECTOR(2,10);
					when "01" =>
						next_x_motion := -CONV_STD_LOGIC_VECTOR(2,11);
						next_y_motion := CONV_STD_LOGIC_VECTOR(2,10);
					when "10" =>
						next_x_motion := CONV_STD_LOGIC_VECTOR(2,11);
						next_y_motion := -CONV_STD_LOGIC_VECTOR(2,10);
					when others =>
						next_x_motion := -CONV_STD_LOGIC_VECTOR(2,11);
						next_y_motion := -CONV_STD_LOGIC_VECTOR(2,10);
				end case;
			end if;

			-- Bounce off the edges of the screen
			if (ball_x_pos >= CONV_STD_LOGIC_VECTOR(639,11) - ('0' & size)) then
				next_x_motion := -CONV_STD_LOGIC_VECTOR(2,11);
			elsif (ball_x_pos <= ('0' & size)) then 
				next_x_motion := CONV_STD_LOGIC_VECTOR(2,11);
			end if;

			if ( ('0' & ball_y_pos >= CONV_STD_LOGIC_VECTOR(479,10) - size) ) then
				next_y_motion := -CONV_STD_LOGIC_VECTOR(2,10);
			elsif (ball_y_pos <= size) then 
				next_y_motion := CONV_STD_LOGIC_VECTOR(2,10);
			end if;

			-- Compute next ball position
			ball_x_motion <= next_x_motion;
			ball_y_motion <= next_y_motion;
			ball_x_pos <= ball_x_pos + next_x_motion;
			ball_y_pos <= ball_y_pos + next_y_motion;
			prev_mouse_left <= mouse_left;
		end if;
	end process Move_Ball;
END behavior;
