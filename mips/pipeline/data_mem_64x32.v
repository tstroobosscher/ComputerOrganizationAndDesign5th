`timescale 1ns/1ns

/*
	synchronous read and write memory unit
 */

module data_mem_64x32(clk, rst, addr, rd, wd, memwrite, memread);

	/*
	 *	reg addr must be long enough to address the entire memory
	 */

	input clk;
	input rst;
	input [5:0] addr;
	output wire [31:0] rd;
	input [31:0] wd;
	input memwrite;
	input memread;

	reg [31:0] memory [0:63];

	integer i;

	initial begin
		for(i = 0; i < 64; i = i + 1)
			memory[i] <= i;
	end


	// data is not available until the next clock cycle
	always @(posedge clk or posedge rst) begin
		if(rst)
			for(i = 0; i < 64; i = i + 1)
				memory[i] <= i;

		else if (memwrite)
			memory[addr] <= wd;
	end

	assign rd = (memread == 1'b1) ? memory[addr] : 32'bX;

endmodule
