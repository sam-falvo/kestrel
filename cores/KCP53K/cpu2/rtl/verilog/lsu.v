`default_nettype none
`timescale 1ns / 1ps

module lsu(
	input		clk_i,
	input		reset_i,
	input	[63:0]	addr_i,
	input		we_i,
	input		nomem_i,
	input		hword_i,
	output		busy_o,
	output		rwe_o,
	output	[63:0]	dat_o,
	input	[63:0]	dat_i,

	output	[63:0]	wbmadr_o,
	output	[15:0]	wbmdat_o,
	output		wbmwe_o,
	output		wbmstb_o,
	output		wbmcyc_o,
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

	wire		next_mt0 = hword_i | mt1;
	wire		next_mt1 = mt2;
	wire		next_mt2 = mt3;
	wire		next_mt3 = 0;

	wire		next_st0 = hword_i | (st0 & ~wbmack_i) | st1;
	wire		next_st1 = (st1 & ~wbmack_i) | st2;
	wire		next_st2 = (st2 & ~wbmack_i) | st3;
	wire		next_st3 = st3 & ~wbmack_i;

	assign		wbmadr_o = mt0 ? {addr_i[63:1], 1'b0} : 0;
	assign		wbmdat_o = mt0 ? dat_i[15:0] : 0;
	assign		wbmwe_o = mt0 ? we_i : 0;
	assign		wbmstb_o = mt0;

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
			if(st0 & wbmack_i) begin
				dat_o <= {{48{wbmdat_i[15]}}, wbmdat_i};
			end
		end
	end

	assign busy_o = wbmcyc_o;
endmodule
