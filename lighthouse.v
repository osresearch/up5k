/** \file
 * Print the lengths of timer pulses from the lighthouse sensors.
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

function [7:0] hexdigit;
	input [3:0] x;
	begin
		hexdigit =
			x == 0 ? "0" :
			x == 1 ? "1" :
			x == 2 ? "2" :
			x == 3 ? "3" :
			x == 4 ? "4" :
			x == 5 ? "5" :
			x == 6 ? "6" :
			x == 7 ? "7" :
			x == 8 ? "8" :
			x == 9 ? "9" :
			x == 10 ? "a" :
			x == 11 ? "b" :
			x == 12 ? "c" :
			x == 13 ? "d" :
			x == 14 ? "e" :
			x == 15 ? "f" :
			"?";
	end
endfunction

	reg [32:0] out;
	reg [4:0] out_bytes;

	always @(posedge clk_48)
	begin
		uart_txd_strobe <= 0;
		if (counter[15:0] == 0)
		begin
			out <= counter;
			out_bytes <= 10;
		end

		if (out_bytes != 0) begin
			uart_txd_strobe <= 1;
			out_bytes <= out_bytes - 1;
			if (out_bytes == 1)
				uart_txd <= "\r";
			else
			if (out_bytes == 2)
				uart_txd <= "\n";
			else begin
				uart_txd <= hexdigit(out[31:28]);
				out <= { out[27:0], 4'b0 };
			end
		end
	end

endmodule
