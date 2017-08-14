`default_nettype none
`timescale 1ns / 1ps

`include "asserts.vh"
`include "xrs.vh"

module decode_tb();
	reg	[11:0]	story_to;
	reg		fault_to;

	reg		clk_i, reset_i, inst_en_i;
	reg	[31:0]	inst_i;
	reg	[63:0]	rs1val_i, rs2val_i, ex_q_i, mem_q_i;
	reg	[4:0]	ex_rd_i, mem_rd_i;

	wire	[63:0]	inpa_o, inpb_o;
	wire		invB_o, cflag_o, lsh_en_o, rsh_en_o;
	wire		ltu_en_o, lts_en_o, sum_en_o;
	wire		and_en_o, xor_en_o;
	wire	[4:0]	rd_o, rs1_o, rs2_o;
	wire		we_o, nomem_o, mem_o;
	wire	[63:0]	dat_o;
	wire	[2:0]	xrs_rwe_o;
	wire		illegal_o;

	always begin
		#10 clk_i <= ~clk_i;
	end

	decode decode(
		.clk_i(clk_i),
		.reset_i(reset_i),

		.inst_i(inst_i),
		.inst_en_i(inst_en_i),
		.rs1val_i(rs1val_i),
		.rs2val_i(rs2val_i),

		.ex_rd_i(ex_rd_i),
		.mem_rd_i(mem_rd_i),
		.ex_q_i(ex_q_i),
		.mem_q_i(mem_q_i),

		.inpa_o(inpa_o),
		.inpb_o(inpb_o),
		.invB_o(invB_o),
		.cflag_o(cflag_o),
		.lsh_en_o(lsh_en_o),
		.rsh_en_o(rsh_en_o),
		.ltu_en_o(ltu_en_o),
		.lts_en_o(lts_en_o),
		.sum_en_o(sum_en_o),
		.and_en_o(and_en_o),
		.xor_en_o(xor_en_o),
		.rd_o(rd_o),
		.rs1_o(rs1_o),
		.rs2_o(rs2_o),
		.we_o(we_o),
		.nomem_o(nomem_o),
		.mem_o(mem_o),
		.dat_o(dat_o),
		.xrs_rwe_o(xrs_rwe_o),
		.illegal_o(illegal_o)
	);

	task zero;
	begin
		{
			ex_rd_i, mem_rd_i, ex_q_i, mem_q_i,
			reset_i, inst_i, rs1val_i, rs2val_i, inst_en_i,
			story_to, fault_to
		} <= 0;
	end
	endtask

	`STANDARD_FAULT
	`DEFASSERT(inpa, 63, o)
	`DEFASSERT(inpb, 63, o)
	`DEFASSERT0(invB, o)
	`DEFASSERT0(cflag, o)
	`DEFASSERT0(lsh_en, o)
	`DEFASSERT0(rsh_en, o)
	`DEFASSERT0(ltu_en, o)
	`DEFASSERT0(lts_en, o)
	`DEFASSERT0(sum_en, o)
	`DEFASSERT0(and_en, o)
	`DEFASSERT0(xor_en, o)
	`DEFASSERT(rd, 4, o)
	`DEFASSERT(rs1, 4, o)
	`DEFASSERT(rs2, 4, o)
	`DEFASSERT0(we, o)
	`DEFASSERT0(nomem, o)
	`DEFASSERT0(mem, o)
	`DEFASSERT(dat, 63, o)
	`DEFASSERT(xrs_rwe, 2, o)
	`DEFASSERT0(illegal, o)

	initial begin
		$dumpfile("decode.vcd");
		$dumpvars;

		zero;
		ex_q_i <= 64'hFACE0BADC0FFEE00;
		mem_q_i <= 64'hFEEDFACE0BADC0DE;
		clk_i <= 0;
		wait(~clk_i); wait(clk_i); #1;

		reset_i <= 1;
		wait(~clk_i); wait(clk_i); #1;
		reset_i <= 0;

		assert_inpa(0);
		assert_inpb(0);
		assert_invB(0);
		assert_cflag(0);
		assert_lsh_en(0);
		assert_rsh_en(0);
		assert_ltu_en(0);
		assert_lts_en(0);
		assert_sum_en(1);
		assert_and_en(0);
		assert_xor_en(0);
		assert_rd(0);
		assert_rs1(0);
//		assert_rs2(0);
		assert_we(0);
		assert_nomem(1);
		assert_mem(0);
		assert_dat(0);
		assert_xrs_rwe(`XRS_RWE_S64);
		assert_illegal(0);

		// ADDI X1, X0, $800
		// SLLI X1, X1, 52

		story_to <= 12'h010;
		inst_en_i <= 1;
		inst_i <= 32'b100000000000_00000_000_00001_0010011;

		wait(~clk_i); wait(clk_i); #1;

		assert_inpa(0);
		assert_inpb(64'hFFFF_FFFF_FFFF_F800);
		assert_invB(0);
		assert_cflag(0);
		assert_lsh_en(0);
		assert_rsh_en(0);
		assert_ltu_en(0);
		assert_lts_en(0);
		assert_sum_en(1);
		assert_and_en(0);
		assert_xor_en(0);
		assert_rd(1);
		assert_rs1(0);
//		assert_rs2(0);
		assert_we(0);
		assert_nomem(1);
		assert_mem(0);
		assert_dat(0);
		assert_xrs_rwe(`XRS_RWE_S64);
		assert_illegal(0);

		story_to <= 12'h018;
		inst_i <= 32'b000000110100_00001_001_00001_0010011;

		wait(~clk_i); wait(clk_i); #1;

		#10 rs1val_i <= 64'hFFFF_FFFF_FFFF_F800;
		rs2val_i <= 64'hDEAD_BEEF_FEED_FACE;

		#1;

		assert_inpa(64'hFFFF_FFFF_FFFF_F800);
		assert_inpb(52);
		assert_invB(0);
		assert_cflag(0);
		assert_lsh_en(1);
		assert_rsh_en(0);
		assert_ltu_en(0);
		assert_lts_en(0);
		assert_sum_en(0);
		assert_and_en(0);
		assert_xor_en(0);
		assert_rd(1);
		assert_rs1(1);
//		assert_rs2(0);
		assert_we(0);
		assert_nomem(1);
		assert_mem(0);
		assert_dat(0);
		assert_xrs_rwe(`XRS_RWE_S64);
		assert_illegal(0);

		// SB X1, 1(X2)		0000000_00001_00010_000_00001_0100011
		// SH X2, 2(X3)		0000000_00010_00011_001_00010_0100011
		// SW X3, 3(X4)		0000000_00011_00100_010_00011_0100011
		// SD X4, 4(X5)		0000000_00100_00101_011_00100_0100011 

		story_to <= 12'h020;
		inst_en_i <= 1;
		inst_i <= 32'b0000000_00001_00010_000_00001_0100011;
		wait(~clk_i); wait(clk_i); #1;

		#10 rs1val_i <= 64'd1;
		rs2val_i <= 64'hDEAD_BEEF_FEED_FACE;
		#1;
		assert_inpa(64'd1);
		assert_inpb(1);
		assert_invB(0);
		assert_cflag(0);
		assert_lsh_en(0);
		assert_rsh_en(0);
		assert_ltu_en(0);
		assert_lts_en(0);
		assert_sum_en(1);
		assert_and_en(0);
		assert_xor_en(0);
//		assert_rd(1);
		assert_rs1(2);
		assert_rs2(1);
		assert_we(1);
		assert_nomem(0);
		assert_mem(1);
		assert_dat(64'hDEAD_BEEF_FEED_FACE);
		assert_xrs_rwe(`XRS_RWE_S8);
		assert_illegal(0);

		story_to <= 12'h024;
		inst_i <= 32'b0000000_00010_00011_001_00010_0100011;

		wait(~clk_i); wait(clk_i); #1;

		#10 rs1val_i <= 64'd2;
		rs2val_i <= 64'hDEAD_BEEF_FEED_FACE;
		#1;
		assert_inpa(64'd2);
		assert_inpb(2);
		assert_invB(0);
		assert_cflag(0);
		assert_lsh_en(0);
		assert_rsh_en(0);
		assert_ltu_en(0);
		assert_lts_en(0);
		assert_sum_en(1);
		assert_and_en(0);
		assert_xor_en(0);
//		assert_rd(1);
		assert_rs1(3);
		assert_rs2(2);
		assert_we(1);
		assert_nomem(0);
		assert_mem(1);
		assert_dat(64'hDEAD_BEEF_FEED_FACE);
		assert_xrs_rwe(`XRS_RWE_S16);
		assert_illegal(0);

		story_to <= 12'h028;
		inst_i <= 32'b0000000_00011_00100_010_00011_0100011;

		wait(~clk_i); wait(clk_i); #1;

		#10 rs1val_i <= 64'd1;
		rs2val_i <= 64'hDEAD_BEEF_FEED_FACE;
		#1;
		assert_inpa(64'd1);
		assert_inpb(3);
		assert_invB(0);
		assert_cflag(0);
		assert_lsh_en(0);
		assert_rsh_en(0);
		assert_ltu_en(0);
		assert_lts_en(0);
		assert_sum_en(1);
		assert_and_en(0);
		assert_xor_en(0);
//		assert_rd(1);
		assert_rs1(4);
		assert_rs2(3);
		assert_we(1);
		assert_nomem(0);
		assert_mem(1);
		assert_dat(64'hDEAD_BEEF_FEED_FACE);
		assert_xrs_rwe(`XRS_RWE_S32);
		assert_illegal(0);

		story_to <= 12'h02C;
		inst_i <= 32'b0000000_00100_00101_011_00100_0100011;

		wait(~clk_i); wait(clk_i); #1;

		#10 rs1val_i <= 64'd4;
		rs2val_i <= 64'hDEAD_BEEF_FEED_FACE;
		#1;
		assert_inpa(64'd4);
		assert_inpb(4);
		assert_invB(0);
		assert_cflag(0);
		assert_lsh_en(0);
		assert_rsh_en(0);
		assert_ltu_en(0);
		assert_lts_en(0);
		assert_sum_en(1);
		assert_and_en(0);
		assert_xor_en(0);
//		assert_rd(1);
		assert_rs1(5);
		assert_rs2(4);
		assert_we(1);
		assert_nomem(0);
		assert_mem(1);
		assert_dat(64'hDEAD_BEEF_FEED_FACE);
		assert_xrs_rwe(`XRS_RWE_S64);
		assert_illegal(0);

		// ADDI X1, X2, 3
		// X2 feedback from EX

		story_to <= 12'h030;
		inst_en_i <= 1;
		inst_i <= 32'b000000000011_00010_000_00001_0010011;
		ex_rd_i <= 2;

		wait(~clk_i); wait(clk_i); #1;
		wait(~clk_i); wait(clk_i); #1;
		wait(~clk_i); wait(clk_i); #1;
		wait(~clk_i); wait(clk_i); #1;

		assert_inpa(64'hFACE_0BAD_C0FF_EE00);
		assert_inpb(64'h0000_0000_0000_0003);
		assert_invB(0);
		assert_cflag(0);
		assert_lsh_en(0);
		assert_rsh_en(0);
		assert_ltu_en(0);
		assert_lts_en(0);
		assert_sum_en(1);
		assert_and_en(0);
		assert_xor_en(0);
		assert_rd(1);
		assert_rs1(2);
//		assert_rs2(0);
		assert_we(0);
		assert_nomem(1);
		assert_mem(0);
		assert_dat(0);
		assert_xrs_rwe(`XRS_RWE_S64);
		assert_illegal(0);

		// SB X1, 1(X2)		0000000_00001_00010_000_00001_0100011

		story_to <= 12'h038;
		inst_en_i <= 1;
		inst_i <= 32'b0000000_00001_00010_000_00001_0100011;
		ex_rd_i <= 0;
		mem_rd_i <= 1;

		wait(~clk_i); wait(clk_i); #1;

		#10 rs1val_i <= 64'd1;
		rs2val_i <= 64'hDEAD_BEEF_FEED_FACE;
		#1;
		assert_inpa(64'd1);
		assert_inpb(1);
		assert_invB(0);
		assert_cflag(0);
		assert_lsh_en(0);
		assert_rsh_en(0);
		assert_ltu_en(0);
		assert_lts_en(0);
		assert_sum_en(1);
		assert_and_en(0);
		assert_xor_en(0);
//		assert_rd(1);
		assert_rs1(2);
		assert_rs2(1);
		assert_we(1);
		assert_nomem(0);
		assert_mem(1);
		assert_dat(64'hFEEDFACE0BADC0DE);
		assert_xrs_rwe(`XRS_RWE_S8);
		assert_illegal(0);

		#100;
		$display("@Done.");
		$stop;
	end
endmodule

