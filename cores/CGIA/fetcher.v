`timescale 1ns / 1ps

//
// The fetcher is responsible for fetching the next scan-line's worth of video
// data and placing it into a working scanline buffer.  This transfer will be
// isochronous in nature, as it's triggered by the horizontal sync signal.
// Bus arbiters must give this core absolute priority if the integrity of the
// video signal is to be maintained.
//
// If an arbiter does not respect the fetcher's request for the bus, video
// refresh will show artifacts, including but not limited to, partial re-
// display of the previous scanline's contents, regions of black or color 0,
// or smearing.  Exact behavior is deliberately left unspecified.
//
//                  Line Buffer (CGIA)
// +--------------+     +-------------+
// |      s_adr_o |====>| S_ADR_I     |
// |      s_dat_o |====>| S_DAT_I     |
// |       s_we_o |---->| S_WE_I      |
// |              |     +-------------+
// |              |
// |              |      Memory (External)
// |              |     +------------+
// |        adr_o |====>| MEM_ADR_I  |
// |        cyc_o |---->| MEM_CYC_I  |
// |        stb_o |---->| MEM_STB_I  |
// |        dat_i |<====| MEM_DAT_O  |
// |        ack_i |<----| MEM_ACK_O  |
// |              |     +------------+
// |              |
// | line_start_i |<====... from register set of CGIA
// |   line_len_i |<====... from register set of CGIA
// |     fb_adr_i |<====... from register set of CGIA
// |        den_i |<----... from register set of CGIA
// |      vsync_i |<----... from CRTC
// |      hsync_i |<----... from CRTC
// +--------------+
//
// Synopsis:
//
// hsync_i	An active-high horizontal sync signal.  This signal typically
//		comes from the CRTC.  If den_i is asserted when hsync_i goes
//		high, this signals the fetcher to obtain the next batch of
//		halfwords from memory.  The burst length is configurable,
//		per the line_len_i signal.
//
// vsync_i	An active-high vertical sync signal.  This signal typically
//		comes from the CRTC.  When asserted, it causes the fetcher's
//		video fetch pointer to reset to a known value.
//
// den_i	Typically set by the programmer, this is a global "display
//		enable" signal.  If den_i is not asserted, it prevents the
//		fetcher from functioning in any way.
//
// fb_adr_i	This bus holds the starting address for the video frame
//		buffer.  Every VSYNC, the fetcher will reset its internal
//		fetch pointer to this value.  This setting is typically
//		configured by the prorammer via the CGIA's registers.
//
// line_len_i	This bus holds the length (in halfwords) of each video
//		scanline.  At the start of each scanline fetch, an internal
//		counter is reset to this value.  It counts down with each
//		successful halfword fetch.  When it reaches the value 1, the
//		CGIA releases cyc_o in the next cycle, indicating that no
//		more halfwords are to be fetched.
//
// line_start_i	The initial position in the horizontal scanline buffer to start
//		storing fetched video data.  Typically 0.
//
// s_we_o	Write Enable signal to the line buffer unit.
//
// s_adr_o	Write address to the line buffer unit.  At the start of each
//		scanline fetch, this pointer is reset to the value held in
//		line_start_i.  Typically 0, it is configurable by the
//		programmer for implementing certain special effects.
//
// s_dat_o	The data to write to the video line buffer.
//
// clk_i	Wishbone SYSCON clock.
//
// reset_i	Wishbone SYSCON reset.
//
// ack_i	Wishbone bus cycle acknowledge signal.  The addressed memory
//		will drive this signal high when data is valid on the
//		dat_i bus.
//
// adr_o	Bus master current address, which points into the video frame-
//		buffer.  Monotonically increments when fetching data, except
//		during vertical sync, at which point it's reset to fb_adr_i.
//
// dat_i	Wishbone data bus coming from the slave.
//
// cyc_o	Wishbone master CYC_O output.  It's asserted when a bus cycle
//		is required.  It's typically consumed by a bus arbiter.
//
// stb_o	Wishbone master STB_O output.  It's asserted when data is
//		expected on the dat_i bus.  Note that this pin covers all
//		16 bits.
module fetcher(
	input	hsync_i,		// From CRTC: HSYNC (active high)
	input	vsync_i,		// From CRTC: VSYNC (active high)
	input	den_i,			// From REGSET: Display ENable
	input	[23:1] fb_adr_i,	// From REGSET: framebuffer address
	input	[9:1] line_len_i,	// From REGSET: Scanline length, in words
	input	[8:1] line_start_i,	// From REGSET: Initial line buffer address
	output	s_we_o,			// To LINEBUF: Write enable/data valid.
	output	[8:1] s_adr_o,		// To LINEBUF: Buffer write address.
	output	[15:0] s_dat_o,		// To LINEBUF: Buffer data.

	input	clk_i,			// SYSCON clock
	input	reset_i,		// SYSCON reset

	input	ack_i,			// MASTER bus cycle acknowledge
	output	[23:1] adr_o,		// MASTER address bus
	input	[15:0] dat_i,		// MASTER data input bus
	output	cyc_o,			// MASTER bus cycle in progress
	output	stb_o			// MASTER bus cycle in progress.
);
	wire slave_data_valid = cyc_o & ack_i;

	reg [8:0] word_counter;
	wire [8:0] next_word_counter = slave_data_valid ? word_counter - 1 : word_counter;
	wire next_word_counter_zero = next_word_counter == 0;

	wire start_fetching = hsync_i & den_i & ~cyc_o;
	wire stop_fetching = cyc_o & next_word_counter_zero;

	reg cyc_o;
	reg [23:1] adr_o;
	wire [23:1] next_adr = slave_data_valid ? adr_o + 1 : adr_o;

	assign s_we_o = slave_data_valid;	// No special processing for write-enable.
	reg [8:1] s_adr_o;
	wire [8:1] next_s_adr = slave_data_valid ? s_adr_o + 1 : s_adr_o ;

	assign stb_o = cyc_o;
	assign s_dat_o = dat_i;

	always @(posedge clk_i) begin
		// Word Counter
		word_counter <= next_word_counter;

		// Line Buffer Interface Driver
		s_adr_o <= next_s_adr;

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
			s_adr_o <= line_start_i;
		end else if(stop_fetching) begin
			cyc_o <= 0;
		end
	end
endmodule

