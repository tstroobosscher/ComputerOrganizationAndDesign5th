`timescale 1 ns / 100 ps

/*

	IEEE 754 floating point addition

	float[31] = sign bit
	float[30:23] = exponent against the bias
	float[22:0] = normalized fraction

	START
		get fl in 1 and 2, wait for start

	EXP_CMP
		if(exp1 != exp2)
			increment smaller, shift corresponding frac

	ADD
		add the fractionals (same as integers)

	NORM
		normalize the sum

	EXCE
		check for underflow / overflow

	ROUND
		round the fraction to the appropriate number of bits

	CHECK_NORM
		check for the normalized fraction, renormalize if necessary

	DONE
		wait for ack

 */

module float_add(clk, rst, start, ack, fl_in_1, fl_in_2, res);
 	input clk;
 	input rst;
 	input start;
 	input ack;
 	input [31:0] fl_in_1;
 	input [31:0] fl_in_2;
 	output reg [31:0] res;

localparam EXP_BIAS = 127;

reg [7:0] state;

// capture sign bit of each fl input
reg fl_in_1_neg;
reg fl_in_2_neg;

reg [7:0] fl_in_1_exp;
reg [7:0] fl_in_2_exp;

reg [23:0] fl_in_1_frac_norm;
reg [23:0] fl_in_2_frac_norm;

// are we concerned with biased numbers in this module? yes, write back must be biased
wire [7:0] fl_in_1_exp_biased = fl_in_1_exp - EXP_BIAS;
wire [7:0] fl_in_2_exp_biased = fl_in_2_exp - EXP_BIAS;

// write back the lower 23 bits of this array
// must be 25 bits to catch the overflow and renormalize
wire [24:0] fl_1_less_fl_2 = fl_in_1_frac_norm - fl_in_2_frac_norm;
wire [24:0] fl_2_less_fl_1 = fl_in_2_frac_norm - fl_in_1_frac_norm;
wire [24:0] fl_1_plus_fl_2 = fl_in_1_frac_norm + fl_in_2_frac_norm;

reg [24:0] add_res;

localparam START 		= 8'b00000001;
localparam EXP_CMP 		= 8'b00000010;
localparam ADD 			= 8'b00000100;
localparam NORM 		= 8'b00001000;
localparam EXCE 		= 8'b00010000;
localparam ROUND 		= 8'b00100000;
localparam CHECK_NORM	= 8'b01000000;
localparam DONE 		= 8'b10000000;

always @(posedge clk or posedge rst) 
	begin
		if (rst) 
			begin
				// go back to start
				state = START;

				// reset regs
				res <= 32'bX;
			end
		else 
			begin
				case(state)
					START 	:
						begin
							fl_in_1_neg <= fl_in_1[31];
							fl_in_2_neg <= fl_in_2[31];

							fl_in_1_exp <= fl_in_1[30:23];
							fl_in_2_exp <= fl_in_2[30:23];

							fl_in_1_frac_norm <= {1'b1, fl_in_1[22:0]};
							fl_in_2_frac_norm <= {1'b1, fl_in_2[22:0]};

							// next state logic
							if(start)
								state = EXP_CMP;
						end
					EXP_CMP	:
						begin

							// if exp1 smaller, imcrement and shift
							if(fl_in_1_exp < fl_in_2_exp)
								begin
									fl_in_1_exp <= fl_in_1_exp + 1'b1;
									fl_in_1_frac_norm <= fl_in_1_frac_norm >> 1'b1;
								end

							// if exp2 smaller, increment and shift
							else if(fl_in_1_exp > fl_in_2_exp)
								begin
									fl_in_2_exp <= fl_in_2_exp + 1'b1;
									fl_in_2_frac_norm <= fl_in_2_frac_norm >> 1'b1;
								end

							// next state logic
							if(fl_in_1_exp == fl_in_2_exp)
								state <= ADD;
						end
					ADD 	:
						begin
							// datapath
							// fl1_exp must equal fl2_exp

							// note, not writing to res yet, must renormalize and round

							// fl1 and fl2 negative, add and assert res sign
							if(	fl_in_1_neg && fl_in_2_neg)
								add_res <= fl_1_plus_fl_2;

							// fl1 negative and fl2 positive, assert add_res sign if |fl1| > |fl2|
							else if(fl_in_1_neg && !fl_in_2_neg)
								begin
									if(fl_in_1_frac_norm > fl_in_2_frac_norm)
									
										// fl1 is negative, fl2 is positive, fl1 is bigger in magnitude
										add_res <= fl_1_less_fl_2;

									else if(fl_in_1_frac_norm < fl_in_2_frac_norm)

										// fl1 is negative, fl2 is positive, fl2 is bigger in magnitude
										add_res <= fl_2_less_fl_1;

									else

										// |fl1| = |fl2|, signs are opposite
										add_res <= {32'b0};
								end

							// fl1 positive and fl2 negative, assert add_res sign if |fl2| > |fl1|
							else if(!fl_in_1_neg && fl_in_2_neg)
								begin
									if(fl_in_1_frac_norm > fl_in_2_frac_norm)
									
										// fl1 is positive, fl2 is negative, fl1 is bigger in magnitude
										add_res <= fl_1_less_fl_2;

									else if(fl_in_1_frac_norm < fl_in_2_frac_norm)

										// fl1 is positve, fl2 is negative, fl2 is bigger in magnitude
										add_res <= fl_2_less_fl_1;

									else

										// |fl1| = |fl2|, signs are opposite
										add_res <= {32'b0};
								end

							// fl1 and fl2 positive, deassert add_res sign
							else if(!fl_in_1_neg && !fl_in_2_neg)
								add_res <= {1'b0, fl_in_1_exp_biased, fl_1_plus_fl_2[22:0]};

							// next state logic
							state <= NORM;
						end
					NORM 	:
						begin
							// either the preprocessed data will be too high (bit 24 set) or data will be too low (bits 24 and 23 unset)
							// if too high, shift right, increment exp
							// if too low, shift left, decrement exp
							if(add_res[24])
								begin
									// shift right, keep the two exponents constant
									add_res <= add_res >> 1'b1;
									fl_in_1_exp <= fl_in_1_exp + 1'b1;
									fl_in_2_exp <= fl_in_2_exp + 1'b1;
								end
							else if(!add_res[24] && !add_res[23])
								begin
									// shift left, keep the two exponents constant
									add_res <= add_res << 1'b1;
									fl_in_1_exp <= fl_in_1_exp - 1'b1;
									fl_in_2_exp <= fl_in_2_exp - 1'b1;
								end


							if(!add res[24] && add_res[23])
								state <= EXCE;
						end
					EXCE 	:
						begin
							
						end
					ROUND 	:
						begin
							
						end
					CHECK_NORM :
						begin
							
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
