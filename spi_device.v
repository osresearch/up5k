/*
 * spi_device.v: Emulates a SPI device in "slave" mode
 *
 * based on scanlime's spi_mem_emu.v - Module for an SPI memory emulator.
 *
 * Portions Copyright (C) 2018 Trammell Hudson
 * Portions Copyright (C) 2009 Micah Dowty
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */


module spi_device #(
	parameter MONITOR=0
)(
	input mclk,
	input reset,
	input spi_cs,		// active low
	input spi_clk,
	input spi_mosi,		// should be inout for dual/quad
	input spi_miso,		// if in monitor mode, need inout for driving
	output reg spi_rx_strobe,
	output reg [7:0] spi_rx_data, // should be 32 bits for quad
	input spi_tx_strobe,
	input [7:0] spi_tx_data,  // should be 32 bits for quad
	output reg [7:0] spi_mon_data // if we are in monitor mode
);

   wire          spi_clk_sync, spi_mosi_sync, spi_miso_sync, spi_cs_sync;
   reg           spi_clk_prev;
   wire          spi_clk_posedge = spi_clk_sync && !spi_clk_prev;
   wire          spi_clk_negedge = !spi_clk_sync && spi_clk_prev;
   reg           spi_miso_out;

   /* Input sync */
   d_flipflop_pair spi_dff_clk(mclk, reset, spi_clk, spi_clk_sync);
   d_flipflop_pair spi_dff_mosi(mclk, reset, spi_mosi, spi_mosi_sync);
   d_flipflop_pair spi_dff_miso(mclk, reset, spi_miso, spi_miso_sync);
   d_flipflop_pair spi_dff_cs(mclk, reset, spi_cs, spi_cs_sync);

   /* For clock edge detection */
   //d_flipflop spi_dff_clk_2(mclk, reset, spi_clk_sync, spi_clk_prev);

   /* Tri-state output buffer.
    *  In monitor mode we always tri-state.
    *  Otherwise use non-sync'ed CS.
    */
   //assign spi_miso = MONITOR || spi_cs ? 1'bZ : spi_miso_out;


   /************************************************
    * Shift register
    */

   reg [2:0]     bit_count;
   reg [7:0]     miso_reg;
   reg [7:0]     mosi_reg;

   always @(posedge mclk)
   begin
     /*
      * Master reset or chip deselect: Reset everything.
      */
	spi_clk_prev <= spi_clk;

     if (reset || spi_cs) begin
        bit_count <= 0;
        mosi_reg <= 0;
        miso_reg <= 8'hFF;
        spi_miso_out <= 1;
        spi_rx_strobe <= 0;
     end

     /*
      * Clock edges: Shift in and increment bit_count on positive
      * edges, shift out on negative edges.
      *
      * Our per-byte state machine begins immediately after the last
      * positive edge in the byte (bit_count == 7), and it must
      * provide a new result to mosi_reg before the next negative edge.
      */
     else if (spi_clk_posedge) begin
        bit_count <= bit_count + 1;
	if (bit_count == 7) begin
		spi_rx_strobe <= 1;
		spi_rx_data <= {mosi_reg[6:0], spi_mosi_sync};
		if (MONITOR)
			spi_mon_data <= { miso_reg[6:0], spi_miso};
	end else begin
		spi_rx_strobe <= 0;
		mosi_reg <= {mosi_reg[6:0], spi_mosi_sync};
		if (MONITOR)
			miso_reg <= { miso_reg[6:0], spi_miso};
	end
     end
     else if (spi_clk_negedge && !MONITOR) begin
	miso_reg <= {miso_reg[6:0], 1'b1};
	spi_miso_out <= miso_reg[7];
	spi_rx_strobe <= 0;
     end else begin
	spi_rx_strobe <= 0;
     end

     /* Input data must occur before the next SPI clock edge.
      * In monitor mode we ignore the tx strobe since data is always output.
      */
     if (spi_tx_strobe && !MONITOR) begin
        miso_reg <= spi_tx_data;
     end
     end

endmodule
