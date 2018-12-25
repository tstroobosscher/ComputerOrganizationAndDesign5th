`timescale 1 ns / 100 ps

/*
	register file implemented based on the description 
	provided in Computer Organization and Design, 5th
*/

module register_file(clk, ra1, ra2, wa, wd, rd1, rd2, regwrite)
	input [4:0] ra1;
	input [4:0] ra2;
	input [4:0] wa;
	input [31:0] wd;
	output reg rd1;
	output reg rd2;
	input regwrite;

	// 32 element array of 32 bit wide registers
	reg [31:0] reg_file [0:31];

	assign rd1 = reg_file[ra1];
	assign rd2 = reg_file[ra2];

	always @(posedge clk) 
	begin
		if(regwrite)
			reg_file[wa] <= wd;	
	end

endmodule
