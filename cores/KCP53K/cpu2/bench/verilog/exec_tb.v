`default_nettype none
`timescale 1ns / 1ps

module exec_tb();
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

	initial begin
		$dumpfile("exec.vcd");
		$dumpvars;

		{
			clk_i, reset_i, inpa_i, inpb_i, dat_i,
			invB_i, cflag_i, lsh_en_i, rsh_en_i,
			ltu_en_i, lts_en_i, sum_en_i,
			and_en_i, xor_en_i, rd_i, we_i,
			nomem_i, mem_i, xrs_rwe_i, busy_i
		} <= 0;

		#100;
		$display("@Done.");
		$stop;
	end
endmodule

