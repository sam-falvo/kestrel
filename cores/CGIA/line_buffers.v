`timescale 1ns / 1ps

// This module implements the two scanline buffers used to hold playfield
// data.  They are configured such that while video refresh draws data from
// one buffer, the video fetcher is storing data into the other.  Thus,
// there is a single scanline latency from the time video data is fetched to
// the time it's actually displayed.
//
// The block diagram of the interface looks like this:
//
//      +-------------------+
// ====>| F_ADR_I   F_DAT_O |====>
// ====>| S_ADR_I           |
// ====>| S_DAT_I           |
// ---->| S_WE_I            |
// ---->| ODD_I             |
// ---->| CLK_I             |
//      +-------------------+
//
// F_ADR_I	The halfword address into the line buffer for video data you
//		want to fetch.  The video refresh circuit typically drives
//		this bus.
//
// S_ADR_I	The halfword address into the line buffer for video data you
//		want to store.  The video fetcher circuit typically drives
//		this bus.  Note that F_ADR_I and S_ADR_I MAY equal each other
//		at any time; this is allowed because fetching and storing
//		each occurs to opposite line buffers.
//
// S_DAT_I	The halfword video data you want to store at S_ADR_I.  Note
//		that video data only stores on the rising edge of CLK_I,
//		and even then, only when S_WE_I is asserted.
//
// S_WE_I	The video fetcher will assert this signal when data is valid
//		on S_DAT_I; otherwise, it will negate this signal to prevent
//		storing garbage.  S_WE_I must also be negated at the end of
//		a video fetch burst to prevent overflowing the buffer.
//
// ODD_I	Asserted when displaying video scanlines 1, 3, 5, 7, etc. and
//		negated otherwise.  This signal controls which buffers are
//		used for fetching and refresh.  Typically driven either by
//		the CRTC.
//
// CLK_I	Wishbone SYSCON clock.
//
// This circuit originally appeared in the MGIA-1 core, used in the Kestrel-2.

module line_buffers(
	input		CLK_I,
	input		ODD_I,
	input	[ 5:0]	F_ADR_I,
	output	[15:0]	F_DAT_O,
	input	[ 5:0]	S_ADR_I,
	input	[15:0]	S_DAT_I,
	input		S_WE_I
);

	reg	[15:0]	line_a[0:511];
	reg	[15:0]	line_b[0:511];
	reg	[15:0]	f_q;

	assign	F_DAT_O = f_q;

	always @(posedge CLK_I) begin
		f_q <= (ODD_I)? line_b[F_ADR_I] : line_a[F_ADR_I];
		if(S_WE_I & ODD_I)	line_a[S_ADR_I] <= S_DAT_I;
		if(S_WE_I & !ODD_I)	line_b[S_ADR_I] <= S_DAT_I;
	end
endmodule
