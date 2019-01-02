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

		// SUB
		UUT.inst_mem.memory[4] = {LOAD_WORD, 5'd31, 5'd1, 16'd0};
		UUT.inst_mem.memory[5] = {LOAD_WORD, 5'd30, 5'd2, 16'd0};
		UUT.inst_mem.memory[6] = {R_TYPE, 5'd1, 5'd2, 5'd3, 5'b0, SUB};
		UUT.inst_mem.memory[7] = {STORE_WORD, 5'd0, 5'd3, 16'd0};

		// OR
		UUT.inst_mem.memory[8] = {LOAD_WORD, 5'd0, 5'd1, 16'd25};
		UUT.inst_mem.memory[9] = {LOAD_WORD, 5'd0, 5'd2, 16'd16};
		UUT.inst_mem.memory[10] = {R_TYPE, 5'd1, 5'd2, 5'd3, 5'b0, OR};
		UUT.inst_mem.memory[11] = {STORE_WORD, 5'd0, 5'd3, 16'd14};

		//AND
		UUT.inst_mem.memory[12] = {LOAD_WORD, 5'd0, 5'd1, 16'd22};
		UUT.inst_mem.memory[13] = {LOAD_WORD, 5'd0, 5'd2, 16'd12};
		UUT.inst_mem.memory[14] = {R_TYPE, 5'd1, 5'd2, 5'd3, 5'b0, AND};
		UUT.inst_mem.memory[15] = {STORE_WORD, 5'd0, 5'd3, 16'd14};

		//SLT
		UUT.inst_mem.memory[16] = {LOAD_WORD, 5'd0, 5'd1, 16'd4};
		UUT.inst_mem.memory[17] = {LOAD_WORD, 5'd0, 5'd2, 16'd5};
		UUT.inst_mem.memory[18] = {R_TYPE, 5'd1, 5'd2, 5'd3, 5'b0, SLT};
		UUT.inst_mem.memory[19] = {STORE_WORD, 5'd0, 5'd3, 16'd14};

		// NOR
		UUT.inst_mem.memory[20] = {LOAD_WORD, 5'd0, 5'd1, 16'd22};
		UUT.inst_mem.memory[21] = {LOAD_WORD, 5'd0, 5'd2, 16'd12};
		UUT.inst_mem.memory[22] = {R_TYPE, 5'd1, 5'd2, 5'd3, 5'b0, NOR};
		UUT.inst_mem.memory[23] = {STORE_WORD, 5'd14, 5'd3, 16'd0};

		// J
		UUT.inst_mem.memory[24] = {JUMP, 26'd26};
		UUT.inst_mem.memory[25] = 32'bX;

		// BEQ, can accept a negative offset, 2's compliment is kinda sick
		UUT.inst_mem.memory[26] = {LOAD_WORD, 5'd0, 5'd1, 16'd5};
		UUT.inst_mem.memory[27] = {LOAD_WORD, 5'd0, 5'd2, 16'd5};
		UUT.inst_mem.memory[28] = {BRANCH_EQ, 5'd1, 5'd2, -16'd29};


		///////////////////////////////////////////////////////////////////////
		//
		//	ADD test
		//
		///////////////////////////////////////////////////////////////////////

		$display("test_bench: running test: ADD");
		// LW $1 0($31)
		#CLK_PERIOD;
		// LW $2 0($31)
		#CLK_PERIOD;
		// ADD $2, $2, $1
		#CLK_PERIOD;
		// SW $2 0($0)
		#CLK_PERIOD;

		// need to wait a little after the next clock cycle to read accurately
		// delta T!
		#1;
		if(UUT.data_mem.memory[0] != (UUT.reg_file.memory[1] + 
			UUT.reg_file.memory[2]))
			$display("test_bench: ADD failure", UUT.reg_file.memory[0],
				UUT.reg_file.memory[1], UUT.reg_file.memory[2]);
		else
			$display("test_bench: ADD succuess");

		//dump_data();

		///////////////////////////////////////////////////////////////////////
		//
		//	SUB test
		//
		///////////////////////////////////////////////////////////////////////

		$display("test_bench: running test: SUB");
		// LW $1 0($31)
		#(CLK_PERIOD - 1);
		// LW $2 30($0)
		#CLK_PERIOD;
		// SUB $3, $1, $2
		#CLK_PERIOD;
		// SW $3 0($0)
		#CLK_PERIOD;

		// need to wait a little after the next clock cycle to read accurately,
		// delta T!
		#1;
		if(UUT.data_mem.memory[0] != (UUT.reg_file.memory[1] - 
			UUT.reg_file.memory[2]))
			$display("test_bench: SUB failure");
		else
			$display("test_bench: SUB succuess");

		//dump_data();

		///////////////////////////////////////////////////////////////////////
		//
		//	OR test
		//
		///////////////////////////////////////////////////////////////////////

		// LW $1 25($0)
		#(CLK_PERIOD-1);
		// LW $2 16($0)
		#CLK_PERIOD;
		// OR $3, $1, $2
		#CLK_PERIOD;
		// SW $3 14($0)
		#CLK_PERIOD;

		$display("test_bench: running test: OR");

		#1;
		if(UUT.data_mem.memory[14] != (UUT.reg_file.memory[1] | 
			UUT.reg_file.memory[2]))
			$display("test_bench: OR failure");
		else
			$display("test_bench: OR succuess");

		//dump_data();

		///////////////////////////////////////////////////////////////////////
		//
		//	AND test
		//
		///////////////////////////////////////////////////////////////////////

		// LW $1 22($0)
		#(CLK_PERIOD-1);
		// LW $2 12($0)
		#CLK_PERIOD;
		// AND $3, $1, $2
		#CLK_PERIOD;
		// SW $3 14($0)
		#CLK_PERIOD;

		$display("test_bench: running test: AND");

		#1;
		if(UUT.data_mem.memory[14] != (UUT.reg_file.memory[1] & 
			UUT.reg_file.memory[2]))
			$display("test_bench: AND failure");
		else
			$display("test_bench: AND succuess");

		//dump_data();

		///////////////////////////////////////////////////////////////////////
		//
		//	SLT test
		//
		///////////////////////////////////////////////////////////////////////

		// LW $1 4($0)
		#(CLK_PERIOD-1);
		// LW $2 5($0)
		#CLK_PERIOD;
		// SLT $3, $1, $2
		#CLK_PERIOD;
		// SW $3 14($0)
		#CLK_PERIOD;

		$display("test_bench: running test: SLT");

		#1;
		if(UUT.data_mem.memory[14] != (UUT.reg_file.memory[1] < 
			UUT.reg_file.memory[2]))
			$display("test_bench: SLT failure");
		else
			$display("test_bench: SLT succuess");

		//dump_data();

		///////////////////////////////////////////////////////////////////////
		//
		//	NOR test
		//
		///////////////////////////////////////////////////////////////////////

		// LW $1 22($0)
		#(CLK_PERIOD-1);
		// LW $2 12($0)
		#CLK_PERIOD;
		// NOR $3, $1, $2
		#CLK_PERIOD;
		// SW $3 14($0)
		#CLK_PERIOD;

		$display("test_bench: running test: NOR");

		#1;
		if(UUT.data_mem.memory[14] != ~(UUT.reg_file.memory[1] | 
			UUT.reg_file.memory[2]))
			$display("test_bench: NOR failure");
		else
			$display("test_bench: NOR succuess");

		//dump_data();

		///////////////////////////////////////////////////////////////////////
		//
		//	JUMP test
		//
		///////////////////////////////////////////////////////////////////////

		// Jump
		#(CLK_PERIOD-1);

		$display("test_bench: running test: J");

		#1;
		if(UUT.program_counter[31:2] != 30'd26)
			$display("test_bench: J failure");
		else
			$display("test_bench: J succuess");

		///////////////////////////////////////////////////////////////////////
		//
		//	BEQ test
		//
		///////////////////////////////////////////////////////////////////////

		// LW $1 5($0)
		#(CLK_PERIOD-1);
		// LW $2 5($0)
		#CLK_PERIOD;
		// BEQ $1, $2, -27
		#CLK_PERIOD;

		$display("test_bench: running test: BEQ");

		#1;
		if(UUT.program_counter != 32'b0)
			$display("test_bench: BEQ failure");
		else
			$display("test_bench: BEQ succuess");

		//dump_data();

		// reserve margin at the end of test
		#(10*CLK_PERIOD);
		$finish;
	end

endmodule
