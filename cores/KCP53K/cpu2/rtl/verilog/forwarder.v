`default_nettype none
`timescale 1ns / 1ps

module forwarder(
	input	[4:0]	ra_i,
	input	[4:0]	rb_i,
	input	[4:0]	rd_i,
	input	[63:0]	dat_i,
	output		hita_o,
	output		hitb_o,
	output	[63:0]	qa_o,
	output	[63:0]	qb_o
);
	assign hita_o = (ra_i === rd_i);
	assign hitb_o = (rb_i === rd_i);
	assign qa_o = hita_o ? dat_i : 0;
	assign qb_o = hitb_o ? dat_i : 0;
endmodule
