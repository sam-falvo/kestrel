module fetcher(
	input	clk_i,		// SYSCON clock
	input	reset_i,	// SYSCON reset

	output	cyc_o		// MASTER bus cycle in progress
);
	reg cyc_o;

	initial begin
		cyc_o <= 0;
	end
endmodule

