`default_nettype none
`timescale 1ns / 1ps
`include "asserts.vh"

module lsu_tb();
	reg	[11:0]	story_to;
	reg		fault_to;
	reg		clk_i, reset_i, we_i, nomem_i, hword_i, word_i, dword_i;
	reg	[63:0]	addr_i, dat_i;

	wire		busy_o, rwe_o;
	wire	[63:0]	dat_o;

	wire	[63:0]	wbmadr_o;
	wire	[15:0]	wbmdat_o;
	wire		wbmwe_o, wbmstb_o;
	reg		wbmack_i;
	reg	[15:0]	wbmdat_i;

	lsu ls(
		.clk_i(clk_i),
		.reset_i(reset_i),
		.addr_i(addr_i),
		.we_i(we_i),
		.nomem_i(nomem_i),
		.hword_i(hword_i),
		.word_i(word_i),
		.dword_i(dword_i),
		.busy_o(busy_o),
		.rwe_o(rwe_o),
		.dat_o(dat_o),
		.dat_i(dat_i),

		.wbmadr_o(wbmadr_o),
		.wbmdat_o(wbmdat_o),
		.wbmwe_o(wbmwe_o),
		.wbmstb_o(wbmstb_o),
		.wbmack_i(wbmack_i),
		.wbmdat_i(wbmdat_i)
	);

	`STANDARD_FAULT
	`DEFASSERT0(busy, o)
	`DEFASSERT0(rwe, o)
	`DEFASSERT(dat, 63, o)
	`DEFASSERT(wbmadr, 63, o)
	`DEFASSERT(wbmdat, 15, o)
	`DEFASSERT0(wbmwe, o)
	`DEFASSERT0(wbmstb, o)

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
		  wbmack_i, addr_i, dat_i, we_i, nomem_i, hword_i, word_i,
		  dword_i, clk_i, reset_i, story_to, fault_to
		} <= 0;

		wait(~clk_i); wait(clk_i); #1;

		reset;
		assert_busy(0);

		// Given that we're not accessing memory,
		// the LSU must pass the address through to the
		// register writeback stage.

		story_to <= 12'h010;

		addr_i <= 64'h1122334455667788;
		dat_i <= 64'h7766554433221100;
		we_i <= 0;
		nomem_i <= 1;
		wait(~clk_i); wait(clk_i); #1;
		assert_dat(64'h1122334455667788);
		assert_rwe(1);

		story_to <= 12'h018;

		addr_i <= 64'h1122334455667788;
		dat_i <= 64'h7766554433221100;
		we_i <= 1;
		nomem_i <= 1;
		wait(~clk_i); wait(clk_i); #1;
		assert_dat(64'h1122334455667788);
		assert_rwe(1);

		// When idle, the LSU must disable writebacks to the register
		// file.

		story_to <= 12'h020;

		nomem_i <= 0;
		wait(~clk_i); wait(clk_i); #1;
		assert_rwe(0);

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

		hword_i <= 1;
		addr_i <= 64'h1122334455667788;
		dat_i <= 64'h7766554433221100;
		we_i <= 1;
		wbmdat_i <= 16'hDEAD;

		wait(~clk_i); wait(clk_i); #1;

		hword_i <= 0;

		assert_busy(1);
		assert_wbmadr(64'h1122334455667788);
		assert_wbmdat(16'h1100);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_rwe(0);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmstb(0);
		assert_rwe(0);
		
		wbmack_i <= 1;

		wait(~clk_i); wait(clk_i); #1;

		assert_rwe(0);
		assert_dat(64'h000000000000DEAD);

		wbmack_i <= 0;

		// When writing a full-word to memory,
		// the LSU must initiate and wait for the complete
		// Wishbone transaction to complete.  In this case,
		// the transfer consists of two cycles (one for lowest
		// 16-bits, one for highest 16-bits).

		story_to <= 12'h050;

		word_i <= 1;
		addr_i <= 64'h1122334455667788;
		dat_i <= 64'h7766554433221100;
		we_i <= 1;
		wbmdat_i <= 16'hDEAD;

		wait(~clk_i); wait(clk_i); #1;

		word_i <= 0;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778A);
		assert_wbmdat(16'h3322);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_rwe(0);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h1122334455667788);
		assert_wbmdat(16'h1100);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_rwe(0);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmstb(0);
		assert_rwe(0);
		
		wbmack_i <= 1;
		wbmdat_i <= 16'hDEAD;

		wait(~clk_i); wait(clk_i); #1;

		wbmdat_i <= 16'hBEEF;

		wait(~clk_i); wait(clk_i); #1;

		assert_rwe(0);
		assert_dat(64'h00000000DEADBEEF);

		wbmack_i <= 0;

		// When writing a double-word to memory,
		// the LSU must initiate and wait for the complete
		// Wishbone transaction to complete.  In this case,
		// the transfer consists of four cycles.

		story_to <= 12'h060;

		dword_i <= 1;
		addr_i <= 64'h1122334455667788;
		dat_i <= 64'h7766554433221100;
		we_i <= 1;

		wait(~clk_i); wait(clk_i); #1;

		dword_i <= 0;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778E);
		assert_wbmdat(16'h7766);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_rwe(0);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778C);
		assert_wbmdat(16'h5544);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_rwe(0);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h112233445566778A);
		assert_wbmdat(16'h3322);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_rwe(0);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmadr(64'h1122334455667788);
		assert_wbmdat(16'h1100);
		assert_wbmwe(1);
		assert_wbmstb(1);
		assert_rwe(0);

		wait(~clk_i); wait(clk_i); #1;

		assert_busy(1);
		assert_wbmstb(0);
		assert_rwe(0);
		
		wbmack_i <= 1;
		wbmdat_i <= 16'hDEAD;

		wait(~clk_i); wait(clk_i); #1;

		wbmdat_i <= 16'hBEEF;

		wait(~clk_i); wait(clk_i); #1;

		wbmdat_i <= 16'h0BAD;

		wait(~clk_i); wait(clk_i); #1;

		wbmdat_i <= 16'hC0DE;

		wait(~clk_i); wait(clk_i); #1;

		assert_rwe(0);
		assert_dat(64'hDEADBEEF0BADC0DE);

		wbmack_i <= 0;

		#100;
		$stop;
	end
endmodule

