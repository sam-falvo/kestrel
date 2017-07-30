`default_nettype none
`timescale 1ns / 1ps

`include "asserts.vh"
`include "xrs.vh"

module lsu_tb();
	reg	[11:0]	story_to;
	reg		fault_to;
	reg		clk_i, reset_i, we_i, nomem_i, mem_i;
	reg	[2:0]	xrs_rwe_i;
	reg	[63:0]	addr_i, dat_i;
	reg	[4:0]	xrs_rd_i;

	wire		busy_o;
	wire	[2:0]	rwe_o;
	wire	[63:0]	dat_o;
	wire	[4:0]	rd_o;

	wire	[63:0]	wbmadr_o;
	wire	[15:0]	wbmdat_o;
	wire		wbmwe_o, wbmstb_o;
	wire	[1:0]	wbmsel_o;
	reg		wbmack_i, wbmstall_i;
	reg	[15:0]	wbmdat_i;

	lsu ls(
		.clk_i(clk_i),
		.reset_i(reset_i),
		.addr_i(addr_i),
		.we_i(we_i),
		.nomem_i(nomem_i),
		.mem_i(mem_i),
		.xrs_rwe_i(xrs_rwe_i),
		.busy_o(busy_o),
		.rwe_o(rwe_o),
		.dat_o(dat_o),
		.dat_i(dat_i),

		.xrs_rd_i(xrs_rd_i),
		.rd_o(rd_o),

		.wbmadr_o(wbmadr_o),
		.wbmdat_o(wbmdat_o),
		.wbmwe_o(wbmwe_o),
		.wbmstb_o(wbmstb_o),
		.wbmsel_o(wbmsel_o),
		.wbmack_i(wbmack_i),
		.wbmstall_i(wbmstall_i),
		.wbmdat_i(wbmdat_i)
	);

	`STANDARD_FAULT
	`DEFASSERT0(busy, o)
	`DEFASSERT(rwe, 2, o)
	`DEFASSERT(dat, 63, o)
	`DEFASSERT(wbmadr, 63, o)
	`DEFASSERT(wbmdat, 15, o)
	`DEFASSERT(wbmsel, 1, o)
	`DEFASSERT0(wbmwe, o)
	`DEFASSERT0(wbmstb, o)
	`DEFASSERT(rd, 4, o)

	always begin
		#5 clk_i <= ~clk_i;
	end

	task reset;
	begin
		reset_i <= 1;
		wait(~clk_i); wait(clk_i); #1;
		reset_i <= 0;
	end
	endtask

	initial begin
		$dumpfile("lsu.vcd");
		$dumpvars;

		{
		  wbmack_i, addr_i, dat_i, we_i, nomem_i, mem_i,
		  clk_i, reset_i, story_to, fault_to,
		  wbmstall_i, xrs_rd_i, xrs_rwe_i
		} <= 0;

		wait(~clk_i); wait(clk_i); #1;

		reset;
		assert_busy(0);

		// Given that we're not accessing memory,
		// the LSU must pass the address through to the
		// register writeback stage.
		//
		// Note that we pass the address, and not the input
		// data, since that's the value generated by the CPU's
		// ALU (instruction execute) stage.

		story_to <= 12'h010;

		addr_i <= 64'h1122334455667788;
		dat_i <= 64'h7766554433221100;
		we_i <= 0;
		nomem_i <= 1;
		xrs_rwe_i <= `XRS_RWE_S64;
		wait(~clk_i); wait(clk_i); #1;
		assert_dat(64'h1122334455667788);
		assert_rwe(`XRS_RWE_S64);

		story_to <= 12'h014;

		addr_i <= 64'h1122334455667788;
		dat_i <= 64'h7766554433221100;
		we_i <= 0;
		nomem_i <= 1;
		xrs_rwe_i <= `XRS_RWE_S32;
		wait(~clk_i); wait(clk_i); #1;
		assert_dat(64'h1122334455667788);
		assert_rwe(`XRS_RWE_S32);

		// we_i is ignored during non-memory cycles.

		story_to <= 12'h018;

		addr_i <= 64'h1122334455667788;
		dat_i <= 64'h7766554433221100;
		we_i <= 1;
		nomem_i <= 1;
		xrs_rwe_i <= `XRS_RWE_S64;
		wait(~clk_i); wait(clk_i); #1;
		assert_dat(64'h1122334455667788);
		assert_rwe(`XRS_RWE_S64);

		we_i <= 0;

		// When idle, the LSU must disable writebacks to the register
		// file.

		story_to <= 12'h020;

		nomem_i <= 0;
		xrs_rwe_i <= `XRS_RWE_U32;
		wait(~clk_i); wait(clk_i); #1;
		assert_rwe(`XRS_RWE_NO);

		// When writing a half-word to memory,
		// the LSU must initiate and wait for the complete
		// Wishbone transaction to complete.  Further, it must
		// disable register write-back.
		//
		// Note that the LSU performs both a read AND a write,
		// irrespective of the we_i signal.  It's up to the
		// external peripheral to respect the we_i signal.
		// Similarly, while the LSU "reads" data even during a
		// write transaction, the register writeback stage is
		// responsible for ignoring this value, as rd_i will be
		// forced to 0.

		story_to <= 12'h040;

		mem_i <= 1;
		xrs_rwe_i <= `XRS_RWE_S16;
		addr_i <= 64'h1122334455667788;
		dat_i <= 64'h7766554433221100;
		we_i <= 1;
		wbmdat_i <= 16'hDEAD;

		wait(~clk_i); wait(clk_i); #1;

		xrs_rwe_i <= `XRS_RWE_NO;
		mem_i <= 0;
		we_i <= 0;

		assert_busy(1);
		assert_wbmadr(64'h1122334455667788);
		assert_wbmdat(16'h1100);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmstb(0);
		assert_wbmsel(2'b00);
		assert_rwe(`XRS_RWE_NO);
		
		wbmack_i <= 1;

		wait(~clk_i); wait(clk_i); #1;

		assert_rwe(`XRS_RWE_S16);
		assert_dat(64'h000000000000DEAD);

		wbmack_i <= 0;

		// When writing a full-word to memory,
		// the LSU must initiate and wait for the complete
		// Wishbone transaction to complete.  In this case,
		// the transfer consists of two cycles (one for lowest
		// 16-bits, one for highest 16-bits).

		story_to <= 12'h050;

		mem_i <= 1;
		xrs_rwe_i <= `XRS_RWE_S32;
		addr_i <= 64'h1122334455667788;
		dat_i <= 64'h7766554433221100;
		we_i <= 1;
		wbmdat_i <= 16'hDEAD;

		wait(~clk_i); wait(clk_i); #1;

		mem_i <= 0;
		xrs_rwe_i <= `XRS_RWE_NO;
		we_i <= 0;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778A);
		assert_wbmdat(16'h3322);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h1122334455667788);
		assert_wbmdat(16'h1100);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmstb(0);
		assert_wbmsel(2'b00);
		assert_rwe(`XRS_RWE_NO);
		
		wbmack_i <= 1;
		wbmdat_i <= 16'hDEAD;

		wait(~clk_i); wait(clk_i); #1;

		wbmdat_i <= 16'hBEEF;

		wait(~clk_i); wait(clk_i); #1;

		assert_rwe(`XRS_RWE_S32);
		assert_dat(64'h00000000DEADBEEF);

		wbmack_i <= 0;

		// When writing a double-word to memory,
		// the LSU must initiate and wait for the complete
		// Wishbone transaction to complete.  In this case,
		// the transfer consists of four cycles.

		story_to <= 12'h060;

		mem_i <= 1;
		xrs_rwe_i <= `XRS_RWE_S64;
		addr_i <= 64'h1122334455667788;
		dat_i <= 64'h7766554433221100;
		we_i <= 1;

		wait(~clk_i); wait(clk_i); #1;

		mem_i <= 0;
		xrs_rwe_i <= `XRS_RWE_NO;
		we_i <= 0;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778E);
		assert_wbmdat(16'h7766);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778C);
		assert_wbmdat(16'h5544);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778A);
		assert_wbmdat(16'h3322);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h1122334455667788);
		assert_wbmdat(16'h1100);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmstb(0);
		assert_wbmsel(2'b00);
		assert_rwe(`XRS_RWE_NO);
		
		wbmack_i <= 1;
		wbmdat_i <= 16'hDEAD;

		wait(~clk_i); wait(clk_i); #1;

		wbmdat_i <= 16'hBEEF;

		wait(~clk_i); wait(clk_i); #1;

		wbmdat_i <= 16'h0BAD;

		wait(~clk_i); wait(clk_i); #1;

		wbmdat_i <= 16'hC0DE;

		wait(~clk_i); wait(clk_i); #1;

		assert_rwe(`XRS_RWE_S64);
		assert_dat(64'hDEADBEEF0BADC0DE);

		wbmack_i <= 0;

		// When writing individual bytes to memory,
		// yeah, you know the drill.  But this time, things
		// are a little different.

		// These tests exercise the lower byte.

		story_to <= 12'h080;

		mem_i <= 1;
		xrs_rwe_i <= `XRS_RWE_S8;
		addr_i <= 64'h1122334455667788;
		dat_i <= 64'h77665544332211A5;
		we_i <= 1;
		wbmdat_i <= 16'hDEAD;

		wait(~clk_i); wait(clk_i); #1;

		mem_i <= 0;
		xrs_rwe_i <= `XRS_RWE_NO;
		we_i <= 0;

		assert_busy(1);
		assert_wbmadr(64'h1122334455667788);
		assert_wbmdat(16'hA5A5);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b01);
		assert_rwe(`XRS_RWE_NO);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmstb(0);
		assert_wbmsel(2'b00);
		assert_rwe(`XRS_RWE_NO);
		
		wbmack_i <= 1;

		wait(~clk_i); wait(clk_i); #1;

		assert_rwe(`XRS_RWE_S8);
		assert_dat(64'h00000000000000AD);

		wbmack_i <= 0;

		// These tests exercise the upper byte.

		story_to <= 12'h088;

		mem_i <= 1;
		xrs_rwe_i <= `XRS_RWE_S8;
		addr_i <= 64'h1122334455667789;
		dat_i <= 64'h77665544332211A5;
		we_i <= 1;
		wbmdat_i <= 16'hDEAD;

		wait(~clk_i); wait(clk_i); #1;

		mem_i <= 0;
		xrs_rwe_i <= `XRS_RWE_NO;
		we_i <= 0;

		assert_busy(1);
		assert_wbmadr(64'h1122334455667789);
		assert_wbmdat(16'hA5A5);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b10);
		assert_rwe(`XRS_RWE_NO);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmstb(0);
		assert_wbmsel(2'b00);
		assert_rwe(`XRS_RWE_NO);
		
		wbmack_i <= 1;

		wait(~clk_i); wait(clk_i); #1;

		assert_rwe(`XRS_RWE_S8);
		assert_dat(64'h00000000000000DE);

		wbmack_i <= 0;

		// So far, all tests have exercised separated cycles for
		// bus commands and bus responses.  But, these operate over
		// independent sub-buses, so it should be possible to overlap
		// their operation.  The perfect, most ideal case would be
		// single-cycle response times.

		story_to <= 12'h0A0;

		mem_i <= 1;
		xrs_rwe_i <= `XRS_RWE_S64;
		addr_i <= 64'h1122334455667788;
		dat_i <= 64'h7766554433221100;
		we_i <= 1;

		wait(~clk_i); wait(clk_i); #1;

		mem_i <= 0;
		xrs_rwe_i <= `XRS_RWE_NO;
		we_i <= 0;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778E);
		assert_wbmdat(16'h7766);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wbmack_i <= 1;
		wbmdat_i <= 16'hDEAD;

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778C);
		assert_wbmdat(16'h5544);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wbmdat_i <= 16'hBEEF;

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778A);
		assert_wbmdat(16'h3322);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wbmdat_i <= 16'hFEED;

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h1122334455667788);
		assert_wbmdat(16'h1100);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wbmdat_i <= 16'hFACE;

		wait(~clk_i); wait(clk_i); #1;

		wbmack_i <= 0;

		assert_rwe(`XRS_RWE_S64);
		assert_dat(64'hDEADBEEFFEEDFACE);

		// The STALL_I signal is required to slow down the command-
		// phase of bus transactions.  We repeat a 64-bit transaction
		// here, but stall for 3 cycles mid-way.

		story_to <= 12'h0B0;

		mem_i <= 1;
		xrs_rwe_i <= `XRS_RWE_S64;
		addr_i <= 64'h1122334455667788;
		dat_i <= 64'h7766554433221100;
		we_i <= 1;

		wait(~clk_i); wait(clk_i); #1;

		mem_i <= 0;
		xrs_rwe_i <= `XRS_RWE_NO;
		we_i <= 0;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778E);
		assert_wbmdat(16'h7766);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778C);
		assert_wbmdat(16'h5544);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wbmack_i <= 1;
		wbmdat_i <= 16'hFEED;

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778A);
		assert_wbmdat(16'h3322);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wbmstall_i <= 1;
		wbmack_i <= 0;

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778A);
		assert_wbmdat(16'h3322);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wbmstall_i <= 1;
		wbmack_i <= 0;

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778A);
		assert_wbmdat(16'h3322);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wbmstall_i <= 1;
		wbmack_i <= 0;

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778A);
		assert_wbmdat(16'h3322);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wbmstall_i <= 0;
		wbmack_i <= 1;
		wbmdat_i <= 16'hFACE;

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h1122334455667788);
		assert_wbmdat(16'h1100);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wbmdat_i <= 16'h00C0;

		wait(~clk_i); wait(clk_i); #1;

		wbmdat_i <= 16'hFFEE;

		wait(~clk_i); wait(clk_i); #1;

		wbmack_i <= 0;
		wbmdat_i <= 0;

		assert_rwe(`XRS_RWE_S64);
		assert_dat(64'hFEEDFACE00C0FFEE);

		// When writing a value fetched from memory, we
		// must propegate the destination register address.

		story_to <= 12'h0C0;

		mem_i <= 1;
		xrs_rwe_i <= `XRS_RWE_S64;
		addr_i <= 64'h1122334455667788;
		dat_i <= 64'h7766554433221100;
		we_i <= 1;
		xrs_rd_i <= 13;

		wait(~clk_i); wait(clk_i); #1;

		mem_i <= 0;
		xrs_rwe_i <= `XRS_RWE_NO;
		we_i <= 0;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778E);
		assert_wbmdat(16'h7766);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778C);
		assert_wbmdat(16'h5544);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778A);
		assert_wbmdat(16'h3322);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h1122334455667788);
		assert_wbmdat(16'h1100);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmstb(0);
		assert_wbmsel(2'b00);
		assert_rwe(`XRS_RWE_NO);
		
		wbmack_i <= 1;
		wbmdat_i <= 16'hDEAD;

		wait(~clk_i); wait(clk_i); #1;

		wbmdat_i <= 16'hBEEF;

		wait(~clk_i); wait(clk_i); #1;

		wbmdat_i <= 16'h0BAD;

		wait(~clk_i); wait(clk_i); #1;

		wbmdat_i <= 16'hC0DE;

		wait(~clk_i); wait(clk_i); #1;

		assert_rwe(`XRS_RWE_S64);
		assert_dat(64'hDEADBEEF0BADC0DE);
		assert_rd(13);

		wbmack_i <= 0;

		// We must propegate destination register for
		// non-memory operations as well.

		story_to <= 12'h0C8;

		addr_i <= 64'h1122334455667788;
		dat_i <= 64'h7766554433221100;
		we_i <= 0;
		nomem_i <= 1;
		xrs_rd_i <= 25;
		xrs_rwe_i <= `XRS_RWE_S64;
		wait(~clk_i); wait(clk_i); #1;
		nomem_i <= 0;
		assert_dat(64'h1122334455667788);
		assert_rwe(`XRS_RWE_S64);
		assert_rd(25);

		// Testing unsigned_i effectiveness.  If asserted,
		// any signed operation must be converted to an
		// unsigned operation.

		story_to <= 12'h0D0;

		mem_i <= 1;
		xrs_rwe_i <= `XRS_RWE_U16;
		addr_i <= 64'h1122334455667788;
		dat_i <= 64'h7766554433221100;
		we_i <= 1;
		wbmdat_i <= 16'hDEAD;

		wait(~clk_i); wait(clk_i); #1;

		mem_i <= 0;
		xrs_rwe_i <= `XRS_RWE_NO;
		we_i <= 0;

		assert_busy(1);
		assert_wbmadr(64'h1122334455667788);
		assert_wbmdat(16'h1100);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_wbmsel(2'b11);
		assert_rwe(`XRS_RWE_NO);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmstb(0);
		assert_wbmsel(2'b00);
		assert_rwe(`XRS_RWE_NO);
		
		wbmack_i <= 1;

		wait(~clk_i); wait(clk_i); #1;

		assert_rwe(`XRS_RWE_U16);
		assert_dat(64'h000000000000DEAD);

		wbmack_i <= 0;

		#100;
		$stop;
	end
endmodule

