`default_nettype none
`timescale 1ns / 1ps

// This module implements the set of 31 64-bit wide registers for the CPU.
//
// Note that reading the register bank is _synchronous_, not asynchronous.
// This means you must present the desired register address prior to a clock
// edge, and the contents of the indicated register will appear after that
// edge.
//
// This module assumes you're targeting the iCE40HX series of FPGAs.

module xrs(
	input		clk_i,
	input	[4:0]	rd_i,
	input	[63:0]	rdat_i,
	input		rwe_i,

	output	[63:0]	rdata_o,
	output	[63:0]	rdatb_o,
	input	[4:0]	ra_i,
	input	[4:0]	rb_i
);
	wire	[63:0]	data_o, datb_o;
	reg	[4:0]	ra_r, rb_r;

	assign rdata_o = (|ra_r) ? data_o : 0;
	assign rdatb_o = (|rb_r) ? datb_o : 0;

	always @(posedge clk_i) begin
		ra_r <= ra_i;
		rb_r <= rb_i;
	end

	ram64b port0(
		.wdata(rdat_i),
		.wen(rwe_i),
		.waddr(rd_i),
		.wclk(clk_i),
		.rdata(data_o),
		.raddr(ra_i),
		.rclk(clk_i)
	);

	ram64b port1(
		.wdata(rdat_i),
		.wen(rwe_i),
		.waddr(rd_i),
		.wclk(clk_i),
		.rdata(datb_o),
		.raddr(rb_i),
		.rclk(clk_i)
	);
endmodule
