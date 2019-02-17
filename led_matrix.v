module top(
	output led_r,
	output gpio_26,
	output gpio_27,
	output gpio_32,
	output gpio_35,
	output gpio_31,
	output gpio_37,
	output gpio_34,
	output gpio_43,
	output gpio_36,
	output gpio_42,
	output gpio_38,
	output gpio_28
);
	wire reset = 0;
	wire clk_48mhz;
	SB_HFOSC osc(1,1, clk_48mhz);
	reg [8:0] counter;
	always @(posedge clk_48mhz) counter <= counter + 1;
	wire clk = clk_48mhz; // counter[0];
	

	wire [2:0] led_addr = {gpio_36, gpio_34, gpio_43};
	assign led_r = 1;
	

	led_matrix matrix(
		.clk(clk),
		.reset(reset),

		// pins
		.led_clk(gpio_38),
		.led_latch(gpio_42),
		.led_oe(gpio_28),
		.led_addr(led_addr),
		.led_r({gpio_35, gpio_27}),
		.led_g({gpio_31, gpio_26}),
		.led_b({gpio_37, gpio_32}),

		//
		.input_clk(0),
		.strobe(0)
	);

endmodule


/*
 * 
 */
module led_matrix(
	input clk,
	input reset,

	// physical interface
	output reg led_clk,
	output reg led_latch,
	output reg led_oe,
	output reg [ADDR_WIDTH-1:0] led_addr,
	output reg [ROWS-1:0] led_r,
	output reg [ROWS-1:0] led_g,
	output reg [ROWS-1:0] led_b,

	// input from caller to update a frame buffer
	input input_clk,
	input [7:0] r,
	input [7:0] g,
	input [7:0] b,
	input [7:0] x,
	input [7:0] y,
	input strobe
);
	parameter ROWS = 2;
	parameter ADDR_WIDTH = 3;
	parameter X_RES = 32;
	parameter Y_SHIFT = 5; // CLOG2(X_RES)
	parameter Y_STRIDE = 8; //1 << ADDR_WIDTH;
	parameter Y_RES = ROWS * Y_STRIDE;

	reg [7:0] bright;
	reg [7:0] led_x;
	reg [7:0] led_y;
	reg [7:0] row;
	reg all_rows_done;
	reg all_pixels_done;

	reg [7:0] framebuffer_r[X_RES * Y_RES - 1 : 0];
	reg [7:0] framebuffer_g[X_RES * Y_RES - 1 : 0];
	reg [7:0] framebuffer_b[X_RES * Y_RES - 1 : 0];

	reg [15:0] pix_offset = (led_y << Y_SHIFT) | led_x;
	wire [7:0] pix_r = framebuffer_r[pix_offset];
	wire [7:0] pix_g = framebuffer_g[pix_offset];
	wire [7:0] pix_b = framebuffer_b[pix_offset];

	initial $readmemh("red.hex", framebuffer_r);
	initial $readmemh("green.hex", framebuffer_g);
	initial $readmemh("blue.hex", framebuffer_b);

	// output logic
	always @(posedge clk)
	begin
		led_clk <= 0;
		led_latch <= 0;

		if (reset)
		begin
			bright <= 0;
			row <= 0;
			led_addr <= 0;
			led_x <= 0;
			led_y <= 0;
			led_oe <= 1;
			all_rows_done <= 0;
			all_pixels_done <= 0;
		end else
		if (all_pixels_done)
		begin
			if (bright == 255) begin
				// have done all of the brightness at this
				// output address, switch off the output
				// and update the output address
				bright <= 0;
				led_oe <= 1;
				led_x <= 0;
				all_pixels_done <= 0;
				all_rows_done <= 0;

				// led_addr will wrap
				led_addr <= led_addr + 1;
				led_y <= led_addr + 1;
			end else begin
				// not yet done with this row
				// increase the brightness
				// and reset to the start of this row
				bright <= bright + 1;
				led_x <= 0;
				all_pixels_done <= 0;
				all_rows_done <= 0;
			end
		end else
		if (all_rows_done)
		begin
			// updated all the rows, clock out this pixel
			// and prepare to clock out the next 
			led_clk <= 1;
			led_y <= led_addr;
			row <= 0;
			all_rows_done <= 0;

			if (led_x == X_RES-1) begin
				// end of the row, latch it and enable output
				all_pixels_done <= 1;
				led_latch <= 1;
				led_oe <= 0;
			end else begin
				led_x <= led_x + 1;
			end
		end else begin
			// update the output bit for this r/g/b
			led_r[row] <= (pix_r >> 1) > bright;
			led_g[row] <= (pix_g >> 1) > bright;
			led_b[row] <= (pix_b >> 1) > bright;

			//led_r[row] <= (led_x << 2) > bright;
			//led_g[row] <= 0; //
			//led_b[row] <= 0; //bright < 200;

			led_y <= led_y + Y_STRIDE;
			if (row == ROWS-1)
				all_rows_done <= 1;
			else
				row <= row + 1;
		end
	end

`ifdef 0

	// input can run in a separate clock domain
	// this might need an input fifo to allow the framebuffer
	// to move into an spram
	always @(posedge input_clk)
	begin
		if (reset) begin
			// nothing to do
		end else
		if (strobe) begin
			framebuffer_r[(y << Y_SHIFT) | x] <= r;
			framebuffer_g[(y << Y_SHIFT) | x] <= g;
			framebuffer_b[(y << Y_SHIFT) | x] <= b;
		end
	end
`endif

endmodule
