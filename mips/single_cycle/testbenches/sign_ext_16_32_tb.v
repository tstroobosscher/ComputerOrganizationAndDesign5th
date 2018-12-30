`timescale 1ns/1ns

/*
	iverilog sign_ext_16_32_tb.v ../sign_ext_16_32.v
 */

module test_bench;

	reg clk_tb = 1;
	// 100Mhz clock
	always #5 clk_tb = ~clk_tb;

	reg [15:0] d_tb;
	wire [31:0] q_tb;

	sign_ext_16_32 UUT(
			.d(d_tb),
			.q(q_tb)
		);

	always @(posedge clk_tb) d_tb <= $random;

	initial begin
		repeat(1000) @(posedge clk_tb);
		$finish;
	end

	initial begin
		$dumpfile("simulation.vcd");
		$dumpvars;
	end

	/*
		evaluation
	 */

	wire [31:0] expected_q;
	assign expected_q = { {16{d_tb[15]}}, d_tb};

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
