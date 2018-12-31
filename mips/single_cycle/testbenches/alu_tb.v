`timescale 1ns/1ns

/*
	Write random values to memory, then read them
 */

module test_bench;

	reg clk_tb;

	// 100Mhz clock
	always #5 clk_tb = ~clk_tb;

	///////////////////////////////////////////////////////////////////////////
	//
	// 
	//	Instantiations
	//
	//
	///////////////////////////////////////////////////////////////////////////

	reg [3:0] alucont_tb;
	reg [31:0] rd1_tb;
	reg [31:0] rd2_tb;
	wire [31:0] res_tb;
	wire zero_tb;

	alu UUT(
		.alucont(alucont_tb),
		.rd1(rd1_tb),
		.rd2(rd2_tb),
		.res(res_tb),
		.zero(zero_tb)
		);

	reg [31:0] test_data_1;
	reg [31:0] test_data_2;
	reg [31:0] expected_data;

	///////////////////////////////////////////////////////////////////////////
	//
	// 
	//	Initializations
	//
	//
	///////////////////////////////////////////////////////////////////////////

	localparam AND 	= 4'b0000;
	localparam OR 	= 4'b0001;
	localparam ADD 	= 4'b0010;
	localparam SUB 	= 4'b0110;
	localparam SLT 	= 4'b0111;
	localparam NOR 	= 4'b1100;

	initial begin
		$dumpfile("simulation.vcd");
		$dumpvars(0, test_bench);
	end

	///////////////////////////////////////////////////////////////////////////
	//
	// 
	//	Test Routine
	//
	//
	///////////////////////////////////////////////////////////////////////////

	initial begin

		alucont_tb = AND;
		test_data_1 = $random;
		test_data_2 = $random;
		rd1_tb = test_data_1;
		rd2_tb = test_data_2;

		expected_data = test_data_1 & test_data_2;

		if((expected_data != res_tb) && (zero_tb == |res_tb))
			$display("ERROR: q value %0x does not match the expected value %0x at test: AND", 
					res_tb, expected_data);

		alucont_tb = OR;
		test_data_1 = $random;
		test_data_2 = $random;
		rd1_tb = test_data_1;
		rd2_tb = test_data_2;

		expected_data = test_data_1 | test_data_2;

		if((expected_data != res_tb) && (zero_tb == |res_tb))
			$display("ERROR: q value %0x does not match the expected value %0x at test: OR", 
					res_tb, expected_data);

		alucont_tb = ADD;
		test_data_1 = $random;
		test_data_2 = $random;
		rd1_tb = test_data_1;
		rd2_tb = test_data_2;

		expected_data = test_data_1 + test_data_2;

		if((expected_data != res_tb) && (zero_tb == |res_tb))
			$display("ERROR: q value %0x does not match the expected value %0x at test: OR", 
					res_tb, expected_data);

		alucont_tb = SUB;
		test_data_1 = $random;
		test_data_2 = $random;
		rd1_tb = test_data_1;
		rd2_tb = test_data_2;

		expected_data = test_data_1 - test_data_2;

		if((expected_data != res_tb) && (zero_tb == |res_tb))
			$display("ERROR: q value %0x does not match the expected value %0x at test: OR", 
					res_tb, expected_data);

		alucont_tb = SLT;
		test_data_1 = $random;
		test_data_2 = $random;
		rd1_tb = test_data_1;
		rd2_tb = test_data_2;

		expected_data = (test_data_1 < test_data_2) ? 1 : 0;

		if((expected_data != res_tb) && (zero_tb == |res_tb))
			$display("ERROR: q value %0x does not match the expected value %0x at test: OR", 
					res_tb, expected_data);

		alucont_tb = ADD;
		test_data_1 = $random;
		test_data_2 = $random;
		rd1_tb = test_data_1;
		rd2_tb = test_data_2;

		expected_data = ~(test_data_1 | test_data_2);

		if((expected_data != res_tb) && (zero_tb == |res_tb))
			$display("ERROR: q value %0x does not match the expected value %0x at test: OR", 
					res_tb, expected_data);

		$finish;
	end

endmodule
