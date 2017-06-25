`default_nettype none
`timescale 1ns / 1ps

`include "asserts.vh"

`include "xrs.vh"


module xrs_tb();
	reg	[11:0]	story_to;
	reg		fault_to;

	reg		clk_i;
	reg	[2:0]	rwe_i;
	reg	[4:0]	ra_i, rb_i, rd_i;
	reg	[63:0]	rdat_i;
	wire	[63:0]	rdata_o, rdatb_o;

	`STANDARD_FAULT
	`DEFASSERT(rdata, 63, o)
	`DEFASSERT(rdatb, 63, o)

	xrs x(
		.clk_i(clk_i),

		.rd_i(rd_i),
		.rdat_i(rdat_i),
		.rwe_i(rwe_i),

		.rdata_o(rdata_o),
		.rdatb_o(rdatb_o),
		.ra_i(ra_i),
		.rb_i(rb_i)
	);

	always begin
		#5 clk_i <= ~clk_i;
	end

	initial begin
		$dumpfile("xrs.vcd");
		$dumpvars;

		{
			story_to, fault_to, clk_i, rwe_i, ra_i, rb_i, rd_i,
			rdat_i
		} <= 0;
		wait(~clk_i); wait(clk_i); #1;

		// Try to store some values in the register file.
		rdat_i <= 64'h1122334455667788;
		rwe_i <= `XRS_RWE_S64;
		rd_i <= 1;
		wait(~clk_i); wait(clk_i); #1;

		rdat_i <= 64'h7766554433221100;
		rd_i <= 2;
		wait(~clk_i); wait(clk_i); #1;

		rwe_i <= `XRS_RWE_NO;

		// Now try to read back the registers we just wrote.
		ra_i <= 1;
		rb_i <= 2;
		wait(~clk_i); wait(clk_i); #1;
		assert_rdata(64'h1122334455667788);
		assert_rdatb(64'h7766554433221100);

		ra_i <= 2;
		rb_i <= 1;
		wait(~clk_i); wait(clk_i); #1;
		assert_rdata(64'h7766554433221100);
		assert_rdatb(64'h1122334455667788);

		ra_i <= 1;
		rb_i <= 0;
		wait(~clk_i); wait(clk_i); #1;
		assert_rdata(64'h1122334455667788);
		assert_rdatb(64'h0);

		ra_i <= 0;
		rb_i <= 2;
		wait(~clk_i); wait(clk_i); #1;
		assert_rdata(64'h0);
		assert_rdatb(64'h7766554433221100);

		// Confirm operation of sign-extension

		rdat_i <= 64'h7766554433221100;
		rwe_i <= `XRS_RWE_S8;
		rd_i <= 1;
		wait(~clk_i); wait(clk_i); #1;

		rwe_i <= `XRS_RWE_S16;
		rd_i <= 2;
		wait(~clk_i); wait(clk_i); #1;

		rwe_i <= `XRS_RWE_S32;
		rd_i <= 3;
		wait(~clk_i); wait(clk_i); #1;

		rwe_i <= `XRS_RWE_S64;
		rd_i <= 4;
		wait(~clk_i); wait(clk_i); #1;

		rwe_i <= `XRS_RWE_NO;

		rdat_i <= 64'h8766554483228180;
		rwe_i <= `XRS_RWE_S8;
		rd_i <= 5;
		wait(~clk_i); wait(clk_i); #1;

		rwe_i <= `XRS_RWE_S16;
		rd_i <= 6;
		wait(~clk_i); wait(clk_i); #1;

		rwe_i <= `XRS_RWE_S32;
		rd_i <= 7;
		wait(~clk_i); wait(clk_i); #1;

		rwe_i <= `XRS_RWE_S64;
		rd_i <= 8;
		wait(~clk_i); wait(clk_i); #1;

		rwe_i <= `XRS_RWE_NO;

		ra_i <= 1;
		wait(~clk_i); wait(clk_i); #1;
		assert_rdata(64'h0000000000000000);

		ra_i <= 2;
		wait(~clk_i); wait(clk_i); #1;
		assert_rdata(64'h0000000000001100);

		ra_i <= 3;
		wait(~clk_i); wait(clk_i); #1;
		assert_rdata(64'h0000000033221100);

		ra_i <= 4;
		wait(~clk_i); wait(clk_i); #1;
		assert_rdata(64'h7766554433221100);

		ra_i <= 5;
		wait(~clk_i); wait(clk_i); #1;
		assert_rdata(64'hFFFFFFFFFFFFFF80);

		ra_i <= 6;
		wait(~clk_i); wait(clk_i); #1;
		assert_rdata(64'hFFFFFFFFFFFF8180);

		ra_i <= 7;
		wait(~clk_i); wait(clk_i); #1;
		assert_rdata(64'hFFFFFFFF83228180);

		ra_i <= 8;
		wait(~clk_i); wait(clk_i); #1;
		assert_rdata(64'h8766554483228180);

		// Confirm operation of zero-extension

		rdat_i <= 64'hFFFFFFFFFFFFFFFF;
		rwe_i <= `XRS_RWE_U8;
		rd_i <= 1;
		wait(~clk_i); wait(clk_i); #1;

		rwe_i <= `XRS_RWE_U16;
		rd_i <= 2;
		wait(~clk_i); wait(clk_i); #1;

		rwe_i <= `XRS_RWE_U32;
		rd_i <= 3;
		wait(~clk_i); wait(clk_i); #1;

		rwe_i <= `XRS_RWE_NO;

		ra_i <= 1;
		wait(~clk_i); wait(clk_i); #1;
		assert_rdata(64'h00000000000000FF);

		ra_i <= 2;
		wait(~clk_i); wait(clk_i); #1;
		assert_rdata(64'h000000000000FFFF);

		ra_i <= 3;
		wait(~clk_i); wait(clk_i); #1;
		assert_rdata(64'h00000000FFFFFFFF);


		#100;
		$stop;
	end
endmodule
