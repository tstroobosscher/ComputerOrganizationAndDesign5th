`timescale 1ns/1ns

/*
	Write random values to register file, then read them

	iverilog inst_mem_64x32_tb.v ../inst_mem_64x32.v
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
	
	reg [5:0] ra_tb;
	wire [31:0] rd_tb;

	inst_mem_64x32 UUT(
		.ra(ra_tb),
		.rd(rd_tb)
		);

	reg [31:0] test_mem [0:31];

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

	///////////////////////////////////////////////////////////////////////////
	//
	// 
	//	Test Routine
	//
	//
	///////////////////////////////////////////////////////////////////////////

	initial begin
		for(i = 0; i < 63; i = i + 1) begin
			UUT.memory[i] = $random;
			test_mem[i] = UUT.memory[i];
		end

		for(ra_tb = 0; ra_tb < 63; ra_tb = ra_tb + 1) begin
			if(test_mem[ra_tb] != rd_tb) begin
				$display("ERROR: q value %0x does not match the expected value %0x at address %d", 
					rd_tb, test_mem[ra_tb], ra_tb);
			end
		end

		$finish;
	end

endmodule
