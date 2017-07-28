`default_nettype none
`timescale 1ns / 1ps

`include "asserts.vh"
`include "xrs.vh"

module integration_tb();
	reg	[11:0]	story_to;
	reg		fault_to;
	
	reg		clk_i, reset_i, inst_en_i;
	reg	[31:0]	inst_i;
	wire		illegal_o;

	wire	[63:0]	xrs_dec_rs1val, xrs_dec_rs2val;

	wire	[63:0]	dec_ex_inpa, dec_ex_inpb;
	wire		dec_ex_invB, dec_ex_cflag, dec_ex_lsh_en, dec_ex_rsh_en;
	wire		dec_ex_ltu_en, dec_ex_lts_en, dec_ex_sum_en, dec_ex_and_en;
	wire		dec_ex_xor_en, dec_ex_we, dec_ex_nomem, dec_ex_mem;
	wire	[4:0]	dec_ex_rd, dec_ex_rs1, dec_ex_rs2;
	wire	[63:0]	dec_ex_dat;
	wire	[2:0]	dec_ex_xrs_rwe;

	wire	[4:0]	ex_mem_rd;
	wire	[63:0]	ex_mem_addr, ex_mem_dat;
	wire		ex_mem_we;
	wire		ex_mem_nomem;
	wire		ex_mem_mem;
	wire	[2:0]	ex_mem_xrs_rwe;

	wire	[2:0]	mem_xrs_rwe;
	wire	[63:0]	mem_xrs_dat;
	wire	[4:0]	mem_xrs_rd;

	wire	[63:0]	wbmadr_o;
	wire	[15:0]	wbmdat_o;
	wire		wbmwe_o, wbmstb_o;
	wire	[1:0]	wbmsel_o;
	reg		wbmack_i, wbmstall_i;
	reg	[15:0]	wbmdat_i;


	always begin
		#10 clk_i <= ~clk_i;
	end

	decode decode(
		.clk_i(clk_i),
		.reset_i(reset_i),

		.inst_i(inst_i),
		.inst_en_i(inst_en_i),
		.rs1val_i(xrs_dec_rs1val),
		.rs2val_i(xrs_dec_rs2val),

		.inpa_o(dec_ex_inpa),
		.inpb_o(dec_ex_inpb),
		.invB_o(dec_ex_invB),
		.cflag_o(dec_ex_cflag),
		.lsh_en_o(dec_ex_lsh_en),
		.rsh_en_o(dec_ex_rsh_en),
		.ltu_en_o(dec_ex_ltu_en),
		.lts_en_o(dec_ex_lts_en),
		.sum_en_o(dec_ex_sum_en),
		.and_en_o(dec_ex_and_en),
		.xor_en_o(dec_ex_xor_en),
		.rd_o(dec_ex_rd),
		.rs1_o(dec_ex_rs1),
		.rs2_o(dec_ex_rs2),
		.we_o(dec_ex_we),
		.nomem_o(dec_ex_nomem),
		.mem_o(dec_ex_mem),
		.dat_o(dec_ex_dat),
		.xrs_rwe_o(dec_ex_xrs_rwe),
		.illegal_o(illegal_o)
	);

	exec exec(
		.clk_i(clk_i),
		.reset_i(reset_i),

		.inpa_i(dec_ex_inpa),
		.inpb_i(dec_ex_inpb),
		.invB_i(dec_ex_invB),
		.cflag_i(dec_ex_cflag),
		.lsh_en_i(dec_ex_lsh_en),
		.rsh_en_i(dec_ex_rsh_en),
		.ltu_en_i(dec_ex_ltu_en),
		.lts_en_i(dec_ex_lts_en),
		.sum_en_i(dec_ex_sum_en),
		.and_en_i(dec_ex_and_en),
		.xor_en_i(dec_ex_xor_en),
		.rd_i(dec_ex_rd),
		.we_i(dec_ex_we),
		.nomem_i(dec_ex_nomem),
		.mem_i(dec_ex_mem),
		.dat_i(dec_ex_dat),
		.xrs_rwe_i(dec_ex_xrs_rwe),

		.busy_i(1'b0),

		.rd_o(ex_mem_rd),
		.addr_o(ex_mem_addr),
		.we_o(ex_mem_we),
		.nomem_o(ex_mem_nomem),
		.mem_o(ex_mem_mem),
		.dat_o(ex_mem_dat),
		.xrs_rwe_o(ex_mem_xrs_rwe)
	);

	lsu ls(
		.clk_i(clk_i),
		.reset_i(reset_i),

		.addr_i(ex_mem_addr),
		.dat_i(ex_mem_dat),
		.we_i(ex_mem_we),
		.nomem_i(ex_mem_nomem),
		.mem_i(ex_mem_mem),
		.xrs_rwe_i(ex_mem_xrs_rwe),
		.xrs_rd_i(ex_mem_rd),
		.busy_o(),

		.rwe_o(mem_xrs_rwe),
		.dat_o(mem_xrs_dat),
		.rd_o(mem_xrs_rd),

		.wbmadr_o(wbmadr_o),
		.wbmdat_o(wbmdat_o),
		.wbmwe_o(wbmwe_o),
		.wbmstb_o(wbmstb_o),
		.wbmsel_o(wbmsel_o),
		.wbmack_i(wbmack_i),
		.wbmstall_i(wbmstall_i),
		.wbmdat_i(wbmdat_i)
	);

	xrs x(
		.clk_i(clk_i),

		.rd_i(mem_xrs_rd),
		.rdat_i(mem_xrs_dat),
		.rwe_i(mem_xrs_rwe),

		.rdata_o(xrs_dec_rs1val),
		.rdatb_o(xrs_dec_rs2val),
		.ra_i(dec_ex_rs1),
		.rb_i(dec_ex_rs2)
	);

	task zero;
	begin
		{
			reset_i, inst_i, inst_en_i,
			wbmack_i, wbmstall_i, wbmdat_i,
			story_to, fault_to
		} <= 0;
	end
	endtask

	`STANDARD_FAULT

	initial begin
		$dumpfile("integration.vcd");
		$dumpvars;

		zero;
		clk_i <= 0;
		wait(~clk_i); wait(clk_i); #1;

		reset_i <= 1;
		wait(~clk_i); wait(clk_i); #1;
		reset_i <= 0;

		#100;
		$display("@Done.");
		$stop;
	end
endmodule
