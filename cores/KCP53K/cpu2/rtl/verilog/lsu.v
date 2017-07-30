`default_nettype none
`timescale 1ns / 1ps

`include "xrs.vh"

//
// Signal Descriptions
// ===================
//
// clk_i	Processor clock (also Wishbone's clock).
// reset_i	1 to reset the circuit in the next cycle.
//		0 for normal operation.
//
// Inputs from execute stage:
//
// xrs_rd_i	Destination register to write to (0 if none).
//
// addr_i	Address to read from or write to in memory.
//		Typically hardwired to the output of the ALU.
//		This is a full-width integer for ease of testing.
//
// we_i		1 for write transaction; 0 for read.  Ignored
//		if no memory operation is requested; see
//		mem_i below.
//
// nomem_i	1 if the value presented to addr_i is intended
//		to be written back to the register file.
//		Mutually exclusive with mem_i.  The xrs_rwe_i
//		signal determines transfer size and zero/sign-
//		extension.
//
// mem_i	1 if the value presented to addr_i is a proper
//		memory address, and a memory transaction is to
//		occur.  The xrs_rwe_i signal determines transfer
//		size and zero/sign-extension.
//
//		At least one of nomem_i or mem_i should be asserted every idle
//		clock cycle.  If none are asserted, the register write-back
//		stage of the pipeline will receive a bubble in the next cycle.
//
// xrs_rwe_i	One of the following values, indicating both the
//		size of, and the signedness of, the register writeback.
//
//		XRS_RWE_NO	No register writeback. [1]
//		XRS_RWE_S8	Signed, 8-bit transfer.
//		XRS_RWE_S16	Signed, 16-bit transfer.
//		XRS_RWE_S32	Signed, 32-bit transfer.
//		XRS_RWE_S64	(Un)Signed, 64-bit transfer.
//		XRS_RWE_U8	Unsigned, 8-bit transfer.
//		XRS_RWE_U16	Unsigned, 16-bit transfer.
//		XRS_RWE_U32	Unsigned, 32-bit transfer.
//
//		Note 1: XRS_RWE_NO will cause additional undefined behavior
//		when used with a memory access cycle.
//
// dat_i	If mem_i signals the start of a Wishbone transaction, this
//		signal contains the value to be written out over wbmdat_o.
//		Ignored otherwise.
//
// Outputs to Register Write-Back Stage:
//
// rwe_o	Pulsed for a single cycle when dat_o holds valid data.
//		Responsibility for zero- or sign-extension lies with
//		the next stage.  See xrs_rwe_i signal above for values.
//
// dat_o	In the absence of a Wishbone transaction, this reflects
//		the addr_i input.  For all Wishbone transactions, this
//		signal holds the value read off of the Wishbone interconnect.
//		dat_o is valid if, and only if, rwe_o is asserted.
//
// rd_o		Destination register to write to.
//
// Outputs to Random Control Logic:
//
// busy_o	Mirrors wbmcyc_o; indicates whether or not a bus transaction
//		is in progress.  This signal can be used to stall the
//		integer pipeline until the transfer has been completed.
//
// Wishbone Master Signals:
//
// wbmcyc_o	See Wishbone B.4 Pipelined Mode specifications.
// wbmadr_o
// etc.
//

module lsu(
	input		clk_i,
	input		reset_i,
	input	[63:0]	addr_i,
	input		we_i,
	input		nomem_i,
	input		mem_i,
	input	[2:0]	xrs_rwe_i,
	input	[63:0]	dat_i,
	input	[4:0]	xrs_rd_i,

	output		busy_o,

	output	[2:0]	rwe_o,
	output	[63:0]	dat_o,
	output	[4:0]	rd_o,

	output	[63:0]	wbmadr_o,
	output	[15:0]	wbmdat_o,
	output		wbmwe_o,
	output		wbmstb_o,
	output		wbmcyc_o,
	output	[1:0]	wbmsel_o,
	input		wbmstall_i,
	input		wbmack_i,
	input	[15:0]	wbmdat_i
);
	reg	[63:0]	dat_o;
	reg	[2:0]	rwe_o, xrs_rwe_r;
	reg		we_r;
	reg	[1:0]	sel_r;
	reg		byte_r, hword_r, word_r, dword_r, unsigned_r;
	reg		rd_o;
	reg	[63:0]	dat_r;

	// State machine for Wishbone B.4 bus.
	// I truly hate having to use so many MUXes and other
	// combinatorials.  But, it's the only way I can keep
	// the number of clock cycles consumed under control.
	// This will slow the maximum speed of the pipeline,
	// however.
	//
	// mt3..mt0 determines which cycle of the transfer the
	// master is participating on; st3..st0 serve the same
	// role for the slave.
	//
	// At the start of a cycle, mtX and stX are both set
	// (0 <= X <= 3, depending upon the size of the transfer).
	// Note that bytes are treated as special cases of half-
	// words.
	//
	// send_XXX are convenience signals indicating which
	// byte lanes are valid on the Wishbone bus.  These are used
	// to disambiguate byte transfers from real half-word trans-
	// fers, as well as to perform byte-steering logic.

	reg		mt0, mt1, mt2, mt3;	// Master timeslots
	reg		st0, st1, st2, st3;	// Slave timeslots

	wire		send_low_byte = sel_r == 2'b01;
	wire		send_high_byte = sel_r == 2'b10;
	wire		send_hword = sel_r == 2'b11;

	wire		byte = (xrs_rwe_i == `XRS_RWE_S8) || (xrs_rwe_i == `XRS_RWE_U8);
	wire		hword = (xrs_rwe_i == `XRS_RWE_S16) || (xrs_rwe_i == `XRS_RWE_U16);
	wire		word = (xrs_rwe_i == `XRS_RWE_S32) || (xrs_rwe_i == `XRS_RWE_U32);
	wire		dword = (xrs_rwe_i == `XRS_RWE_S64);

	wire	[1:0]	sel_i = byte ? {addr_i[0], ~addr_i[0]} : {2{hword | word | dword}};

	wire		next_mt0 = mem_i ? (hword | byte) : (~wbmstall_i ? mt1 : mt0);
	wire		next_mt1 = mem_i ? word : (~wbmstall_i ? mt2 : mt1);
	wire		next_mt2 = mem_i ? 0 : (~wbmstall_i ? mt3 : mt2);
	wire		next_mt3 = mem_i ? dword : (~wbmstall_i ? 0 : mt3);

	wire		next_st0 = mem_i ? (hword | byte) : (st0 & ~wbmack_i) | (st1 & wbmack_i);
	wire		next_st1 = mem_i ? word : (st1 & ~wbmack_i) | (st2 & wbmack_i);
	wire		next_st2 = mem_i ? 0 : (st2 & ~wbmack_i) | (st3 & wbmack_i);
	wire		next_st3 = mem_i ? dword : (st3 & ~wbmack_i);

	wire	[15:0]	byte_data = {dat_r[7:0], dat_r[7:0]};

	assign		wbmadr_o = ((mt0 & send_low_byte) ? addr_i : 0)
				 | ((mt0 & send_high_byte) ? addr_i : 0)
				 | ((mt0 & send_hword) ? {addr_i[63:1], 1'b0} : 0)
				 | (mt1 ? {addr_i[63:2], 2'b10} : 0)
				 | (mt2 ? {addr_i[63:3], 3'b100} : 0)
				 | (mt3 ? {addr_i[63:3], 3'b110} : 0);
	assign		wbmdat_o = ((mt0 & send_low_byte) ? byte_data : 0)
				 | ((mt0 & send_high_byte) ? byte_data : 0)
				 | ((mt0 & send_hword) ? dat_r[15:0] : 0)
				 | (mt1 ? dat_r[31:16] : 0)
				 | (mt2 ? dat_r[47:32] : 0)
				 | (mt3 ? dat_r[63:48] : 0);
	assign		wbmstb_o = mt0 | mt1 | mt2 | mt3;
	assign		wbmwe_o = wbmstb_o ? we_r : 0;
	assign		wbmsel_o = wbmstb_o ? sel_r : 0;

	assign		wbmcyc_o = st0 | st1 | st2 | st3;

	always @(posedge clk_i) begin
		dat_o <= dat_o;
		rwe_o <= 0;
		we_r <= we_r;
		sel_r <= sel_r;
		xrs_rwe_r <= xrs_rwe_r;
		rd_o <= rd_o;

		mt0 <= next_mt0;
		mt1 <= next_mt1;
		mt2 <= next_mt2;
		mt3 <= next_mt3;

		st0 <= next_st0;
		st1 <= next_st1;
		st2 <= next_st2;
		st3 <= next_st3;

		if(reset_i) begin
			{dat_o, sel_r, rd_o} <= 0;
			{mt0, mt1, mt2, mt3, st0, st1, st2, st3, we_r} <= 0;
			xrs_rwe_r <= 0;
		end
		else begin
			if(nomem_i) begin
				dat_o <= addr_i;
				rwe_o <= xrs_rwe_i;
				rd_o <= xrs_rd_i;
			end

			if(mem_i) begin
				dat_o <= 0;
				dat_r <= dat_i;
				we_r <= we_i;
				sel_r <= sel_i;
				xrs_rwe_r <= xrs_rwe_i;
				rd_o <= xrs_rd_i;
			end

			if(st0 & wbmack_i & send_low_byte) begin
				dat_o[7:0] <= wbmdat_i[7:0];
				we_r <= 0;
				sel_r <= 0;
				xrs_rwe_r <= `XRS_RWE_NO;
			end
			if(st0 & wbmack_i & send_high_byte) begin
				dat_o[7:0] <= wbmdat_i[15:8];
				we_r <= 0;
				sel_r <= 0;
				xrs_rwe_r <= `XRS_RWE_NO;
			end
			if(st0 & wbmack_i & send_hword) begin
				dat_o[15:0] <= wbmdat_i;
				we_r <= 0;
				sel_r <= 0;
				xrs_rwe_r <= `XRS_RWE_NO;
			end

			if(st1 & wbmack_i) begin
				dat_o[31:16] <= wbmdat_i;
			end
			if(st2 & wbmack_i) begin
				dat_o[47:32] <= wbmdat_i;
			end
			if(st3 & wbmack_i) begin
				dat_o[63:48] <= wbmdat_i;
			end

			if(st0 & wbmack_i) begin
				rwe_o <= xrs_rwe_r;
			end
		end
	end

	assign busy_o = wbmcyc_o;
endmodule
