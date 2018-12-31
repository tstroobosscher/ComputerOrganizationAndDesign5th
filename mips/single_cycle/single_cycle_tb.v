`timescale 1ns/1ns

/*
	Write random values to memory, then read them

	iverilog data_mem_64x32_tb.v ../data_mem_64x32.v
 */

module test_bench;
	reg rst_tb = 1;
	
	reg clk_tb = 1;

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

	initial begin
		for(i = 0; i < 64; i = i + 1) begin
			UUT.data_mem.memory[i] = i;
		end
	end

	// program
	initial begin

		// LW 
		//UUT.inst_mem.memory[0] = 32'b


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
