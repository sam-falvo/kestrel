module fetcher(
	input	hsync_i,		// From CRTC: HSYNC (active high)
	input	vsync_i,		// From CRTC: VSYNC (active high)
	input	den_i,			// From REGSET: Display ENable
	input	[23:1] fb_adr_i,	// From REGSET: framebuffer address
	input	[9:1] line_len_i,	// From REGSET: Scanline length, in words
	output	s_we_o,			// To LINEBUF: Write enable/data valid.

	input	clk_i,			// SYSCON clock
	input	reset_i,		// SYSCON reset

	input	ack_i,			// MASTER bus cycle acknowledge
	output	[23:1] adr_o,		// MASTER address bus
	output	cyc_o			// MASTER bus cycle in progress
);
	wire slave_data_valid = cyc_o & ack_i;

	reg [8:0] word_counter;
	wire [8:0] next_word_counter = slave_data_valid ? word_counter - 1 : word_counter;
	wire next_word_counter_zero = next_word_counter == 0;

	wire start_fetching = hsync_i & den_i & ~cyc_o;
	wire stop_fetching = cyc_o & next_word_counter_zero;

	assign s_we_o = ack_i;		// No special processing for write-enable.

	reg cyc_o;
	reg [23:1] adr_o;

	wire [23:1] next_adr = slave_data_valid ? adr_o + 1 : adr_o;

	always @(posedge clk_i) begin
		// Word Counter
		word_counter <= next_word_counter;

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
			word_counter <= line_len_i;
		end else if(stop_fetching) begin
			cyc_o <= 0;
		end
	end
endmodule

