`default_nettype none
`timescale 1ns / 1ps

`include "asserts.vh"
`include "xrs.vh"

module exec_tb();
	reg	[11:0]	story_to;
	reg		fault_to;

	reg		clk_i, reset_i;
	reg	[63:0]	inpa_i, inpb_i, dat_i;
	reg		invB_i, cflag_i, lsh_en_i, rsh_en_i;
	reg		ltu_en_i, lts_en_i, sum_en_i, and_en_i;
	reg		xor_en_i;
	reg	[4:0]	rd_i;
	reg		we_i, nomem_i, mem_i;
	reg	[2:0]	xrs_rwe_i;
	reg		busy_i;

	wire	[4:0]	rd_o;
	wire	[63:0]	addr_o, dat_o;
	wire		we_o, nomem_o, mem_o;
	wire	[2:0]	xrs_rwe_o;

	always begin
		#10 clk_i <= ~clk_i;
	end

	exec exec(
		.clk_i(clk_i),
		.reset_i(reset_i),

		.inpa_i(inpa_i),
		.inpb_i(inpb_i),
		.invB_i(invB_i),
		.cflag_i(cflag_i),
		.lsh_en_i(lsh_en_i),
		.rsh_en_i(rsh_en_i),
		.ltu_en_i(ltu_en_i),
		.lts_en_i(lts_en_i),
		.sum_en_i(sum_en_i),
		.and_en_i(and_en_i),
		.xor_en_i(xor_en_i),
		.rd_i(rd_i),
		.we_i(we_i),
		.nomem_i(nomem_i),
		.mem_i(mem_i),
		.dat_i(dat_i),
		.xrs_rwe_i(xrs_rwe_i),

		.busy_i(busy_i),

		.rd_o(rd_o),
		.addr_o(addr_o),
		.we_o(we_o),
		.nomem_o(nomem_o),
		.mem_o(mem_o),
		.dat_o(dat_o),
		.xrs_rwe_o(xrs_rwe_o)
	);

	task zero;
	begin
		{
			reset_i, inpa_i, inpb_i, dat_i,
			invB_i, cflag_i, lsh_en_i, rsh_en_i,
			ltu_en_i, lts_en_i, sum_en_i,
			and_en_i, xor_en_i, rd_i, we_i,
			nomem_i, mem_i, xrs_rwe_i, busy_i,
			story_to, fault_to
		} <= 0;
	end
	endtask

	`STANDARD_FAULT
	`DEFASSERT(rd, 4, o)
	`DEFASSERT(addr, 63, o)
	`DEFASSERT0(we, o)
	`DEFASSERT0(nomem, o)
	`DEFASSERT0(mem, o)
	`DEFASSERT(dat, 63, o)
	`DEFASSERT(xrs_rwe, 2, o)

	initial begin
		$dumpfile("exec.vcd");
		$dumpvars;

		zero;
		clk_i <= 0;
		wait(~clk_i); wait(clk_i); #1;

		reset_i <= 1;
		wait(~clk_i); wait(clk_i); #1;
		reset_i <= 0;

		story_to <= 12'h010;
		inpa_i <= 64'hE00000;
		inpb_i <= 64'hFFFFFFFF_FFFF_F800;
		cflag_i <= 0;
		{lsh_en_i, rsh_en_i, ltu_en_i, lts_en_i} <= 0;
		{sum_en_i, and_en_i, xor_en_i} <= 3'b100;
		{nomem_i, mem_i} <= 2'b01;
		xrs_rwe_i <= `XRS_RWE_S16;
		rd_i <= 23;
		busy_i <= 0;
		wait(~clk_i); wait(clk_i); #1;

		zero;

		assert_rd(23);
		assert_addr(64'hDFF800);
		assert_we(0);
		assert_nomem(0);
		assert_mem(1);
		assert_dat(0);
		assert_xrs_rwe(`XRS_RWE_S16);

		wait(~clk_i); wait(clk_i); #1;
		story_to <= 12'h020;

		inpa_i <= 64'hE00000;
		inpb_i <= 64'h7FF;
		dat_i <= 64'h0000_0000_0000_DEAD;
		cflag_i <= 0;
		{lsh_en_i, rsh_en_i, ltu_en_i, lts_en_i} <= 0;
		{sum_en_i, and_en_i, xor_en_i} <= 3'b100;
		{nomem_i, mem_i} <= 2'b01;
		xrs_rwe_i <= `XRS_RWE_S16;
		rd_i <= 23;
		busy_i <= 0;
		we_i <= 1;

		wait(~clk_i); wait(clk_i); #1;

		assert_rd(23);
		assert_addr(64'hE007FF);
		assert_we(1);
		assert_nomem(0);
		assert_mem(1);
		assert_dat(64'hDEAD);
		assert_xrs_rwe(`XRS_RWE_S16);

		inpa_i <= 64'h400000;
		inpb_i <= 64'hFFFF_FFFF_FFFF_F800;
		dat_i <= 64'h0000_0000_0000_FACE;
		cflag_i <= 0;
		{lsh_en_i, rsh_en_i, ltu_en_i, lts_en_i} <= 0;
		{sum_en_i, and_en_i, xor_en_i} <= 3'b100;
		{nomem_i, mem_i} <= 2'b01;
		xrs_rwe_i <= `XRS_RWE_S8;
		rd_i <= 19;
		busy_i <= 0;
		we_i <= 0;

		wait(~clk_i); wait(clk_i); #1;

		assert_rd(19);
		assert_addr(64'h3FF800);
		assert_we(0);
		assert_nomem(0);
		assert_mem(1);
		assert_xrs_rwe(`XRS_RWE_S8);

		zero;

		#100;
		$display("@Done.");
		$stop;
	end
endmodule

