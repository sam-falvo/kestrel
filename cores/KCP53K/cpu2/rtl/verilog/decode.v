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
// Inputs from the instruction fetch stage:
//
// inst_i	Instruction.  If none, use NOP (ADDI X0, X0, 0).
// inst_en_i	1 if a new instruction is to be registered.
//		0 to retain the previously registered instruction.
//		(Put another way, inst_i is valid if 1.)
//
// I/Os to/from the register writeback stage:
//
// rs1val_i	Source register value 1.
// rs2val_i	Source register value 2.
//
// rs1_o	Source register address.  Data must appear on
//		rs1val_i before next cycle.
// rs2_o	As with rs1_o.
//
// Outputs to the decode stage:
//
// inpa_o	ALU input value A.  Corresponds to RS1.
// inpb_o	ALU input value B.  Corresponds to RS2 or immediate.
// invB_o	1 to invert the B input.
// cflag_o	ALU carry input.  Used with invB_o to effect subtractions.
// lsh_en_o	Arithmetic/logic operations.
// rsh_en_o
// ltu_en_o
// lts_en_o
// sum_en_o
// and_en_o
// xor_en_o
// rd_o		The destination register to write to (0 if none).
// we_o		1 if memory store operation; 0 otherwise.
// nomem_o	1 if ALU-to-register write.
// mem_o	1 if memory load or store operation; 0 otherwise.
// dat_o	Value to store in memory writes.  Corresponds to RS2.
// xrs_rwe_o	The size of the value to write.
//
// illegal_o	1 if the last instruction received is illegal.
//		0 if it's a valid instruction.
//

// ADDI X0, X0, 0
`define INST_NOP	(32'b000000000000_00000_000_00000_0010011)

module decode(
	input		clk_i,
	input		reset_i,

	input	[31:0]	inst_i,
	input		inst_en_i,

	input	[63:0]	rs1val_i,
	input	[63:0]	rs2val_i,

	output	[63:0]	inpa_o,
	output	[63:0]	inpb_o,
	output		invB_o,
	output		cflag_o,
	output		lsh_en_o,
	output		rsh_en_o,
	output		ltu_en_o,
	output		lts_en_o,
	output		sum_en_o,
	output		and_en_o,
	output		xor_en_o,
	output	[4:0]	rd_o,
	output	[4:0]	rs1_o,
	output	[4:0]	rs2_o,
	output		we_o,
	output		nomem_o,
	output		mem_o,
	output	[63:0]	dat_o,
	output	[2:0]	xrs_rwe_o,

	output		illegal_o
);
	reg	[31:0]	inst_r;
	reg		illegal_o;
	reg	[63:0]	inpa_o;
	reg	[63:0]	inpb_o;
	reg	[63:0]	dat_o;
	reg		invB_o;
	reg		cflag_o;
	reg		lsh_en_o;
	reg		rsh_en_o;
	reg		ltu_en_o;
	reg		lts_en_o;
	reg		sum_en_o;
	reg		and_en_o;
	reg		xor_en_o;
	reg		we_o;
	reg		nomem_o;
	reg		mem_o;
	reg	[2:0]	xrs_rwe_o;

	assign	rs2_o = inst_r[24:20];
	assign	rs1_o = inst_r[19:15];
	assign	rd_o = inst_r[11:7];

	wire	[63:0]	imm12 = {{52{inst_r[31]}}, inst_r[31:20]};

	always @(*) begin
		illegal_o <= 1;
		inpa_o <= 0;
		inpb_o <= 0;
		dat_o <= 0;
		invB_o <= 0;
		cflag_o <= 0;
		{lsh_en_o,
		 rsh_en_o,
		 ltu_en_o,
		 lts_en_o,
		 sum_en_o,
		 and_en_o,
		 xor_en_o
		} <= 0;
		we_o <= 0;
		nomem_o <= 1;
		mem_o <= 0;
		xrs_rwe_o <= `XRS_RWE_S64;

		if (inst_r[1:0] == 2'b11) begin
			// OP-IMM
			if((inst_r[6:5] == 2'b00) &&
			   (inst_r[4:2] == 3'b100)) begin
				illegal_o <= 0;
				inpa_o <= rs1val_i;
				inpb_o <= imm12;
				case (inst_r[14:12])
				3'b000: sum_en_o <= 1;
				3'b001: lsh_en_o <= 1;
				3'b010: lts_en_o <= 1;
				3'b011: ltu_en_o <= 1;
				3'b100: xor_en_o <= 1;
				3'b101: {cflag_o, rsh_en_o} <= {inst_r[30], 1'b1};
				3'b110: {and_en_o, xor_en_o} <= 2'b11;
				3'b111: and_en_o <= 1;
				endcase
			end
		end
	end

	always @(posedge clk_i) begin
		inst_r <= inst_r;

		if (reset_i) begin
			inst_r <= `INST_NOP;
		end
		else begin
			if(inst_en_i) begin
				inst_r <= inst_i;
			end
		end
	end
endmodule

