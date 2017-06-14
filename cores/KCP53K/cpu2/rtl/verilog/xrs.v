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
// rsx8_i	1 allows the register bank to store the specified sign-
// rsx16_i	extended value on rdat_i into the register addressed by
// rsx32_i	rd_i.
// rsx64_i
//
// rzx8_i	1 allows the register bank to store the specified ZERO-
// rzx16_i	extended value on rdat_i into the register addressed by
// rzx32_i	rd_i.
//
//		Note: if none of the rsxN_i bits are set, and none of the
//		rzxN_i bits are set, then no value is stored into the
//		register set.  This is indistinguishable from forcing rd_i
//		equal to 0.
//
// ra_i		Source register addresses (0-31).
// rb_i
//
// rdata_o	64-bit value currently stored at the specified register
// rdatb_o	address.  Note that register 0 is hardwired to the value 0.
//

module xrs(
	input		clk_i,
	input	[4:0]	rd_i,
	input	[63:0]	rdat_i,
	input		rzx8_i,
	input		rzx16_i,
	input		rzx32_i,
	input		rsx8_i,
	input		rsx16_i,
	input		rsx32_i,
	input		rsx64_i,

	output	[63:0]	rdata_o,
	output	[63:0]	rdatb_o,
	input	[4:0]	ra_i,
	input	[4:0]	rb_i
);
	wire	[63:0]	rx_dat  = (rzx8_i ? {56'd0, rdat_i[7:0]} : 0)
				| (rzx16_i ? {48'd0, rdat_i[15:0]} : 0)
				| (rzx32_i ? {32'd0, rdat_i[31:0]} : 0)
				| (rsx8_i ? {{56{rdat_i[7]}}, rdat_i[7:0]} : 0)
				| (rsx16_i ? {{48{rdat_i[15]}}, rdat_i[15:0]} : 0)
				| (rsx32_i ? {{32{rdat_i[31]}}, rdat_i[31:0]} : 0)
				| (rsx64_i ? rdat_i : 0)
				;
	wire	rwe_i = |{rzx8_i, rzx16_i, rzx32_i, rsx8_i, rsx16_i, rsx32_i, rsx64_i};

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
		.wen(rwe_i),
		.waddr(rd_i),
		.wclk(clk_i),
		.rdata(data_o),
		.raddr(ra_i),
		.rclk(clk_i)
	);

	ram64b port1(
		.wdata(rx_dat),
		.wen(rwe_i),
		.waddr(rd_i),
		.wclk(clk_i),
		.rdata(datb_o),
		.raddr(rb_i),
		.rclk(clk_i)
	);
endmodule
