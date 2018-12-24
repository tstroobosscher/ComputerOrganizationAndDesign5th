`timescale 1 ns / 100 ps

/*

	Mutltiply 2 32 bit numbers.

	Multiplicand X Multiplier = Product

	4 states:
		START/init 	// wait for start signal
				   		if start, init i reg, multplicand, multiplier
		TEST   		// test multiplier0, inc i,
						if multiplier0 add multiplicand to product
			   		// shift multiplicand by one
		REPEAT 		// check i < 32 
		DONE   		// wait for ack

	Control Signals:
		Multiplier0
		Start
		Ack

 */

module mult1(clk, rst, start, ack, multiplicand, multiplier, product);
 	input clk;
 	input rst;
 	input start;
 	input ack;
 	input [31:0] multiplicand;
 	input [31:0] multiplier;
 	output reg [63:0] product;

reg [5:0] i;
reg [31:0] multiplicand_reg;
reg [31:0] multiplier_reg;
reg [3:0] state;

wire multiplier0 = multiplier_reg[0];

localparam START 	= 4'b0001;
localparam TEST 	= 4'b0010;
localparam REPEAT 	= 4'b0100;
localparam DONE 	= 4'b1000;

always @(posedge clk or posedge rst) 
	begin
		if (rst) 
			begin // reset
				state = START; // go back to start, reset regs
				product 			= 64'bX;
				i 					= 6'bX;
				multiplicand_reg 	= 32'bX;
				multiplier_reg 		= 32'bX;
			end
		else 
			begin
				case(state)
					START 	:
						begin
							i <= 0;
							product <= 0;
							multiplier_reg <= multiplier;
							multiplicand_reg <= multiplicand;

							if(start)
								state = TEST;
							else
								state = START;
						end
					TEST 	:
						begin
							i <= i + 1;

							if (multiplier0) 
									product <= product + multiplicand_reg;

							multiplicand_reg <= multiplicand_reg << 1;
							multiplier_reg <= multiplier_reg >> 1;

							state <= REPEAT;
						end
					REPEAT 	:
						begin
							if(i <= 32)
								state <= TEST;
							else
								state <= DONE;
						end
					DONE 	:
						begin
							if(ack)
								state <= START;
							else
								state <= DONE;
						end
				endcase
			end
	end

endmodule
