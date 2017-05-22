`default_nettype none
`timescale 1ns / 1ps
`include "asserts.vh"

module lsu_tb();
	reg	[11:0]	story_to;
	reg		fault_to;
	reg		clk_i, reset_i;

	always begin
		#5 clk_i <= ~clk_i;
	end

	task reset;
	begin
		reset_i <= 1;
		wait(~clk_i); wait(clk_i); #1;
		reset_i <= 0;
		wait(~clk_i); wait(clk_i); #1;
	end
	endtask

	initial begin
		$dumpfile("lsu.vcd");
		$dumpvars;

		{clk_i, reset_i, story_to, fault_to} <= 0;
		wait(~clk_i); wait(clk_i); #1;

		reset;

		#100;
		$stop;
	end
endmodule

