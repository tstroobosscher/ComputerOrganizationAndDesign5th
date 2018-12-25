`timescale 1 ns / 100 ps

/*
	32 bit mips alu
	no cout?
	signed/unsigned ops?
 */

module alu(alucont, rd1, rd2, res, zero)
	input [3:0] alucont;
	input [31:0] rd1;
	input [31:0] rd2;

	output [31:0] res
	output zero;

	localparam AND 	= 4'b0000;
	localparam OR 	= 4'b0001;
	localparam ADD 	= 4'b0010;
	localparam SUB 	= 4'b0110;
	localparam SLT 	= 4'b0111;
	localparam NOR 	= 4'b1100;

	always @(*) begin
		case(alucont)
			AND		: begin
				res = rd1 & rd2;
			end
			OR 		: begin
				res = rd1 | rd2;
			end
			ADD 	: begin
				res = rd1 + rd2;
			end
			SUB 	: begin
				res = rd1 - rd2;
			end
			SLT 	: begin
				res = rd1 < rd2 : 1 ? 0;
			end
			NOR 	: begin
				res = ~(rd1 & rd2);
			end
		endcase
	end

endmodule
