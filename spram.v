/** \file
 * Single Ported RAM wrapper.
 *
 * The up5k has 1024 Kb of single ported block RAM.
 * This is can't read/write simultaneously, so it is necessary to
 * mux the read/write pins.
 *
 * Implement an 8-bit wide SPRAM using the 16-bit wide 16K block.
 */

module spram_32k(
	input clk,
	input reset,
	input wren,
	input cs,
	input [14:0] addr,
	input [7:0] write_data,
	output [7:0] read_data
);
	wire align = addr[0];
	wire [15:0] rdata_16;
	assign read_data = align ? rdata_16[15:8] : rdata_16[7:0];

	SB_SPRAM256KA ram(
		// read 16 bits at a time
		.DATAOUT(rdata_16),

		// ignore the bottom bit
		.ADDRESS(addr[14:1]),

		// duplicate the write data into both bytes
		.DATAIN({write_data, write_data}),

		// select writes to either top or bottom byte
		.MASKWREN({align, align, !align, !align}),
		.WREN(wren),

		.CHIPSELECT(cs && !reset),
		.CLOCK(clk),

		// if we cared about power, maybe we would adjust these
		.STANDBY(1'b0),
		.SLEEP(1'b0),
		.POWEROFF(1'b1)
	);

endmodule


// This works like the dual-ported FIFO, but the read_data is
// only available when write_strobe is not set.
module fifo_spram(
	input clk,
	input reset,
	output data_available,
	input [WIDTH-1:0] write_data,
	input write_strobe,
	output [WIDTH-1:0] read_data,
	input read_strobe
);
	parameter WIDTH = 8;
	parameter BITS = 15;

	reg [BITS-1:0] write_ptr;
	reg [BITS-1:0] read_ptr;

	spram_32k mem(
		.clk(clk),
		.reset(reset),
		.cs(1),
		.wren(write_strobe),
		.addr(write_strobe ? write_ptr : read_ptr),
		.write_data(write_data),
		.read_data(read_data)
	);

	assign data_available = read_ptr != write_ptr;

	always @(posedge clk)
	begin
		if (reset) begin
			write_ptr <= 0;
			read_ptr <= 0;
		end else begin
			if (write_strobe)
				write_ptr <= write_ptr + 1;
			if (read_strobe)
				read_ptr <= read_ptr + 1;
		end
	end

endmodule
