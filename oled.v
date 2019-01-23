`include "util.v"

/*
 * Connect a WEH001602A OLED Character 16x2 to the TinyFPGA
 *
 *  1 Gnd
 *  2 Vcc (3.3v)
 *  3 NC
 *  4 RS
 *  5 R/!W
 *  6 E
 *  7 DB0
 *  8 DB1
 *  9 DB2
 * 10 DB3
 * 11 DB4
 * 12 DB5
 * 13 DB6
 * 14 DB7
 * 15 NC (button?)
 * 16 NC (button?)
 */
module top(
	input pin_clk,
	output pin_led,

	output pin_1, // rs
	output pin_2, // r
	output pin_3, // e
	inout  pin_4, // db0
	inout  pin_5, // db1
	inout  pin_6, // db2
	inout  pin_7, // db3
	inout  pin_8, // db4
	inout  pin_9, // db5
	inout  pin_10, // db6
	inout  pin_11 // db7
);
	wire clk_48mhz, locked;
	wire reset = !locked;
	pll pll_inst(pin_clk, clk_48mhz, locked);

	// generate a 2 MHz clock from the 16 MHz input
	wire clk_24mhz, clk_12mhz, clk_6mhz, clk_3mhz, clk_1mhz;
	wire clk_500khz, clk_250khz, clk_100khz;
	always @(posedge clk_48mhz) clk_24mhz = !clk_24mhz;
	always @(posedge clk_24mhz) clk_12mhz = !clk_12mhz;
	always @(posedge clk_12mhz) clk_6mhz = !clk_6mhz;
	always @(posedge clk_6mhz) clk_3mhz = !clk_3mhz;
	always @(posedge clk_3mhz) clk_1mhz = !clk_1mhz;
	always @(posedge clk_1mhz) clk_500khz = !clk_500khz;
	always @(posedge clk_500khz) clk_250khz = !clk_250khz;
	always @(posedge clk_250khz) clk_100khz = !clk_100khz;
	wire clk = clk_3mhz;
/*
	wire clk;
	divide_by_n #(.N(64)) div(clk_48mhz, reset, clk);
*/

	wire oled_ready;
	reg [8:0] oled_cmd;
	reg oled_strobe;
	reg oled_wait;

	oled oled_inst(
		.clk(clk),
		.reset(reset),
		//.debug(pin_led),

		// physical connection
		.rs_pin(pin_1),
		.read_pin(pin_2),
		.enable_pin(pin_3),
		.db_pins({
			pin_11,
			pin_10, 
			pin_9,
			pin_8,
			pin_7,
			pin_6,
			pin_5,
			pin_4
		}),

		// commands
		.ready(oled_ready),
		.command(oled_cmd),
		.strobe(oled_strobe),
		.wait_for_busy(oled_wait)
	);

	reg [3:0] counter;
	reg [4:0] out;

	localparam INIT0 = 0;
	localparam INIT1 = 1;
	localparam INIT2 = 2;
	localparam INIT3 = 3;
	localparam INIT4 = 4;
	localparam DRAW = 5;
	localparam DRAW2 = 6;
	reg [3:0] state = INIT0;

                           //0123456789abcdef0123456789abcdef
	reg [32*8-1:0] message = "TinyFPGA-BX            OLED 16x2";

	always @(posedge clk)
	begin
		if (reset)
			state <= INIT0;
		else begin

		if (oled_ready)
			counter <= counter + 1;

		oled_strobe <= 0;

		if (oled_ready)
		case (state)
		INIT0: begin
			pin_led <= 1;
			// function set
			oled_cmd <= {
				1'b0, // rs
				3'b001,
				1'b1, // 8-bit data length
				1'b1, // two lines
				1'b0, // first font
				2'b00 // font table 0
			};
			oled_wait <= 1;
			oled_strobe <= 1;
			state <= INIT1;
		end
		INIT1: begin
			// power off
			oled_cmd <= {
				1'b0, // rs
				4'b0001,
				1'b1, // character mode
				1'b1, // power off mode
				1'b1, // 
				1'b1  //
			};
			oled_wait <= 1;
			oled_strobe <= 1;
			state <= INIT2;
		end
		INIT2: begin
			// display on/off control
			oled_cmd <= {
				1'b0, // rs
				5'b00001,
				1'b1, // entire display on
				1'b1, // no cursor
				1'b0  // no blink
			};
			oled_wait <= 1;
			oled_strobe <= 1;
			state <= INIT3;
		end
		INIT3: begin
			// display clear
			oled_cmd <= 9'b000000001;
			oled_wait <= 1;
			oled_strobe <= 1;
			state <= INIT4;
		end
		INIT4: begin
			// entry mode set
			oled_cmd <= {
				1'b0, // rs
				6'b000001,
				1'b1, // increment on every write
				1'b0  // no display shift
			};
			oled_wait <= 1;
			oled_strobe <= 1;
			state <= DRAW;
		end
		DRAW: begin
			// go to position
			if (counter == 0)
			begin
			oled_cmd <= { 1'b0, 
				8'h80
				| (out[4] ? 8'h40 : 8'h00)
				| out[3:0]
			};
			oled_strobe <= 1;
			oled_wait <= 1;
			state <= DRAW2;
			end
		end
		DRAW2: begin
			if (counter == 0)
			begin
			pin_led <= !pin_led;
			oled_wait <= 1;
			oled_cmd <= { 1'b1, message[31*8-out*8 +: 8] };
			oled_strobe <= 1;
			state <= DRAW;
			out <= out + 1;
			end
		end
		endcase
		end
	end
endmodule


module oled(
	input clk,
	input reset,
	output debug,

	// physical connection
	inout [7:0] db_pins,
	output read_pin,
	output enable_pin,
	output rs_pin,

	// command input (rs and 8 bits of data)
	output ready,
	input wait_for_busy,
	input [8:0] command,
	input strobe
);
	reg read;
	reg enable;
	reg rs;

	assign read_pin = read;
	assign enable_pin = enable;
	assign rs_pin = rs;

	// only enable to output pins when we are in write mode
	wire [7:0] db_in;
	reg [7:0] db_out = 0;
	SB_IO #(
		.PIN_TYPE(6'b1010_01) // tristatable output
	) db_buffer[7:0] (
		.OUTPUT_ENABLE(!read),
		.PACKAGE_PIN(db_pins),
		.D_IN_0(db_in),
		.D_OUT_0(db_out)
	);

	localparam IDLE = 0;
	localparam SEND_CMD1 = 1;
	localparam SEND_CMD2 = 2;
	localparam SEND_CMD3 = 3;
	localparam WAIT_BUSY = 4;
	localparam WAIT_BUSY1 = 5;
	localparam WAIT_BUSY2 = 6;

	reg [4:0] state = WAIT_BUSY;
	assign ready = state == IDLE;

	always @(posedge clk)
	begin
		if (reset) begin
			state <= WAIT_BUSY;
		end else
		case (state)
		IDLE: begin
			debug <= 0;
			rs <= 0;
			read <= 1;
			enable <= 0;

			if (strobe) begin
				// start a new write
				read <= 0;
				rs <= command[8];
				db_out <= command[7:0];
				state <= SEND_CMD1;
			end
		end
		SEND_CMD1: begin
			// rising edge one clock after the r/w transition
			enable <= 1;
			state <= SEND_CMD2;
		end
		SEND_CMD2: begin
			// LCD clocks in data on this falling edge
			enable <= 0;
			if (wait_for_busy)
				state <= WAIT_BUSY;
			else
				state <= IDLE;
		end
		WAIT_BUSY: begin
			enable <= 0;
			read <= 1;
			rs <= 0;
			state <= WAIT_BUSY1;
		end
		WAIT_BUSY1: begin
			enable <= 1;
			state <= WAIT_BUSY2;
		end
		WAIT_BUSY2: begin
			if (!db_in[7])
				state <= IDLE;
			else
				state <= WAIT_BUSY1;
			enable <= 0;
		end
		endcase
	end
endmodule

/**
 * PLL configuration
 *
 * This Verilog module was generated automatically
 * using the icepll tool from the IceStorm project.
 * Use at your own risk.
 *
 * Given input frequency:        16.000 MHz
 * Requested output frequency:   48.000 MHz
 * Achieved output frequency:    48.000 MHz
 */

module pll(
	input  clock_in,
	output clock_out,
	output locked
	);

SB_PLL40_CORE #(
		.FEEDBACK_PATH("SIMPLE"),
		.DIVR(4'b0000),		// DIVR =  0
		.DIVF(7'b0101111),	// DIVF = 47
		.DIVQ(3'b100),		// DIVQ =  4
		.FILTER_RANGE(3'b001)	// FILTER_RANGE = 1
	) uut (
		.LOCK(locked),
		.RESETB(1'b1),
		.BYPASS(1'b0),
		.REFERENCECLK(clock_in),
		.PLLOUTCORE(clock_out)
		);

endmodule
