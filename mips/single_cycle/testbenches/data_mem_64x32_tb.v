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
	

	reg [5:0] addr_tb;
	wire [31:0] rd_tb;
	reg [31:0] wd_tb;
	reg memwrite_tb;
	reg memread_tb;

	data_mem_64x32 UUT(
		.clk(clk_tb),
		.addr(addr_tb),
		.rd(rd_tb),
		.wd(wd_tb),
		.memwrite(memwrite_tb),
		.memread(memread_tb)
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

	/*
		evaluation  ($random)
	 */

	reg start;
	reg [31:0] test_mem [0:63];
	wire [31:0] expected_data;
	integer num_errors = 0;

	initial addr_tb = 0;
	initial memwrite_tb = 0;
	initial memread_tb = 0;
	initial wd_tb = 0;

	initial begin
		clk_tb = 0;

		// clock is starting high
		// issues coming from write synchronization
		// need to consider the whole clock cycle and the read/write 
		// characteristics of the module
		memwrite_tb = 1'b1;
		repeat(64) begin
			wd_tb = $random;
			test_mem[addr_tb] = wd_tb;
			#10;
			addr_tb = addr_tb + 1;
		end

		memwrite_tb = 1'b0;
		addr_tb = 0;
		wd_tb = 32'bX;

		memread_tb = 1'b1;
		repeat(64) @(posedge clk_tb) begin
			if(test_mem[addr_tb] != rd_tb) begin
				$display("ERROR: q value %0x does not match the expected value %0x at address %d", 
					rd_tb, test_mem[addr_tb], addr_tb);
				//num_errors = num_errors + 1;
			end
			addr_tb = addr_tb + 1;
		end

		$finish;
	end

endmodule
