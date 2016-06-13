module fetcher(
	input	hsync_i,	// From CRTC: HSYNC (active high)
	input	den_i,		// From CRTC: Display ENable

	input	clk_i,		// SYSCON clock
	input	reset_i,	// SYSCON reset

	output	cyc_o		// MASTER bus cycle in progress
);
	wire start_fetching = hsync_i & den_i;

	reg cyc_o;

	always @(posedge clk_i) begin
		if(reset_i) begin
			cyc_o <= 0;
		end else if(start_fetching) begin
			cyc_o <= 1;
		end;
	end
endmodule

