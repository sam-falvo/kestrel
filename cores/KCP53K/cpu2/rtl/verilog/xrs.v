`timescale 1ns / 1ps

// This module implements the set of 31 64-bit wide registers for the CPU.
//
// Note that reading the register bank is _synchronous_, not asynchronous.
// This means you must present the desired register address prior to a clock
// edge, and the contents of the indicated register will appear after that
// edge.
//
// This module assumes you're targeting the iCE40HX series of FPGAs.

module xrs(
	input		clk_i,
	input	[4:0]	rd_i,
	input	[63:0]	rdat_i,
	input		rwe_i,

	output	[63:0]	rdata_o,
	output	[63:0]	rdatb_o,
	input	[4:0]	ra_i,
	input	[4:0]	rb_i
);
	wire	[63:0]	data_o, datb_o;

	assign rdata_o = (|ra_i) ? data_o : 0;
	assign rdatb_o = (|rb_i) ? datb_o : 0;

	ram64b port0(
		.wdata(rdat_i),
		.wen(rwe_i),
		.waddr(rd_i),
		.wclk(clk_i),
		.rdata(data_o),
		.raddr(ra_i),
		.rclk(clk_i)
	);

	ram64b port1(
		.wdata(rdat_i),
		.wen(rwe_i),
		.waddr(rd_i),
		.wclk(clk_i),
		.rdata(datb_o),
		.raddr(rb_i),
		.rclk(clk_i)
	);
endmodule

module ram16b (
	input	[15:0]	wdata,
	input		wen,
	input	[4:0]	waddr,
	input		wclk,
	output	[15:0]	rdata,
	input	[4:0]	raddr,
	input		rclk
);
	SB_RAM40_4K ram(
		.WDATA(wdata),
		.MASK({16{wen}}),
		.WADDR({3'b000, waddr}),
		.WE(wen),
		.WCLKE(1'b1),
		.WCLK(wclk),

		.RDATA(rdata),
		.RADDR({3'b000, raddr}),
		.RE(1'b1),
		.RCLKE(1'b1),
		.RCLK(rclk)
	);
endmodule

module ram64b (
	input	[63:0]	wdata,
	input		wen,
	input	[4:0]	waddr,
	input		wclk,
	output	[63:0]	rdata,
	input	[4:0]	raddr,
	input		rclk
);
	ram16b col0(
		.wdata(wdata[15:0]),
		.wen(wen),
		.waddr(waddr),
		.wclk(wclk),
		.rdata(rdata[15:0]),
		.raddr(raddr),
		.rclk(rclk)
	);

	ram16b col1(
		.wdata(wdata[31:16]),
		.wen(wen),
		.waddr(waddr),
		.wclk(wclk),
		.rdata(rdata[31:16]),
		.raddr(raddr),
		.rclk(rclk)
	);

	ram16b col2(
		.wdata(wdata[47:32]),
		.wen(wen),
		.waddr(waddr),
		.wclk(wclk),
		.rdata(rdata[47:32]),
		.raddr(raddr),
		.rclk(rclk)
	);

	ram16b col3(
		.wdata(wdata[63:48]),
		.wen(wen),
		.waddr(waddr),
		.wclk(wclk),
		.rdata(rdata[63:48]),
		.raddr(raddr),
		.rclk(rclk)
	);
endmodule

