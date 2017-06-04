`default_nettype none
`timescale 1ns / 1ps

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

	// State machine for Wishbone B.4 bus.
	// I truly hate having to use so many MUXes and other
	// combinatorials.  But, it's the only way I can keep
	// the number of clock cycles consumed under control.
	// This will slow the maximum speed of the pipeline,
	// however.

	reg		mt0, mt1, mt2, mt3;	// Master timeslots
	reg		st0, st1, st2, st3;	// Slave timeslots

	wire		send_low_byte = sel_i == 2'b01;
	wire		send_high_byte = sel_i == 2'b10;
	wire		send_hword = sel_i == 2'b11;

	wire		next_mt0 = ~wbmstall_i ? (hword_i | mt1) : mt0;
	wire		next_mt1 = ~wbmstall_i ? (word_i | mt2) : mt1;
	wire		next_mt2 = ~wbmstall_i ? mt3 : mt2;
	wire		next_mt3 = ~wbmstall_i ? dword_i : mt3;

	wire		next_st0 = hword_i | (st0 & ~wbmack_i) | st1;
	wire		next_st1 = word_i | (st1 & ~wbmack_i) | st2;
	wire		next_st2 = (st2 & ~wbmack_i) | st3;
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
	assign		wbmwe_o = wbmstb_o ? we_i : 0;
	assign		wbmsel_o = wbmstb_o ? sel_i : 0;

	assign		wbmcyc_o = st0 | st1 | st2 | st3;

	always @(posedge clk_i) begin
		dat_o <= dat_o;
		rwe_o <= 0;

		mt0 <= next_mt0;
		mt1 <= next_mt1;
		mt2 <= next_mt2;
		mt3 <= next_mt3;

		st0 <= next_st0;
		st1 <= next_st1;
		st2 <= next_st2;
		st3 <= next_st3;

		if(reset_i) begin
			dat_o <= 0;
			{mt0, mt1, mt2, mt3, st0, st1, st2, st3} <= 0;
		end
		else begin
			if(nomem_i) begin
				dat_o <= addr_i;
				rwe_o <= 1;
			end
			if(hword_i || word_i || dword_i) begin
				dat_o <= 0;
			end
			if(st0 & wbmack_i & send_low_byte) begin
				dat_o[7:0] <= wbmdat_i[7:0];
			end
			if(st0 & wbmack_i & send_high_byte) begin
				dat_o[7:0] <= wbmdat_i[15:8];
			end
			if(st0 & wbmack_i & send_hword) begin
				dat_o[15:0] <= wbmdat_i;
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
