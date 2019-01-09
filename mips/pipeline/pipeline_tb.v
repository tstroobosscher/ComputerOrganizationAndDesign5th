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

	integer expected_value;

	// program
	initial begin

		rst_tb = 1'b1;

		// wait 2 clocks
		#(2*CLK_PERIOD);
		rst_tb = 1'b0;

		//	let each instruction go through 5 stages each and test the result

		// Dont forget R-Type shamt! 5'b0
		
		///////////////////////////////////////////////////////////////////////
		//
		//	LW
		//
		///////////////////////////////////////////////////////////////////////

		$display("test_bench: running test: LW");
		UUT.inst_mem.memory[0] = {LOAD_WORD, 5'd31, 5'd0, 16'd0};

		#(5*CLK_PERIOD);

		// need to wait a little after the next clock cycle to read accurately
		// delta T!
		#CLK_PERIOD;
		if(UUT.reg_file.memory[0] != expected_value)
			$display("test_bench: LW failure");
		else
			$display("test_bench: LW succuess");

		///////////////////////////////////////////////////////////////////////
		//
		//	SW
		//
		///////////////////////////////////////////////////////////////////////

		rst_tb = 1'b1;

		// wait 2 clocks
		#(2*CLK_PERIOD);
		rst_tb = 1'b0;

		$display("test_bench: running test: SW");
		UUT.inst_mem.memory[0] = {STORE_WORD, 5'd0, 5'd3, 16'd0};

		expected_value = UUT.reg_file.memory[3];

		#(5*CLK_PERIOD);

		#CLK_PERIOD;
		if(UUT.data_mem.memory[0] != expected_value)
			$display("test_bench: SW failure");
		else
			$display("test_bench: SW success");

		///////////////////////////////////////////////////////////////////////
		//
		//	ADD
		//
		///////////////////////////////////////////////////////////////////////

		rst_tb = 1'b1;

		// wait 2 clocks
		#(2*CLK_PERIOD);
		rst_tb = 1'b0;

		$display("test_bench: running test: ADD");
		UUT.inst_mem.memory[0] = {R_TYPE, 5'd1, 5'd2, 5'd0, 5'b0, ADD};

		expected_value = UUT.reg_file.memory[1] + UUT.reg_file.memory[2];

		#(5*CLK_PERIOD);

		#CLK_PERIOD;
		if(UUT.reg_file.memory[0] != expected_value)
			$display("test_bench: ADD failure");
		else
			$display("test_bench: ADD success");

		///////////////////////////////////////////////////////////////////////
		//
		//	SUB
		//
		///////////////////////////////////////////////////////////////////////

		rst_tb = 1'b1;

		// wait 2 clocks
		#(2*CLK_PERIOD);
		rst_tb = 1'b0;

		$display("test_bench: running test: SUB");
		UUT.inst_mem.memory[0] = {R_TYPE, 5'd2, 5'd1, 5'd0, 5'b0, SUB};

		expected_value = UUT.reg_file.memory[2] - UUT.reg_file.memory[1];

		#(5*CLK_PERIOD);

		#CLK_PERIOD;
		if(UUT.reg_file.memory[0] != expected_value)
			$display("test_bench: SUB failure");
		else
			$display("test_bench: SUB success");

		///////////////////////////////////////////////////////////////////////
		//
		//	AND
		//
		///////////////////////////////////////////////////////////////////////

		rst_tb = 1'b1;

		// wait 2 clocks
		#(2*CLK_PERIOD);
		rst_tb = 1'b0;

		$display("test_bench: running test: AND");
		UUT.inst_mem.memory[0] = {R_TYPE, 5'd2, 5'd1, 5'd0, 5'b0, AND};

		expected_value = UUT.reg_file.memory[2] & UUT.reg_file.memory[1];

		#(5*CLK_PERIOD);

		#CLK_PERIOD;
		if(UUT.reg_file.memory[0] != expected_value)
			$display("test_bench: AND failure");
		else
			$display("test_bench: AND success");

		///////////////////////////////////////////////////////////////////////
		//
		//	OR
		//
		///////////////////////////////////////////////////////////////////////

		rst_tb = 1'b1;

		// wait 2 clocks
		#(2*CLK_PERIOD);
		rst_tb = 1'b0;

		$display("test_bench: running test: OR");
		UUT.inst_mem.memory[0] = {R_TYPE, 5'd2, 5'd1, 5'd0, 5'b0, OR};

		expected_value = UUT.reg_file.memory[2] | UUT.reg_file.memory[1];

		#(5*CLK_PERIOD);

		#CLK_PERIOD;
		if(UUT.reg_file.memory[0] != expected_value)
			$display("test_bench: OR failure");
		else
			$display("test_bench: OR success");

		///////////////////////////////////////////////////////////////////////
		//
		//	NOR
		//
		///////////////////////////////////////////////////////////////////////

		rst_tb = 1'b1;

		// wait 2 clocks
		#(2*CLK_PERIOD);
		rst_tb = 1'b0;

		$display("test_bench: running test: NOR");
		UUT.inst_mem.memory[0] = {R_TYPE, 5'd2, 5'd1, 5'd0, 5'b0, NOR};

		expected_value = ~(UUT.reg_file.memory[2] | UUT.reg_file.memory[1]);

		#(5*CLK_PERIOD);

		#CLK_PERIOD;
		if(UUT.reg_file.memory[0] != expected_value)
			$display("test_bench: NOR failure");
		else
			$display("test_bench: NOR success");

		///////////////////////////////////////////////////////////////////////
		//
		//	SLT
		//
		///////////////////////////////////////////////////////////////////////

		rst_tb = 1'b1;

		// wait 2 clocks
		#(2*CLK_PERIOD);
		rst_tb = 1'b0;

		$display("test_bench: running test: SLT");
		UUT.inst_mem.memory[0] = {R_TYPE, 5'd1, 5'd2, 5'd0, 5'b0, SLT};

		expected_value = 32'b1;

		#(5*CLK_PERIOD);

		#CLK_PERIOD;
		if(UUT.reg_file.memory[0] != expected_value)
			$display("test_bench: SLT failure");
		else
			$display("test_bench: SLT success");

		///////////////////////////////////////////////////////////////////////
		//
		//	BEQ
		//
		///////////////////////////////////////////////////////////////////////

		rst_tb = 1'b1;

		// wait 2 clocks
		#(2*CLK_PERIOD);
		rst_tb = 1'b0;

		$display("test_bench: running test: BEQ: taken");
		UUT.inst_mem.memory[0] = {BRANCH_EQ, 5'd1, 5'd1, 16'd5};

		expected_value = UUT.program_counter + 4 + 5*4;

		#(2*CLK_PERIOD);

		#CLK_PERIOD;
		if(UUT.program_counter != expected_value)
			$display("test_bench: BEQ: taken failure");
		else
			$display("test_bench: BEQ: taken success");

		rst_tb = 1'b1;

		// wait 2 clocks
		#(2*CLK_PERIOD);
		rst_tb = 1'b0;

		$display("test_bench: running test: BEQ: not taken");
		UUT.inst_mem.memory[0] = {BRANCH_EQ, 5'd1, 5'd2, -16'd29};

		expected_value = UUT.program_counter + 4;

		#(2*CLK_PERIOD);

		#CLK_PERIOD;
		if(UUT.program_counter != expected_value)
			$display("test_bench: BEQ: not taken failure");
		else
			$display("test_bench: BEQ: not taken success");


		// reserve margin at the end of test
		#(10*CLK_PERIOD);
		$finish;
	end

endmodule
