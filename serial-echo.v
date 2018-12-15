/** \file
 * Test the serial input/output to the FTDI chip.
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

	wire clk_48;
	wire reset = 0;
	SB_HFOSC u_hfosc (
		.CLKHFPU(1'b1),
		.CLKHFEN(1'b1),
		.CLKHF(clk_48)
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
	wire clk_1, clk_4;
	divide_by_n #(.N(48)) div1(clk_48, reset, clk_1);
	divide_by_n #(.N(12)) div4(clk_48, reset, clk_4);

	reg [7:0] uart_txd;
	reg uart_txd_strobe;
	wire uart_txd_ready;

	wire [7:0] uart_rxd;
	wire uart_rxd_strobe;

	uart_tx txd(
		.mclk(clk_48),
		.reset(reset),
		.baud_x1(clk_1),
		.serial(serial_txd),
		.ready(uart_txd_ready),
		.data(uart_txd),
		.data_strobe(uart_txd_strobe)
	);

	uart_rx rxd(
		.mclk(clk_48),
		.reset(reset),
		.baud_x4(clk_4),
		.serial(serial_rxd),
		.data(uart_rxd),
		.data_strobe(uart_rxd_strobe)
	);

	assign debug0 = serial_txd;

	reg fifo_read_strobe;
	wire fifo_available;

	fifo buffer(
		.clk(clk_48),
		.reset(reset),
		.write_data(uart_rxd),
		.write_strobe(uart_rxd_strobe),
		.data_available(fifo_available),
		.read_data(uart_txd),
		.read_strobe(fifo_read_strobe)
	);

/*
	always @(posedge clk_48) begin
		// when new data arrives, write it to the tx buffer
		if (uart_rxd_strobe) begin
			buffer[write_ptr] <= uart_rxd;
			//buffer_write <= uart_rxd;
			write_ptr <= write_ptr + 1;
		end

	end
*/
	always @(posedge clk_48) begin
		uart_txd_strobe <= 0;
		fifo_read_strobe <= 0;
		led_r <= 1;

		if (fifo_available && uart_txd_ready && !uart_txd_strobe) begin
			fifo_read_strobe <= 1;
			uart_txd_strobe <= 1;
		end
	end
endmodule
