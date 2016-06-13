`timescale 1ns / 1ps

//
// This test script exercises the CGIA's DMA fetching facility, the "fetcher."
// The Fetcher is a non-pipelined Wishbone bus master interface, so we will
// assume the role of an attached memory slave.
//
// The fetcher is pretty dumb: it simply reads a fixed number of 16-bit words
// from memory and deposits them, as-is, into one of two line buffers.
//
// Since the fetcher is cued into action by other CGIA components, we also
// impersonate them as well.
//

module test_fetcher();
	reg [15:0] story_o;	// Holds grep tag for failing test cases.

	reg clk_o;		// Wishbone SYSCON clock
	reg reset_o;		// Wishbone SYSCON reset

	wire cyc_i;		// Wishbone MASTER bus cycle in progress.

	reg hsync_o;		// CRTC HSYNC output (active high).
	reg den_o;		// CRTC Display ENable.

	// Core Under Test
	fetcher f(
		.den_i(den_o),
		.hsync_i(hsync_o),

		.clk_i(clk_o),
		.reset_i(reset_o),

		.cyc_o(cyc_i)
	);

	// 50MHz clock (1/50MHz = 20ns)
	always begin
		#20 clk_o <= ~clk_o;
	end

	// Test script starts here.
	initial begin
		clk_o <= 0;
		hsync_o <= 0;
		den_o <= 0;

		// Going into reset, the CGIA must negate its CYC_O signal.
		story_o <= 16'h0000;
		wait(clk_o); wait(~clk_o);
		reset_o <= 1;
		wait(clk_o); wait(~clk_o);
		if(cyc_i) begin
			$display("@E %04X Fetcher needs to negate CYC_O on reset", story_o);
			$stop;
		end

		// Coming out of reset, the CGIA must keep CYC_O negated.
		story_o <= 16'h0100;
		reset_o <= 0;
		wait(clk_o); wait(~clk_o);
		if(cyc_i) begin
			$display("@E %04X Fetcher needs to negate CYC_O on reset", story_o);
			$stop;
		end

		// When we start horizontal sync and the display is enabled,
		// the fetcher needs to start fetching from memory.  It should
		// request the bus by asserting its CYC_O.
		story_o <= 16'h0200;
		hsync_o <= 1;
		den_o <= 0;
		wait(clk_o); wait(~clk_o);
		if(cyc_i) begin
			$display("@E %04X Fetcher needs to both HSYNC and DEN to start fetching phase.", story_o);
			$stop;
		end

		story_o <= 16'h0210;
		hsync_o <= 1;
		den_o <= 1;
		wait(clk_o); wait(~clk_o);
		if(~cyc_i) begin
			$display("@E %04X Fetcher needs to request the bus on HSYNC", story_o);
			$stop;
		end

		#100 $display("@I OK");
		$stop;
	end
endmodule
