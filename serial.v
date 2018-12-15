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
	input serial_rxd,
	output debug0
);
	wire clk_48, clk_96, locked;
	wire reset = !locked;
	SB_HFOSC u_hfosc (
		.CLKHFPU(1'b1),
		.CLKHFEN(1'b1),
		.CLKHF(clk_48)
	);

	pll_96 pll(
		.clock_in(clk_48),
		.clock_out(clk_96),
		.locked(locked)
	);

	reg [31:0] counter;

	always @(posedge clk_48)
		if (reset)
			counter <= 0;
		else
			counter <= counter + 1;

	assign led_g = 1;
	assign led_b = serial_rxd; // idles high

	// generate a 3 MHz serial clock from the 96 MHz clock
	reg [4:0] counter_96;
	wire clk_3;
	assign clk_3 = (counter_96 == 5'b0);
	always @(posedge clk_96)
		counter_96 <= counter_96 + 1;

	reg [7:0] uart_txd;
	reg uart_txd_strobe;
	wire uart_txd_ready;

	uart_tx txd(
		.mclk(clk_96),
		.reset(reset),
		.baud_x1(clk_3),
		.serial(serial_txd),
		.ready(uart_txd_ready),
		.data(uart_txd),
		.data_strobe(uart_txd_strobe)
	);

	assign debug0 = serial_txd;
	reg [3:0] byte_counter;

	always @(posedge clk_48) begin
		led_r <= 1;

		if (reset) begin
			// nothing
			byte_counter <= 0;
			uart_txd_strobe <= 0;
		end else
		if (uart_txd_ready && !uart_txd_strobe && counter[20:0] == 0) begin
			// ready to send a new byte
			uart_txd_strobe <= 1;

			if (byte_counter == 0)
				uart_txd <= "\r";
			else
			if (byte_counter == 1)
				uart_txd <= "\n";
			else
				uart_txd <= 8'h41 + byte_counter - 2;
			byte_counter <= byte_counter + 1;
			led_r <= 0;
		end else begin
			uart_txd_strobe <= 0;
		end
	end
endmodule

