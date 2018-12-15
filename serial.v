/** \file
 * Test the serial output to the FTDI cable.
 *
 * This didn't work in other tests...
 */

module top(
	output led_r,
	output led_g,
	output led_b,
	output serial_txd,
	input serial_rxd
);
	wire clk_48;
	SB_HFOSC u_hfosc (
		.CLKHFPU(1'b1),
		.CLKHFEN(1'b1),
		.CLKHF(clk_48)
	);

	reg [31:0] counter;

	always @(posedge clk_48)
		counter <= counter + 1;

	assign led_r = 1;
	assign led_g = 1;
	assign led_b = serial_rxd; // idles high


endmodule

