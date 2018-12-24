`timescale 1 ns / 100 ps

/*

	Mutltiply 2 32 bit numbers.

	Dividend / Divisor = Quotient

	4 states:
		START/INIT 	// wait for start signal
				   		if start
				   		quotient <= 0
				   		remainder <= dividend;
				   		divisor_reg[63:0] <= {divisor, 32'b0}
		SUB
						remainder <= dividend - divisor
		TEST_REM   	// test remainder, inc i,
						if remainder >= 0 shift quotient left, make new lsb a 1;
						if remainder < 0, remainder <= remainder + divisor
							shift quotient to the left, filling in with a 0 in the lsb
			   		// shift divisor to the right by one
		REPEAT 		// check i < 33
		DONE   		// wait for ack

	Control Signals:
		remainder
		Start
		Ack

 */

module div(clk, rst, start, ack, dividend, divisor, quotient, remainder);
 	input clk;
 	input rst;
 	input start;
 	input ack;
 	input [63:0] dividend;
 	input [31:0] divisor;
 	output reg [31:0] quotient;
 	output reg signed [63:0] remainder;

reg [5:0] i;
reg [63:0] divisor_reg;
reg [4:0] state;

localparam START 	= 5'b00001;
localparam SUB 		= 5'b00010;
localparam TEST 	= 5'b00100;
localparam REPEAT 	= 5'b01000;
localparam DONE 	= 5'b10000;

always @(posedge clk or posedge rst) 
	begin
		if (rst) 
			begin // reset
				state = START; // go back to start, reset regs
				i 					= 6'bX;
				divisor_reg			= 64'bX;
				quotient 			= 32'bX;
				remainder 			= 64'bX;
			end
		else 
			begin
				case(state)
					START 	:
						begin

							// datapath
							i <= 0;
							quotient <= 0;
							divisor_reg <= {divisor, 32'b0};
							remainder <= dividend;
							
							// Next state logic
							if(start)
								state = SUB;
						end
					SUB 	:
						begin
							remainder <= remainder - divisor_reg;

							state <= TEST;
						end
					TEST 	:
						begin
							i <= i + 1;

							if (remainder >= 0) 
								begin
									quotient <= {quotient[30:0], 1'b1};
								end
							else
								begin
									remainder <= remainder + divisor_reg;
									quotient <= {quotient[30:0], 1'b0};
								end

							divisor_reg <= divisor_reg >> 1;

							state <= REPEAT;
						end
					REPEAT 	:
						begin
							if(i <= 32)
								state <= SUB;
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
