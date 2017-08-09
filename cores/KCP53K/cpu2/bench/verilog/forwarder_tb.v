`default_nettype none
`timescale 1ns / 1ps

`include "asserts.vh"


module forwarder_tb();
	reg	[11:0]	story_to;
	reg		fault_to;

	reg		clk_i;
	wire	[63:0]	qa_o, qb_o;
	wire		hita_o, hitb_o;
	reg	[63:0]	dat_i;
	reg	[4:0]	ra_i, rb_i, rd_i;

	`STANDARD_FAULT
	`DEFASSERT(qa, 63, o)
	`DEFASSERT(qb, 63, o)
	`DEFASSERT0(hita, o)
	`DEFASSERT0(hitb, o)

	forwarder f(
		.ra_i(ra_i),
		.rb_i(rb_i),
		.rd_i(rd_i),
		.dat_i(dat_i),
		.hita_o(hita_o),
		.hitb_o(hitb_o),
		.qa_o(qa_o),
		.qb_o(qb_o)
	);

	always begin
		#5 clk_i <= ~clk_i;
	end

	initial begin
		$dumpfile("forwarder.vcd");
		$dumpvars;

		{
			clk_i, story_to, fault_to, ra_i, rb_i, rd_i, dat_i
		} <= 0;
		wait(~clk_i); wait(clk_i); #1;

		ra_i <= 15;
		rb_i <= 21;
		rd_i <= 19;
		dat_i <= 64'hDEADBEEFFEEDFACE;
		wait(~clk_i); wait(clk_i); #1;
		assert_hita(0);
		assert_hitb(0);
		assert_qa(0);
		assert_qb(0);

		ra_i <= 19;
		rb_i <= 21;
		rd_i <= 19;
		wait(~clk_i); wait(clk_i); #1;
		assert_hita(1);
		assert_hitb(0);
		assert_qa(64'hDEADBEEFFEEDFACE);
		assert_qb(0);

		ra_i <= 15;
		rb_i <= 19;
		rd_i <= 19;
		wait(~clk_i); wait(clk_i); #1;
		assert_hita(0);
		assert_hitb(1);
		assert_qa(0);
		assert_qb(64'hDEADBEEFFEEDFACE);

		ra_i <= 19;
		rb_i <= 19;
		rd_i <= 19;
		wait(~clk_i); wait(clk_i); #1;
		assert_hita(1);
		assert_hitb(1);
		assert_qa(64'hDEADBEEFFEEDFACE);
		assert_qb(64'hDEADBEEFFEEDFACE);

		#100;
		$stop;
	end
endmodule
