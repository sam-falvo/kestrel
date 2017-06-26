`default_nettype none
`timescale 1ns / 1ps

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
// addr_i	Address to read from or write to in memory.
//		Typically hardwired to the output of the ALU.
//		This is a full-width integer for ease of testing.
//
// we_i		1 for write transaction; 0 for read.  Ignored
//		if no memory operation is requested; see
//		hword_i, word_i, and dword_i below.
//
// nomem_i	1 if the value presented to addr_i is intended
//		to be written back to the register file.
//		Mutually exclusive with hword_i, word_i, and
//		dword_i.
//
// hword_i
// word_i
// dword_i	1 to request one of 8-bit (hword_i), 16-bit
//		(hword_i), 32-bit (word_i), or 64-bit (dword_i)
//		transfers.  Mutually exclusive with each other
//		and with nomem_i.
//
//		When the transfer completes, rwe_o will be pulsed.
//		dat_o will hold whatever value was read off of
//		the Wishbone interconnect, which may well be
//		undefined if we_i is was set in conjunction with these
//		command strobes.
//
//		At least one of nomem_i, hword_i, word_i, or dword_i
//		should be asserted every idle clock cycle.  If none are
//		asserted, the register write-back stage of the pipeline
//		will receive a bubble in the next cycle.
//
// dat_i	If one of hword_i, word_i, or dword_i signals the
//		start of a Wishbone transaction, this signal contains
//		the value to be written out over wbmdat_o.
//		Ignored otherwise.
//
// sel_i	Byte lane select signals.  sel_i[1] selects the upper-half
//		of the data bus, while sel_i[0] selects the lower-half.
//		Ignored if no memory operation is requested.
//		Otherwise, passed through to wbmsel_o during bus command
//		phases.
//
//		For word_i and dword_i transfers, sel_i MUST be 2'b11.
//		For hword_i transfers, it may take on one of three valid
//		values:
//
//		2'b11	16-bit half-word transfer.
//		2'b10	8-bit byte transfer.
//		2'b01	8-bit byte transfer.
//		2'b00	Undefined behavior.
//
// Outputs to Register Write-Back Stage:
//
// rwe_o	Pulsed for a single cycle when dat_o holds valid data.
//		Responsibility for zero- or sign-extension lies with
//		the next stage.
//
// dat_o	In the absence of a Wishbone transaction, this reflects
//		the addr_i input.  For all Wishbone transactions, this
//		signal holds the value read off of the Wishbone interconnect.
//		dat_o is valid if, and only if, rwe_o is asserted.
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
	input		hword_i,
	input		word_i,
	input		dword_i,
	output		busy_o,
	output		rwe_o,
	output	[63:0]	dat_o,
	input	[63:0]	dat_i,
	input	[1:0]	sel_i,

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
	reg		rwe_o;
	reg		we_r;
	reg	[1:0]	sel_r;

	// State machine for Wishbone B.4 bus.
	// I truly hate having to use so many MUXes and other
	// combinatorials.  But, it's the only way I can keep
	// the number of clock cycles consumed under control.
	// This will slow the maximum speed of the pipeline,
	// however.

	reg		mt0, mt1, mt2, mt3;	// Master timeslots
	reg		st0, st1, st2, st3;	// Slave timeslots

	wire		send_low_byte = sel_r == 2'b01;
	wire		send_high_byte = sel_r == 2'b10;
	wire		send_hword = sel_r == 2'b11;

	wire		next_mt0 = ~wbmstall_i ? (hword_i | mt1) : mt0;
	wire		next_mt1 = ~wbmstall_i ? (word_i | mt2) : mt1;
	wire		next_mt2 = ~wbmstall_i ? mt3 : mt2;
	wire		next_mt3 = ~wbmstall_i ? dword_i : mt3;

	wire		next_st0 = hword_i | (st0 & ~wbmack_i) | (st1 & wbmack_i);
	wire		next_st1 = word_i | (st1 & ~wbmack_i) | (st2 & wbmack_i);
	wire		next_st2 = (st2 & ~wbmack_i) | (st3 & wbmack_i);
	wire		next_st3 = dword_i | (st3 & ~wbmack_i);

	wire	[15:0]	byte_data = {dat_i[7:0], dat_i[7:0]};

	assign		wbmadr_o = ((mt0 & send_low_byte) ? addr_i : 0)
				 | ((mt0 & send_high_byte) ? addr_i : 0)
				 | ((mt0 & send_hword) ? {addr_i[63:1], 1'b0} : 0)
				 | (mt1 ? {addr_i[63:2], 2'b10} : 0)
				 | (mt2 ? {addr_i[63:3], 3'b100} : 0)
				 | (mt3 ? {addr_i[63:3], 3'b110} : 0);
	assign		wbmdat_o = ((mt0 & send_low_byte) ? byte_data : 0)
				 | ((mt0 & send_high_byte) ? byte_data : 0)
				 | ((mt0 & send_hword) ? dat_i[15:0] : 0)
				 | (mt1 ? dat_i[31:16] : 0)
				 | (mt2 ? dat_i[47:32] : 0)
				 | (mt3 ? dat_i[63:48] : 0);
	assign		wbmstb_o = mt0 | mt1 | mt2 | mt3;
	assign		wbmwe_o = wbmstb_o ? we_r : 0;
	assign		wbmsel_o = wbmstb_o ? sel_r : 0;

	assign		wbmcyc_o = st0 | st1 | st2 | st3;

	always @(posedge clk_i) begin
		dat_o <= dat_o;
		rwe_o <= 0;
		we_r <= we_r;
		sel_r <= sel_r;

		mt0 <= next_mt0;
		mt1 <= next_mt1;
		mt2 <= next_mt2;
		mt3 <= next_mt3;

		st0 <= next_st0;
		st1 <= next_st1;
		st2 <= next_st2;
		st3 <= next_st3;

		if(reset_i) begin
			{dat_o, sel_r} <= 0;
			{mt0, mt1, mt2, mt3, st0, st1, st2, st3, we_r} <= 0;
		end
		else begin
			if(nomem_i) begin
				dat_o <= addr_i;
				rwe_o <= 1;
			end
			if(hword_i || word_i || dword_i) begin
				dat_o <= 0;
				we_r <= we_i;
				sel_r <= sel_i;
			end
			if(st0 & wbmack_i & send_low_byte) begin
				dat_o[7:0] <= wbmdat_i[7:0];
				rwe_o <= 1;
				we_r <= 0;
				sel_r <= 0;
			end
			if(st0 & wbmack_i & send_high_byte) begin
				dat_o[7:0] <= wbmdat_i[15:8];
				rwe_o <= 1;
				we_r <= 0;
				sel_r <= 0;
			end
			if(st0 & wbmack_i & send_hword) begin
				dat_o[15:0] <= wbmdat_i;
				rwe_o <= 1;
				we_r <= 0;
				sel_r <= 0;
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
		end
	end

	assign busy_o = wbmcyc_o;
endmodule
