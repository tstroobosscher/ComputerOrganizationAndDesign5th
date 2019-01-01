`timescale 1ns/1ns

/*
	register file implemented based on the description 
	provided in Computer Organization and Design, 5th
*/

module register_file(clk, ra1, ra2, wa, wd, rd1, rd2, regwrite);
	input clk;
	input [4:0] ra1;
	input [4:0] ra2;
	input [4:0] wa;
	input [31:0] wd;
	output reg [31:0] rd1;
	output reg [31:0] rd2;
	input regwrite;

	// 32 element array of 32 bit wide registers
	reg [31:0] memory [0:31];

	integer i;

	initial begin
		for(i = 0; i < 32; i = i + 1)
			memory[i] = i;
	end

	always @(*) begin
		rd1 <= memory[ra1];
		rd2 <= memory[ra2];
	end

	always @(posedge clk) begin
		if(regwrite)
			memory[wa] <= wd;	
	end

endmodule
