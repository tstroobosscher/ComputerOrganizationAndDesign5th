`timescale 1ns/1ns

/*
	holds preloaded program, is addressed by the program counter
*/

module inst_mem_64x32(ra, rd);
	input [5:0] ra;
	output [31:0] rd;

	reg [31:0] memory [0:63];

	assign rd = memory[ra];

	integer i;

endmodule
