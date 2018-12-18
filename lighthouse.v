/** \file
 * Interface with a Vive Lighthouse v1
 *
 * Measure the raw sweep times for the sensor.
 * This also reports the lengths of the two sync pulses so that
 * the correct axis and OOTX can be assigned.

                 Data      Data      Angle
                <----->   <-----><------------>
_____   ________       ___       _____________   ___________
     |_|        |_____|   |_____|             |_|
    Sweep        Sync0     Sync1             Sweep

 * Sync0 is from lighthouse A, sync1 is from lighthouse B
 *
 * at 48 MHz every sync pulse is a 512 tick window
 * so we only look at the top few bits,
 * which encode the skip/data/axis bits:
 *
 * length = 3072 + axis*512 + data*1024 + skip*2048
 *
 * This disagrees with https://github.com/nairol/LighthouseRedox/blob/master/docs/Light%20Emissions.md
 * but matches what I've seen on my lighthouses.
 */

/*
 * Parse an entire frame and output the angle at 20-bits of resolution
 * The strobe goes high when there is a valid sensor reading; axis
 * indicates which lighthouse sent it and which rotor on that lighthouse.
 * OOTX data contains both lighthouse OOTX bits
 */
module lighthouse_sensor(
	input clk,
	input reset,
	input raw_pin,
	output strobe,
	output [ANGLE_BITS-1:0] angle,
	output lighthouse,
	output axis,
	output [1:0] ootx,
);
	parameter WIDTH = 20;
	parameter MHZ = 48;
	parameter ANGLE_BITS = 20;

	wire sweep_strobe;
	wire [10:0] sync0;
	wire [10:0] sync1;
	wire [20-1:0] sweep;

	wire skip0, axis0, valid0;
	wire skip1, axis1, valid1;

	lighthouse_sweep #(
		.WIDTH(WIDTH),
		.CLOCKS_PER_MICROSECOND(MHZ)
	) lh_sweep(
		.clk(clk),
		.reset(reset),
		.raw_pin(raw_pin),
		.sync0(sync0),
		.sync1(sync1),
		.sweep(sweep),
		.sweep_strobe(sweep_strobe)
	);

	lighthouse_sync_decode #(.MHZ(MHZ)) sync0_decode(
		sync0, skip0, ootx[0], axis0, valid0);

	lighthouse_sync_decode #(.MHZ(MHZ)) sync1_decode(
		sync1, skip1, ootx[1], axis1, valid1);


	always @(posedge clk)
	begin
		strobe <= 0;

		if (reset || !valid0 || !valid1) begin
			// nothing; ignore any pulses
		end else
		if (sweep_strobe) begin
			if (skip0 == skip1)
				strobe <= 0; // should never happen.
			else
				strobe <= 1;

			angle <= sweep;

			lighthouse <= skip0;

			axis <=
				!skip0 &&  axis0 ? 0 :
				!skip0 && !axis0 ? 1 :
				!skip1 &&  axis0 ? 2 :
				!skip1 && !axis0 ? 3 : 0 ;
		end
	end

endmodule


module lighthouse_sync_decode(
	input [10:0] sync,
	output skip,
	output data,
	output axis,
	output valid
);
	parameter MHZ = 48; // we should do something with this

	assign valid = (6 <= sync) && (sync <= 13);

	wire [2:0] type = sync - 6;
	assign skip = type[2];
	assign data = type[1];
	assign axis = type[0];
endmodule


module lighthouse_sweep(
	input clk,
	input reset,
	input raw_pin,
	output reg [10:0] sync0,
	output reg [10:0] sync1,
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
	reg got_sync1;

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
			got_sync1 <= 0;
		end else
		if (fall_strobe)
		begin
			// record the time of the falling strobe
			last_fall <= counter;
		end else
		if (rise_strobe)
		begin
			if (len < 15 * CLOCKS_PER_MICROSECOND) begin
				// signal that we have something
				// if we've seen the sync pulses
				if (got_sync1)
					sweep_strobe <= 1;

				// time is from the last rising edge to
				// the midpoint of the sweep pulse
				sweep <= counter - len/2 - last_rise;

				// indicate that we have a sweep
				got_sweep <= 1;
				got_sync1 <= 0;
			end else
			if (got_sweep) begin
				// first non-sweep pulse after a sweep
				sync0 <= len[10+9:9];
				got_sweep <= 0;
				got_sync1 <= 0;
			end else begin
				// second non-sweep pulse
				sync1 <= len[10+9:9];
				got_sync1 <= 1;
			end

			last_rise <= counter;
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
