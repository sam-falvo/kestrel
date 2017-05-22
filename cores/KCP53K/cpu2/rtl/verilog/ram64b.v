`default_nettype none
`timescale 1ns / 1ps

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

