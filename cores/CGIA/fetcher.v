module fetcher(
	input	hsync_i,		// From CRTC: HSYNC (active high)
	input	vsync_i,		// From CRTC: VSYNC (active high)
	input	den_i,			// From REGSET: Display ENable
	input	[23:1] fb_adr_i,	// From REGSET: framebuffer address

	input	clk_i,			// SYSCON clock
	input	reset_i,		// SYSCON reset

	input	ack_i,			// MASTER bus cycle acknowledge
	output	[23:1] adr_o,		// MASTER address bus
	output	cyc_o			// MASTER bus cycle in progress
);
	wire start_fetching = hsync_i & den_i & ~cyc_o;
	wire slave_data_valid = cyc_o & ack_i;

	reg cyc_o;
	reg [23:1] adr_o;
	wire [23:1] next_adr = slave_data_valid ? adr_o + 1 : adr_o;

	always @(posedge clk_i) begin
		// Address bus driver
		case({cyc_o, vsync_i})
		{1'b0, 1'b1}:	adr_o <= fb_adr_i;
		{1'b1, 1'b1}:	adr_o <= fb_adr_i;
		{1'b1, 1'b0}:	adr_o <= next_adr;
		default:	adr_o <= adr_o;
		endcase

		if(reset_i) begin
			cyc_o <= 0;
		end else if(start_fetching) begin
			cyc_o <= 1;
		end
	end
endmodule

