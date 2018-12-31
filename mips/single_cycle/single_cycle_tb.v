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


	LW $(RT) OFFSET+$(RS)
	SW $(RT) OFFSET+$(RS)


	Note: data mem and reg file are loaded with natural values initially
			inst mem is uninitialized
 */

module test_bench;
	reg rst_tb = 0;
	
	reg clk_tb = 0;

	// 100Mhz clock
	always #5 clk_tb = ~clk_tb;

	///////////////////////////////////////////////////////////////////////////
	//
	// 
	//	Instantiations
	//
	//
	///////////////////////////////////////////////////////////////////////////

	single_cycle_mips_32 UUT(
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

	// function field NOT ALUOP
	localparam AND 	= 6'b100100;
	localparam OR 	= 6'b100101;
	localparam ADD 	= 6'b100000;
	localparam SUB 	= 6'b100010;
	localparam SLT 	= 6'b101010;
	localparam NOR 	= 6'b100111;

	// program
	initial begin

		// LW
		UUT.inst_mem.memory[0] = {LOAD_WORD, 5'd31, 5'd0, 16'd0};
		// LW
		UUT.inst_mem.memory[1] = {LOAD_WORD, 5'd31, 5'd1, 16'd0};
		// ADD
		UUT.inst_mem.memory[2] = {R_TYPE, 5'd0, 5'd1, 5'd2, 5'b0, ADD};

	end

	///////////////////////////////////////////////////////////////////////////
	//
	// 
	//	Test Routine
	//
	//
	///////////////////////////////////////////////////////////////////////////

	initial begin
		repeat(1000) @(posedge clk_tb);
		$finish;
	end

endmodule
