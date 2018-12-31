`timescale 1ns/1ns

/*
	synchronous read and write memory unit
 */

module data_mem_64x32(clk, addr, rd, wd, memwrite, memread);

	/*
	 *	reg addr must be long enough to address the entire memory
	 */

	input clk;
	input [5:0] addr;
	output wire [31:0] rd;
	input [31:0] wd;
	input memwrite;
	input memread;

	reg [31:0] reg_mem [0:63];

	integer i;

	initial begin
		for(i = 0; i < 64; i = i + 1)
			reg_mem[i] <= i;
	end


	// data is not available until the next clock cycle
	always @(posedge clk) begin
		if (memwrite == 1'b1)
			reg_mem[addr] <= wd;
	end

	assign rd = (memread == 1'b1) ? reg_mem[addr] : 32'bX;

endmodule
