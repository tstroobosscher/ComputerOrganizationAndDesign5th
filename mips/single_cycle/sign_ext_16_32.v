`timescale 1 ns / 100 ps

/*
	16 to 32 bit sign extender
*/

module sign_ext_16_32(d, q)
	input [15:0] d;
	output [31:0] q;

	assign q = {16{d[15]}, d};

endmodule
