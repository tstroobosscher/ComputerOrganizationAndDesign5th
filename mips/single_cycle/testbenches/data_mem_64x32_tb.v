`timescale 1ns/1ns

/*
	Write random values to memory, then read them
 */

module test_bench;

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
	

	reg [6:0] addr_tb;
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
		repeat(1000) @(posedge clk_tb);
		$finish;
	end

	initial begin
		$dumpfile("simulation.vcd");
		$dumpvars;
	end

	/*
		evaluation  ($random)

		state machine:
			Start: initialize the registers, wait for start signal 
			Write: write 64 random values to the memory, and temp them 
			Read: read back those stored 64 values into temp2
			Result: compare the temp1 and temp2
	 */

	reg [3:0] state;
	reg start;
	reg [7:0] i;
	reg [31:0] test_mem [63:0];

	localparam START = 0001;
	localparam WRITE = 0010;
	localparam READ = 0100;
	localparam RESULT = 1000;

	initial state = START;
	initial start = 1'b0;

	always @(posedge clk_tb) begin
		case(state)
			START 	:
				begin

					// RTL
					if(~start) begin
						addr_tb <= 32'b0;
						wd_tb <= 32'b0;
						memwrite_tb <= 1'b0;
						memread_tb <= 1'b0;
						i <= 0;
					end
					else if(start) begin
						test_mem[addr_tb] <= wd_tb <= $random;
						memwrite_tb <= 1'b1;
					end

					// NSL
					if(start)
						state <= WRITE;
				end
			WRITE 	:
				begin

					// RTL
					if(addr_tb < 63) begin
						addr_tb <= addr_tb + 1;
						test_mem[addr_tb] <= wd_tb <= $random;
						memwrite_tb <= 1'b1;
					end
					else if(addr_tb >= 63) begin
						memwrite_tb <= 1'b0;
					end

					// NSL 
					if(addr_tb == 63) begin
						state <= READ;
						addr_tb <= 0;
					end
				end
			READ 	:
				begin
					
				end


		endcase
	end

	integer num_checks = 0;
	integer num_errors = 0;
	always @(posedge clk_tb) begin
		num_checks = num_checks + 1;
		if(expected_q != q_tb) begin
			$display("ERROR: q value %0x does not match the expected value %0x at time %0fns", 
				q_tb, expected_q, $realtime);
			num_errors = num_errors + 1;
		end
	end

endmodule
