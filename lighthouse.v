/** \file
 * Print the lengths of timer pulses from the lighthouse sensors.
 */
`include "util.v"
`include "uart.v"

module top(
	output led_r,
	output led_g,
	output led_b,
	output serial_txd,
	input serial_rxd,
	output spi_cs,
	output debug0,
	input gpio_18,
	input gpio_28,
	input gpio_38
);
	assign spi_cs = 1; // it is necessary to turn off the SPI flash chip

	// map the sensor
	wire lighthouse_a = gpio_28;

	wire clk_48;
	wire reset = 0;
	SB_HFOSC u_hfosc (
		.CLKHFPU(1'b1),
		.CLKHFEN(1'b1),
		.CLKHF(clk_48)
	);

	// pulse the green LED to know that we're alive
	reg [31:0] counter;
	always @(posedge clk_48)
		counter <= counter + 1;
	wire pwm_g;
	pwm pwm_g_driver(clk_48, 1, pwm_g);
	assign led_g = !(counter[25:23] == 0 && pwm_g);

	assign led_b = serial_rxd; // idles high

	// generate a 3 MHz/12 MHz serial clock from the 48 MHz clock
	// this is the 3 Mb/s maximum supported by the FTDI chip
	wire clk_1, clk_4;
	divide_by_n #(.N(16)) div1(clk_48, reset, clk_1);
	divide_by_n #(.N( 4)) div4(clk_48, reset, clk_4);

	wire [7:0] uart_rxd;
	wire uart_rxd_strobe;

	uart_rx rxd(
		.mclk(clk_48),
		.reset(reset),
		.baud_x4(clk_4),
		.serial(serial_rxd),
		.data(uart_rxd),
		.data_strobe(uart_rxd_strobe)
	);

	assign debug0 = serial_txd;
	assign led_r = serial_txd;

	reg [7:0] uart_txd;
	reg uart_txd_strobe = 0;

	uart_tx_fifo txd(
		.clk(clk_48),
		.reset(reset),
		.baud_x1(clk_1),
		.serial(serial_txd),
		.data(uart_txd),
		.data_strobe(uart_txd_strobe)
	);

	// output buffer
	reg [31:0] timer_fifo_write;
	reg timer_fifo_write_strobe;
	wire timer_fifo_available;
	wire [31:0] timer_fifo_read;
	reg timer_fifo_read_strobe;

	fifo #(.WIDTH(32),.NUM(256)) timer_fifo(
		.clk(clk_48),
		.reset(reset),
		.data_available(timer_fifo_available),
		.write_data(timer_fifo_write),
		.write_strobe(timer_fifo_write_strobe),
		.read_data(timer_fifo_read),
		.read_strobe(timer_fifo_read_strobe)
	);

	// timer delta
	wire rise_strobe_a;
	wire fall_strobe_a;
	wire [23:0] length_a;

	edge_capture edge_a(
		.clk(clk_48),
		.reset(reset),
		.raw_pin(lighthouse_a),
		.rise_strobe(rise_strobe_a),
		.fall_strobe(fall_strobe_a),
		.pulse_length(length_a)
	);

	always @(posedge clk_48)
	begin
		timer_fifo_write_strobe <= 0;

		if (fall_strobe_a)
		begin
			timer_fifo_write <= { 8'h00, length_a };
			timer_fifo_write_strobe <= 1;
		end else
		if (rise_strobe_a)
		begin
			timer_fifo_write <= { 8'h80, length_a };
			timer_fifo_write_strobe <= 1;
		end
	end

	reg [31:0] out = 32'hDECAFBAD;
	reg [4:0] out_bytes = 10;

	always @(posedge clk_48)
	begin
		uart_txd_strobe <= 0;
		timer_fifo_read_strobe <= 0;

		// convert timer deltas to hex digits
		if (out_bytes != 0)
		begin
			uart_txd_strobe <= 1;
			out_bytes <= out_bytes - 1;
			if (out_bytes == 1)
				uart_txd <= "\r";
			else
			if (out_bytes == 2)
				uart_txd <= "\n";
			else if (out_bytes == 10)
				uart_txd <= out[31] ? "+" : "-";
			else begin
				uart_txd <= hexdigit(out[31:28]);
			end

			out <= { out[27:0], 4'b0 };
		end else
		if (timer_fifo_available)
		begin
			out <= timer_fifo_read;
			timer_fifo_read_strobe <= 1;
			out_bytes <= 10;
		end
	end

endmodule


module edge_capture(
	input clk,
	input reset,
	input raw_pin,
	output [WIDTH-1:0] pulse_length,
	output rise_strobe,
	output fall_strobe
);
	parameter WIDTH = 24;

	reg [WIDTH-1:0] counter;
	reg pin0;
	reg pin1;
	reg pin2;

	always @(posedge clk)
	begin
		// defaults
		rise_strobe <= 0;
		fall_strobe <= 0;

		// flop the raw pin the ensure stability
		pin0 <= raw_pin;
		pin1 <= pin0;
		pin2 <= pin1;

		if (reset)
			counter <= 0;
		else
		if (pin2 != pin1) begin
			rise_strobe <=  pin2;
			fall_strobe <= !pin2;
			pulse_length <= counter;
			counter <= 0;
		end else
		if (counter != ~0)
			counter <= counter + 1;
	end

endmodule
