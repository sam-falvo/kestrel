`default_nettype none
`timescale 1ns / 1ps

//
// Signal Descriptions
// ===================
//
// clk_i	Processor clock.
// reset_i	1 to reset the circuit in the next cycle.
//		0 for normal operation.
//
// Inputs from the decode stage:
//
// inpa_i	ALU input value A.
// inpb_i	ALU input value B.
//
// invB_i	1 to invert the B input.  You can use this to
//		arrange for subtraction by setting cflag_i,
//		invB_en_i, and sum_en_i at once, for example.
//
// cflag_i	Input carry flag value.  Unless you know what
//		you're doing, keep this 0.
//
// lsh_en_i	1 to enable left-shift outputs (a << b).
// rsh_en_i	1 to enable right-shift outputs (a >> b).
//		Note that cflag_i selects between logical (0)
//		and arithmetic (1) right shift.
// ltu_en_i	1 to enable less-than outputs (1 if a < b; 0
// lts_en_i	otherwise).  Note that ltu_en_i is for an
//		unsigned comparison, while lts_en_i is for signed.
// sum_en_i	1 to enable sum outputs (a + b).
// and_en_i	1 to enable AND outputs (a & b).
// xor_en_i	1 to enable XOR outputs (a ^ b).
//		NOTE: To get inclusive OR, you'd enable both
//		and_en_i and xor_en_i, since (A|B) = (A&B) | (A^B).
//
// rd_i		Destination register to write to (0 if none).
//
// we_i		1 for write transaction; 0 for read.  Ignored
//		if no memory operation is requested; see also
//		nomem_i and mem_i.
//
// nomem_i	1 if the ALU result is to be written back to
//		the register file.
//
// mem_i	1 if the ALU result is to be taken as an effective
//		address.
//
// dat_i	For memory writes, this value contains the value
//		to be written out the data bus.
//
// xrs_rwe_i	The size of the value to write.  If nomem_i asserted,
//		this must be XRS_RWE_S64.  Otherwise, this determines,
//		both size and signedness of the memory transfer.
//
// Outputs to the memory stage:
//
// rd_o		Destination register to write to (0 if none).
//
// addr_o	Address to read from or write to in memory.
//		Alternatively, the value to write directly to
//		Rd.  This literally is the ALU output.
//
// we_o		1 for write transaction; 0 for read.  Ignored
//		if no memory operation is requested; see also
//		nomem_o and mem_o.
//
// nomem_o	1 if the value presented to addr_o is intended
//		to be written back to the register file.
//		Mutually exclusive with mem_o.
//
// mem_o	1 if the value presented to addr_o is a proper
//		memory address and a memory transaction is to
//		occur.
//
// dat_o	If mem_o signals the start of a transaction,
//		this signal contains the value to be written
//		out over the data bus.  Ignored otherwise.
//
// xrs_rwe_o	The size of the value to write.  If nomem_i asserted,
//		this must be XRS_RWE_S64.  Otherwise, this determines,
//		both size and signedness of the memory transfer.
//
// Feedback from memory stage:
//
// busy_o	1 if a memory transaction remains in progress;
//		0 if not.
//

module exec(
	input		clk_i,
	input		reset_i,

	input	[63:0]	inpa_i,
	input	[63:0]	inpb_i,
	input		invB_i,
	input		cflag_i,
	input		lsh_en_i,
	input		rsh_en_i,
	input		ltu_en_i,
	input		lts_en_i,
	input		sum_en_i,
	input		and_en_i,
	input		xor_en_i,
	input	[4:0]	rd_i,
	input		we_i,
	input		nomem_i,
	input		mem_i,
	input	[63:0]	dat_i,
	input	[2:0]	xrs_rwe_i,

	input		busy_i,

	output	[4:0]	rd_o,
	output	[63:0]	addr_o,
	output		we_o,
	output		nomem_o,
	output		mem_o,
	output	[63:0]	dat_o,
	output	[2:0]	xrs_rwe_o
);
	reg	[63:0]	inpa_r, inpb_r, dat_r;
	reg		invB_r, cflag_r, we_r, nomem_r, mem_r;
	reg		lsh_en_r, rsh_en_r, ltu_en_r, lts_en_r, sum_en_r;
	reg		and_en_r, xor_en_r;
	reg	[2:0]	xrs_rwe_r;
	reg	[4:0]	rd_r;

	assign	rd_o = rd_r;
	assign	we_o = we_r;
	assign	nomem_o = nomem_r;
	assign	mem_o = mem_r;
	assign	dat_o = dat_r;
	assign	xrs_rwe_o = xrs_rwe_r;

	alu alu(
		.inA_i(inpa_r),
		.inB_i(inpb_r),
		.cflag_i(cflag_r),
		.sum_en_i(sum_en_r),
		.and_en_i(and_en_r),
		.xor_en_i(xor_en_r),
		.invB_en_i(invB_r),
		.lsh_en_i(lsh_en_r),
		.rsh_en_i(rsh_en_r),
		.ltu_en_i(ltu_en_r),
		.lts_en_i(lts_en_r),
		.out_o(addr_o),
		.cflag_o(),
		.vflag_o(),
		.zflag_o()
	);

	always @(posedge clk_i) begin
		inpa_r <= inpa_r;
		inpb_r <= inpb_r;
		dat_r <= dat_r;
		invB_r <= invB_r;
		cflag_r <= cflag_r;
		we_r <= we_r;
		nomem_r <= nomem_r;
		mem_r <= mem_r;
		lsh_en_r <= lsh_en_r;
		rsh_en_r <= rsh_en_r;
		ltu_en_r <= ltu_en_r;
		lts_en_r <= lts_en_r;
		sum_en_r <= sum_en_r;
		and_en_r <= and_en_r;
		xor_en_r <= xor_en_r;
		xrs_rwe_r <= xrs_rwe_r;
		rd_r <= rd_i;

		if (reset_i) begin
			{
				inpa_r, inpb_r, dat_r, invB_r, cflag_r, we_r,
				mem_r, nomem_r, lsh_en_r, rsh_en_r, ltu_en_r,
				lts_en_r, sum_en_r, and_en_r, xor_en_r,
				xrs_rwe_r, rd_r
			} <= 0;
		end
		else if (~busy_i) begin
			inpa_r <= inpa_i;
			inpb_r <= inpb_i;
			dat_r <= dat_i;
			invB_r <= invB_i;
			cflag_r <= cflag_i;
			we_r <= we_i;
			nomem_r <= nomem_i;
			mem_r <= mem_i;
			lsh_en_r <= lsh_en_i;
			rsh_en_r <= rsh_en_i;
			ltu_en_r <= ltu_en_i;
			lts_en_r <= lts_en_i;
			sum_en_r <= sum_en_i;
			and_en_r <= and_en_i;
			xor_en_r <= xor_en_i;
			xrs_rwe_r <= xrs_rwe_i;
			rd_r <= rd_i;
		end
	end
endmodule

