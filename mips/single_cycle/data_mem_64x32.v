`timescale 1 ns / 100 ps

/*
	synchronous read and write memory unit
 */

module data_mem_64x32(clk, addr, rd, wd, memwrite, memread)

	/*
	 *	reg addr must be long enough to address the entire memory
	 */

	input clk;
	input [6:0] addr;
	output [31:0] rd;
	input [31:0] wd;
	input memwrite;
	input memread;

	reg [31:0] reg_mem [63:0];

	always @(posedge clk) begin
		if (memwrite) begin
			reg_mem[addr] <= wd;
		end

		if (memread) begin
			rd = reg_mem[addr];
		end
	end

endmodule
