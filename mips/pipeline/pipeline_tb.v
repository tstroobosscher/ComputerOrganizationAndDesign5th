`timescale 1ns/1ns

/*
	R-Type
	    OP      RS      RT      RD    SHAMT  FUNCT
	|-------|-------|-------|-------|------|------|
	  31:26   25:21   20:16   15:11   10:6   5:0

	LW/SW
	    OP      RS      RT         ADDRESS
	|-------|-------|-------|---------------------|
	  31:26   25:21   20:16         15:0
	
	Branch
        OP      RS      RT         ADDRESS
	|-------|-------|-------|---------------------|
	  31:26   25:21   20:16         15:0

	Jump
        OP               ADDRESS
	|-------|------------------------------------|
	  31:26               25:0


	LW $(RT) OFFSET+$(RS)
	SW $(RT) OFFSET+$(RS)


	Note: data mem and reg file are loaded with natural values initially
			inst mem is uninitialized
 */

module test_bench#(
	parameter CLK_PERIOD = 10 //ns
	);

	reg rst_tb = 1;
	
	reg clk_tb = 1;

	// 100Mhz clock
	always #(CLK_PERIOD/2) clk_tb = ~clk_tb;

	///////////////////////////////////////////////////////////////////////////
	//
	// 
	//	Instantiations
	//
	//
	///////////////////////////////////////////////////////////////////////////

	five_stage_pipeline_mips_32 UUT(
		.clk(clk_tb),
		.rst(rst_tb)
		);

	///////////////////////////////////////////////////////////////////////////
	//
	// 
	//	Initializations
	//
	//
	///////////////////////////////////////////////////////////////////////////

	initial begin
		$dumpfile("simulation.vcd");
		$dumpvars(0, test_bench);
	end

	integer i;

	// load data memory with values
	initial begin
		for(i = 0; i < 64; i = i + 1) begin
			UUT.data_mem.memory[i] = i;
		end
	end

	localparam R_TYPE 		= 6'b000000;
	localparam LOAD_WORD 	= 6'b100011;
	localparam STORE_WORD 	= 6'b101011;
	localparam BRANCH_EQ	= 6'b000100;
	localparam JUMP 		= 6'b000010;

	// function field NOT ALUOP
	localparam AND 			= 6'b100100;
	localparam OR 			= 6'b100101;
	localparam ADD 			= 6'b100000;
	localparam SUB 			= 6'b100010;
	localparam SLT 			= 6'b101010;
	localparam NOR 			= 6'b100111;

	///////////////////////////////////////////////////////////////////////////
	//
	// 
	//	Test Routine
	//
	//
	///////////////////////////////////////////////////////////////////////////

	task dump_data;
		integer i;
		for(i = 0; i < 32; i = i + 1) begin
			$display("UUT address: %d, reg_file data: %d, data_mem data: %d", 
				i, UUT.reg_file.memory[i], UUT.data_mem.memory[i]);
		end
	endtask

	// program
	initial begin

		// wait 2 clocks
		#(2*CLK_PERIOD);
		rst_tb = 1'b0;

		// Dont forget R-Type shamt! 5'b0
		// ADD

		UUT.inst_mem.memory[0] = {LOAD_WORD, 5'd31, 5'd1, 16'd0};
		UUT.inst_mem.memory[1] = {LOAD_WORD, 5'd31, 5'd2, 16'd0};
		UUT.inst_mem.memory[2] = {R_TYPE, 5'd1, 5'd2, 5'd3, 5'b0, ADD};
		UUT.inst_mem.memory[3] = {STORE_WORD, 5'd0, 5'd3, 16'd0};

		// reserve margin at the end of test
		#(10*CLK_PERIOD);
		$finish;
	end

endmodule
