`timescale 1ns/1ns

/*
	Write random values to register file, then read them

	iverilog register_file_tb.v ../register_file.v
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
	
	reg [4:0] ra1_tb;
	reg [4:0] ra2_tb;
	reg [4:0] wa_tb;
	reg [31:0] wd_tb;
	wire [31:0] rd1_tb;
	wire [31:0] rd2_tb;
	reg regwrite_tb;

	register_file UUT(
		.clk(clk_tb),
		.ra1(ra1_tb),
		.ra2(ra2_tb),
		.wa(wa_tb),
		.wd(wd_tb),
		.rd1(rd1_tb),
		.rd2(rd2_tb),
		.regwrite(regwrite_tb)
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

	reg [31:0] test_mem [0:31];
	wire [31:0] expected_data;
	integer num_errors = 0;

	initial wa_tb = 0;
	initial clk_tb = 0;
	initial ra1_tb = 0;
	initial ra2_tb = 1;

	///////////////////////////////////////////////////////////////////////////
	//
	// 
	//	Test Routine
	//
	//
	///////////////////////////////////////////////////////////////////////////

	initial begin

		// clock is starting high
		// issues coming from write synchronization
		// need to consider the whole clock cycle and the read/write 
		// characteristics of the module
		regwrite_tb = 1'b1;
		repeat(32) begin
			wd_tb = $random;
			test_mem[wa_tb] = wd_tb;
			#10;
			wa_tb = wa_tb + 1;
		end

		regwrite_tb = 1'b0;
		wa_tb = 0;
		wd_tb = 32'bX;

		repeat(16) @(posedge clk_tb) begin
			if(rd1_tb != test_mem[ra1_tb]) begin
				$display("ERROR: q value %0x does not match the expected value %0x at address %d", 
					rd1_tb, test_mem[ra1_tb], ra1_tb);
				num_errors = num_errors + 1;
			end
			if(rd2_tb != test_mem[ra2_tb]) begin
				$display("ERROR: q value %0x does not match the expected value %0x at address %d", 
					rd2_tb, test_mem[ra2_tb], ra2_tb);
				num_errors = num_errors + 1;
			end
			#10;
			ra1_tb = ra1_tb + 2;
			ra2_tb = ra2_tb + 2;
		end

		$finish;
	end

endmodule
