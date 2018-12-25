`timescale 1 ns / 100 ps

/*

*/

module inst_mem_64x32(ra, rd)
	input [4:0] ra;
	output [31:0] rd;
	reg [31:0] reg_mem [63:0];

	assign rd = reg_mem[ra];
endmodule
