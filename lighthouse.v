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
	reg [71:0] timer_fifo_write;
	reg timer_fifo_write_strobe;
	wire timer_fifo_available;
	wire [71:0] timer_fifo_read;
	reg timer_fifo_read_strobe;

	fifo #(.WIDTH(8*3*3),.NUM(256)) timer_fifo(
		.clk(clk_48),
		.reset(reset),
		.data_available(timer_fifo_available),
		.write_data(timer_fifo_write),
		.write_strobe(timer_fifo_write_strobe),
		.read_data(timer_fifo_read),
		.read_strobe(timer_fifo_read_strobe)
	);

	wire [23:0] sync0_a;
	wire [23:0] sync1_a;
	wire [23:0] sweep_a;
	wire sweep_strobe_a;

	lighthouse_sweep sensor_a(
		.clk(clk_48),
		.reset(reset),
		.raw_pin(lighthouse_a),
		.sync0(sync0_a),
		.sync1(sync1_a),
		.sweep(sweep_a),
		.sweep_strobe(sweep_strobe_a)
	);

	always @(posedge clk_48)
	begin
		timer_fifo_write_strobe <= 0;

		if (sweep_strobe_a)
		begin
			timer_fifo_write <= {
				sync0_a,
				sync1_a,
				sweep_a
			};
			timer_fifo_write_strobe <= 1;
		end
	end

	reg [71:0] out;
	reg [5:0] out_bytes;

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
			else begin
				uart_txd <= hexdigit(out[71:68]);
			end

			out <= { out[68:0], 4'b0 };
		end else
		if (timer_fifo_available)
		begin
			out <= timer_fifo_read;
			timer_fifo_read_strobe <= 1;
			out_bytes <= 20;
		end
	end

endmodule


/*
 * Measure the raw sweep times for the sensor.
 * This also reports the lengths of the two sync pulses so that
 * the correct axis and OOTX can be assigned.

                 Sync      Data      Angle
                <----->   <-----><------------>
_____   ________       ___       _____________   ___________
     |_|        |_____|   |_____|             |_|
    Sweep        Sync0     Sync1             Sweep

 */
module lighthouse_sweep(
	input clk,
	input reset,
	input raw_pin,
	output reg [WIDTH-1:0] sync0,
	output reg [WIDTH-1:0] sync1,
	output reg [WIDTH-1:0] sweep,
	output sweep_strobe
);
	parameter WIDTH = 24;
	parameter CLOCKS_PER_MICROSECOND = 48;

	wire rise_strobe;
	wire fall_strobe;
	reg [WIDTH-1:0] counter;
	reg [WIDTH-1:0] last_rise;
	reg [WIDTH-1:0] last_fall;
	reg got_sweep;

	// time low
	wire [WIDTH-1:0] len = counter - last_fall;
	wire [WIDTH-1:0] duty = counter - last_rise;

	edge_capture edge(
		.clk(clk),
		.reset(reset),
		.raw_pin(raw_pin),
		.rise_strobe(rise_strobe),
		.fall_strobe(fall_strobe)
	);

	always @(posedge clk)
	begin
		sweep_strobe <= 0;
		counter <= counter + 1;

		if (reset)
		begin
			counter <= 0;
			last_fall <= 0;
			last_rise <= 0;
			got_sweep <= 0;
		end else
		if (fall_strobe)
		begin
			// record the time of the falling strobe
			last_fall <= counter;
		end else
		if (rise_strobe)
		begin
			if (len < 15 * CLOCKS_PER_MICROSECOND) begin
				// this was a sweep!
				got_sweep <= 1;

				// signal that we have something
				sweep_strobe <= 1;

				// time is from the last rising edge to
				// the midpoint of the sweep pulse
				//sweep <= counter - len/2 - last_rise;
				sweep <= duty[23:4];
			end else
			if (got_sweep) begin
				// first non-sweep pulse after a sweep
				sync0 <= len;
				got_sweep <= 0;
			end else begin
				// second non-sweep pulse
				sync1 <= len;
			end
		end
	end

endmodule


module edge_capture(
	input clk,
	input reset,
	input raw_pin,
	output rise_strobe,
	output fall_strobe
);
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

		if (reset) begin
			// nothing to do
		end else
		if (pin2 != pin1) begin
			rise_strobe <= !pin2;
			fall_strobe <=  pin2;
		end
	end

endmodule
