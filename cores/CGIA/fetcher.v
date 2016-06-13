module fetcher(
	input	hsync_i,	// From CRTC: HSYNC (active high)
	input	den_i,		// From CRTC: Display ENable

	input	clk_i,		// SYSCON clock
	input	reset_i,	// SYSCON reset

	output	cyc_o		// MASTER bus cycle in progress
);
	reg cyc_o;

	wire busreq;
	assign busreq = den_i & hsync_i;

	always @(posedge clk_i) begin
		cyc_o <= busreq;
	end
endmodule

