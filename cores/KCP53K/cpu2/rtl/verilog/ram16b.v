`default_nettype none
`timescale 1ns / 1ps

module ram16b(
	input	[15:0]	wdata,
	input		wen,
	input	[4:0]	waddr,
	input		wclk,
	output	[15:0]	rdata,
	input	[4:0]	raddr,
	input		rclk
);
`ifdef synthesis
	ram16b_ice40 ram(
		.wdata(wdata),
		.wen(wen),
		.waddr(waddr),
		.wclk(wclk),
		.rdata(rdata),
		.raddr(raddr),
		.rclk(rclk)
	);
`endif
`ifndef synthesis
	ram16b_sim ram(
		.wdata(wdata),
		.wen(wen),
		.waddr(waddr),
		.wclk(wclk),
		.rdata(rdata),
		.raddr(raddr),
		.rclk(rclk)
	);
`endif
endmodule

`ifdef synthesis
module ram16b_ice40 (
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
`endif

`ifndef synthesis
module ram16b_sim (
	input	[15:0]	wdata,
	input		wen,
	input	[4:0]	waddr,
	input		wclk,
	output	[15:0]	rdata,
	input	[4:0]	raddr,
	input		rclk
);
	reg [15:0] memory[0:31];
	reg [4:0] raddr_r;

	always @(posedge wclk) begin
		if(wen) begin
			memory[waddr] <= wdata;
		end
	end

	always @(posedge rclk) begin
		raddr_r <= raddr;
	end

	assign rdata = memory[raddr_r];
endmodule
`endif

