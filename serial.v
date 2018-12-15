/** \file
 * Test the serial output to the FTDI cable.
 *
 * The schematic disagrees with the PCF, but the PCF works...
 *
 * The SPI flash chip select *MUST* be pulled high to disable the
 * flash chip, otherwise they will both be driving the bus.
 *
 * This may interfere with programming; `iceprog -e 128` should erase enough
 * to make it compliant for re-programming
 *
 * The USB port will have to be cycled to get the FTDI to renumerate as
 * /dev/ttyUSB0.  Not sure what is going on with iceprog.
 */

module top(
	output led_r,
	output led_g,
	output led_b,
	output serial_txd,
	input serial_rxd,
	output spi_cs,
	output debug0
);
	assign spi_cs = 1; // it is necessary to turn off the SPI flash chip

	wire clk_48, clk_96, locked;
	wire reset = !locked;
	SB_HFOSC u_hfosc (
		.CLKHFPU(1'b1),
		.CLKHFEN(1'b1),
		.CLKHF(clk_48)
	);

	pll_32 pll(
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

	// generate a 1 MHz serial clock from the 48 MHz clock
	reg clk_3;
	reg [5:0] clk_3_counter;
	always @(posedge clk_48)
	begin
		clk_3 <= 0;
		if (reset)
			clk_3_counter <= 0;
		else
		if (clk_3_counter == 48)
		begin
			clk_3 <= 1;
			clk_3_counter <= 0;
		end else
			clk_3_counter <= clk_3_counter + 1;
	end

	reg [7:0] uart_txd;
	reg uart_txd_strobe;
	wire uart_txd_ready;

	uart_tx txd(
		.mclk(clk_48),
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
		uart_txd_strobe <= 0;

		if (reset) begin
			// nothing
			byte_counter <= 0;
		end else
		if (uart_txd_ready && !uart_txd_strobe && counter[15:0] == 0) begin
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
		end
	end
endmodule

