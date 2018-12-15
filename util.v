/** \file
 * Utility modules.
 */

`define CLOG2(x) \
   x <= 2	 ? 1 : \
   x <= 4	 ? 2 : \
   x <= 8	 ? 3 : \
   x <= 16	 ? 4 : \
   x <= 32	 ? 5 : \
   x <= 64	 ? 6 : \
   x <= 128	 ? 7 : \
   x <= 256	 ? 8 : \
   x <= 512	 ? 9 : \
   x <= 1024	 ? 10 : \
   x <= 2048	 ? 11 : \
   x <= 4096	 ? 12 : \
   x <= 8192	 ? 13 : \
   x <= 16384	 ? 14 : \
   x <= 32768	 ? 15 : \
   x <= 65536	 ? 16 : \
   -1

module divide_by_n(
	input clk,
	input reset,
	output reg out
);
	parameter N = 2;

	reg [`CLOG2(N)-1:0] counter;

	always @(posedge clk)
	begin
		out <= 0;

		if (reset)
			counter <= 0;
		else
		if (counter == 0)
		begin
			out <= 1;
			counter <= N - 1;
		end else
			counter <= counter - 1;
	end
endmodule


module fifo(
	input clk,
	input reset,
	output data_available,
	input [WIDTH-1:0] write_data,
	input write_strobe,
	output [WIDTH-1:0] read_data,
	input read_strobe
);
	parameter WIDTH = 8;
	parameter NUM = 256;

	reg [WIDTH-1:0] buffer[0:NUM-1];
	reg [`CLOG2(NUM)-1:0] write_ptr;
	reg [`CLOG2(NUM)-1:0] read_ptr;

	assign read_data = buffer[read_ptr];
	assign data_available = read_ptr != write_ptr;

	always @(posedge clk) begin
		if (reset) begin
			write_ptr <= 0;
			read_ptr <= 0;
		end else begin
			if (write_strobe) begin
				buffer[write_ptr] <= write_data;
				write_ptr <= write_ptr + 1;
			end
			if (read_strobe) begin
				read_ptr <= read_ptr + 1;
			end
		end
	end
endmodule


module pwm(
	input clk,
	input [7:0] bright,
	output out
);
	reg [7:0] counter;
	always @(posedge clk)
		counter <= counter + 1;

	always @(*)
		out <= counter < bright;

endmodule


/************************************************************************
 *
 * Random utility modules.
 *
 * Micah Dowty <micah@navi.cx>
 *
 ************************************************************************/


module d_flipflop(clk, reset, d_in, d_out);
   input clk, reset, d_in;
   output d_out;

   reg    d_out;

   always @(posedge clk or posedge reset)
     if (reset) begin
         d_out   <= 0;
     end
     else begin
         d_out   <= d_in;
     end
endmodule


module d_flipflop_pair(clk, reset, d_in, d_out);
   input  clk, reset, d_in;
   output d_out;
   wire   intermediate;

   d_flipflop dff1(clk, reset, d_in, intermediate);
   d_flipflop dff2(clk, reset, intermediate, d_out);
endmodule


/*
 * A set/reset flipflop which is set on sync_set and reset by sync_reset.
 */
module set_reset_flipflop(clk, reset, sync_set, sync_reset, out);
   input clk, reset, sync_set, sync_reset;
   output out;
   reg    out;

   always @(posedge clk or posedge reset)
     if (reset)
       out   <= 0;
     else if (sync_set)
       out   <= 1;
     else if (sync_reset)
       out   <= 0;
endmodule


/*
 * Pulse stretcher.
 *
 * When the input goes high, the output goes high
 * for as long as the input is high, or as long as
 * it takes our timer to roll over- whichever is
 * longer.
 */
module pulse_stretcher(clk, reset, in, out);
   parameter BITS = 20;

   input  clk, reset, in;
   output out;
   reg    out;

   reg [BITS-1:0] counter;

   always @(posedge clk or posedge reset)
     if (reset) begin
        out <= 0;
        counter <= 0;
     end
     else if (counter == 0) begin
        out <= in;
        counter <= in ? 1 : 0;
     end
     else if (&counter) begin
        if (in) begin
           out <= 1;
        end
        else begin
           out <= 0;
           counter <= 0;
        end
     end
     else begin
        out <= 1;
        counter <= counter + 1;
     end
endmodule

