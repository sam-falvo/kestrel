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
//
// Signal Descriptions
// ===================
//
// clk_i	Processor clock (also Wishbone's clock).
//
// rd_i		Destination register address (0-31).
// rdat_i	64-bit data word to write to the destination register.
//		This value may be sign or zero extended as per the write-
//		enables below.
//
// rwe_i 	1 allows the register bank to store the specified sign-
//        	or zero-extended value on rdat_i into the register addr-
//		essed by rd_i.
//
//		Note: if none of the rwe_i bits are set, then no value is
//		stored into the register set.  This is indistinguishable from
//		forcing rd_i equal to 0.
//
// ra_i		Source register addresses (0-31).
// rb_i
//
// rdata_o	64-bit value currently stored at the specified register
// rdatb_o	address.  Note that register 0 is hardwired to the value 0.
//

`include "xrs.vh"

module xrs(
	input		clk_i,
	input	[4:0]	rd_i,
	input	[63:0]	rdat_i,
	input	[2:0]	rwe_i,

	output	[63:0]	rdata_o,
	output	[63:0]	rdatb_o,
	input	[4:0]	ra_i,
	input	[4:0]	rb_i
);
	wire	[63:0]	rx_dat  = ((rwe_i == `XRS_RWE_U8) ? {56'd0, rdat_i[7:0]} : 0)
				| ((rwe_i == `XRS_RWE_U16) ? {48'd0, rdat_i[15:0]} : 0)
				| ((rwe_i == `XRS_RWE_U32) ? {32'd0, rdat_i[31:0]} : 0)
				| ((rwe_i == `XRS_RWE_S8) ? {{56{rdat_i[7]}}, rdat_i[7:0]} : 0)
				| ((rwe_i == `XRS_RWE_S16) ? {{48{rdat_i[15]}}, rdat_i[15:0]} : 0)
				| ((rwe_i == `XRS_RWE_S32) ? {{32{rdat_i[31]}}, rdat_i[31:0]} : 0)
				| ((rwe_i == `XRS_RWE_S64) ? rdat_i : 0)
				;
	wire	wen = |rwe_i;

	wire	[63:0]	data_o, datb_o;
	reg	[4:0]	ra_r, rb_r;

	assign rdata_o = (|ra_r) ? data_o : 0;
	assign rdatb_o = (|rb_r) ? datb_o : 0;

	always @(posedge clk_i) begin
		ra_r <= ra_i;
		rb_r <= rb_i;
	end

	ram64b port0(
		.wdata(rx_dat),
		.wen(wen),
		.waddr(rd_i),
		.wclk(clk_i),
		.rdata(data_o),
		.raddr(ra_i),
		.rclk(clk_i)
	);

	ram64b port1(
		.wdata(rx_dat),
		.wen(wen),
		.waddr(rd_i),
		.wclk(clk_i),
		.rdata(datb_o),
		.raddr(rb_i),
		.rclk(clk_i)
	);
endmodule
