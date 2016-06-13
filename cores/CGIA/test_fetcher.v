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
	wire [23:1] adr_i_raw;	// Wishbone MASTER address bus.
	reg ack_o;		// Wishbone MASTER cycle acknowledge.

	reg hsync_o;		// CRTC HSYNC output (active high).
	reg vsync_o;		// CRTC VSYNC output (active high).
	reg den_o;		// REGSET Display ENable.
	reg [23:1] fb_adr_o;	// REGSET Start of frame buffer.

	// Convenience assignments, so I don't have to do mental gyrations
	// in the test code.
	wire [23:0] adr_i = {adr_i_raw[23:1], 1'b0};

	// Core Under Test
	fetcher f(
		.den_i(den_o),
		.hsync_i(hsync_o),
		.vsync_i(vsync_o),

		.fb_adr_i(fb_adr_o),

		.clk_i(clk_o),
		.reset_i(reset_o),

		.ack_i(ack_o),
		.cyc_o(cyc_i),
		.adr_o(adr_i_raw)
	);

	// 50MHz clock (1/50MHz = 20ns)
	always begin
		#20 clk_o <= ~clk_o;
	end

	// Test script starts here.
	initial begin
		clk_o <= 0;
		hsync_o <= 0;
		vsync_o <= 0;
		den_o <= 0;
		ack_o <= 1;

		fb_adr_o <= (24'hFF0000) >> 1;

		// Going into reset, the CGIA must negate its CYC_O signal.
		story_o <= 16'h0000;
		wait(clk_o); wait(~clk_o);
		reset_o <= 1;
		wait(clk_o); wait(~clk_o);
		if(cyc_i !== 0) begin
			$display("@E %04X Fetcher needs to negate CYC_O on reset", story_o);
			$stop;
		end

		// Coming out of reset, the CGIA must keep CYC_O negated.
		story_o <= 16'h0100;
		reset_o <= 0;
		wait(clk_o); wait(~clk_o);
		if(cyc_i !== 0) begin
			$display("@E %04X Fetcher needs to negate CYC_O on reset", story_o);
			$stop;
		end

		// Before we can fetch, we need to load the current framebuffer address register.
		// This is done by reading the framebuffer base address configuration register
		// at every VSYNC period.
		story_o <= 16'h0200;
		vsync_o <= 1;
		wait(clk_o); wait(~clk_o);
		if(adr_i != 24'hFF0000) begin
			$display("@E %04X Expected address $%06X, got $%06X", story_o, 24'hFF0000, adr_i);
			$stop;
		end

		// When we start horizontal sync and the display is enabled,
		// the fetcher needs to start fetching from memory.  It should
		// request the bus by asserting its CYC_O.  But, only if DEN_I
		// is asserted.
		story_o <= 16'h0300;
		hsync_o <= 1;
		den_o <= 0;
		wait(clk_o); wait(~clk_o);
		if(cyc_i !== 0) begin
			$display("@E %04X Fetcher needs to both HSYNC and DEN to start fetching phase.", story_o);
			$stop;
		end

		story_o <= 16'h0310;
		vsync_o <= 0;
		hsync_o <= 1;
		den_o <= 1;
		wait(clk_o); wait(~clk_o);
		if(~cyc_i) begin
			$display("@E %04X Fetcher needs to request the bus on HSYNC", story_o);
			$stop;
		end
		if(adr_i !== 24'hFF0000) begin
			$display("@E %04X Expected address $%06X, got $%06X", story_o, 24'hFF0000, adr_i);
			$stop;
		end

		// Fetching may well take longer than the span of time HSYNC is asserted.
		story_o <= 16'h0400;
		hsync_o <= 0;
		den_o <= 1;
		wait(clk_o); wait(~clk_o);
		if(~cyc_i) begin
			$display("@E %04X Fetcher needs to continue fetching after HSYNC", story_o);
			$stop;
		end
		if(adr_i !== 24'hFF0002) begin
			$display("@E %04X Expected address $%06X, got $%06X", story_o, 24'hFF0002, adr_i);
			$stop;
		end

		// Fetching must accept wait-states.
		story_o <= 16'h0500;
		ack_o <= 0;
		wait(clk_o); wait(~clk_o);
		if(adr_i !== 24'hFF0002) begin
			$display("@E %04X Expected address $%06X, got $%06X", story_o, 24'hFF0002, adr_i);
			$stop;
		end

		story_o <= 16'h0501;
		wait(clk_o); wait(~clk_o);
		if(adr_i !== 24'hFF0002) begin
			$display("@E %04X Expected address $%06X, got $%06X", story_o, 24'hFF0002, adr_i);
			$stop;
		end

		story_o <= 16'h0502;
		wait(clk_o); wait(~clk_o);
		if(adr_i !== 24'hFF0002) begin
			$display("@E %04X Expected address $%06X, got $%06X", story_o, 24'hFF0002, adr_i);
			$stop;
		end

		story_o <= 16'h0503;
		ack_o <= 1;
		wait(clk_o); wait(~clk_o);
		if(adr_i !== 24'hFF0004) begin
			$display("@E %04X Expected address $%06X, got $%06X", story_o, 24'hFF0004, adr_i);
			$stop;
		end

		#100 $display("@I OK");
		$stop;
	end
endmodule
