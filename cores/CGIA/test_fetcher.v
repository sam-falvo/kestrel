`timescale 1ns / 1ps

module test_fetcher();
	reg [15:0] story_o;	// Holds grep tag for failing test cases.

	reg clk_o;		// Wishbone SYSCON clock
	reg reset_o;		// Wishbone SYSCON reset

	// 50MHz clock (1/50MHz = 20ns)
	always begin
		#20 clk_o <= ~clk_o;
	end

	// Test script starts here.
	initial begin
		clk_o <= 0;
		reset_o <= 1;
		#100 reset_o <= 0;
		#100 $display("@I OK");
		$stop;
	end
endmodule
