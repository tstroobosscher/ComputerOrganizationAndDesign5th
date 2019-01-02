`timescale 1ns/1ns

/*
	pipelined mips implementation

	Supported instructions:
		BEQ
		SUB
		ADD
		OR
		SLT
		NOR
		AND
		LW
		SW

	R-Type
	    OP      RS      RT      RD    SHAMT FUNCT
	|-------|-------|-------|-------|------|-----|
	  31:26   25:21   20:16   15:11   10:6   5:0

	LW/SW
	    OP      RS      RT         ADDRESS
	|-------|-------|-------|--------------------|
	  31:26   25:21   20:16         15:0

	Branch
        OP      RS      RT         ADDRESS
	|-------|-------|-------|--------------------|
	  31:26   25:21   20:16         15:0

	Jump
        OP               ADDRESS
	|-------|------------------------------------|
	  31:26               25:0


			|		|		|		|
			|		|		|		|
		PC 	| 	IF 	|	ID	|	EX	|	MEM
			|		|		|		|
			|		|		|		|

		IF/ID {inst_pre_jump, instruction}
		ID/EX {inst_pre_jump, rd1, rd2, sign_ext_imm}
		EX/MEM {next_inst, zero, ALU_res, rd2}
		MEM/WB {mem_rd, alu_res}
 */

module single_cycle_mips_32(clk, rst);
	input clk;
	input rst;

	///////////////////////////////////////////////////////////////////////////
	//
	// IF stage
	//
	///////////////////////////////////////////////////////////////////////////

		///////////////////////////////////////////////////////////////////////
		//
		//	PC -> IF
		//
		///////////////////////////////////////////////////////////////////////

		reg [31:0] program_counter;
		reg pc_init;

		initial pc_init = 1'b0;
		initial program_counter = 32'b0;

		// assign next_instruction after address calculation modules
		wire [31:0] IF_next_instruction;
		wire [31:0] IF_program_counter_plus_4;
		wire [31:0] IF_instruction;

		assign IF_program_counter_plus_4 = IF_program_counter + 4;
		assign IF_next_instruction = PCSrc ? MEM_next_instruction : IF_program_counter_plus_4;

		// save logic for reset and first instruction
		always @(posedge clk or posedge rst) begin
			if (rst) begin
				// reset precedence
				program_counter <= 32'bX;
			end
			else begin

				// PC has its own state logic
				if(~pc_init) begin
					program_counter <= 32'b0;
					pc_init <= 1'b1;
				end
				else begin
					program_counter <= IF_next_instruction;	
				end
			end
		end

		///////////////////////////////////////////////////////////////////////
		//
		//	Instruction Memory -> IF
		//
		///////////////////////////////////////////////////////////////////////	

		inst_mem_64x32 inst_mem(
			.ra(program_counter[7:2]),
			.rd(IF_instruction)
			);

		// pipes the instruction and PC + 4, 64 bits
		reg [63:0] IF_ID_pipe;

		always @(posedge clk or posedge rst) begin
			if (rst)
				IF_ID_pipe <= 64'b0;

			else
				// 63:32 -> pc+4, 31:0 -> instruction
				IF_ID_pipe <= {IF_program_counter_plus_4, IF_instruction};
		end

	///////////////////////////////////////////////////////////////////////////
	//
	// ID stage
	//
	///////////////////////////////////////////////////////////////////////////

		wire [31:0] ID_instruction;
		wire [31:0] ID_next_instruction;

		assign ID_instruction = IF_ID_pipe[31:0];

		///////////////////////////////////////////////////////////////////////
		//
		//	Control Lines -> ID
		//
		///////////////////////////////////////////////////////////////////////

		localparam R_TYPE 		= 6'b000000;
		localparam LOAD_WORD 	= 6'b100011;
		localparam STORE_WORD 	= 6'b101011;

		reg RegDst;
		reg PCSrc;
		reg MemRead;
		reg MemToReg;
		reg [1:0] AluOP;
		reg MemWrite;
		reg ALUSrc;
		reg RegWrite;

		initial RegDst = 1'b0;
		initial PCSrc = 1'b0;
		initial MemRead = 1'b0;
		initial MemToReg = 1'b0;
		initial AluOP = 2'b00;
		initial MemWrite = 1'b0;
		initial ALUSrc = 1'b0;
		initial RegWrite = 1'b0;

		always @(*) begin
			case(instruction[31:26])
				R_TYPE 	: begin
					// R type uses both data addresses and a result address
					RegDst <= 1'b1;
					// second data reg goes to alu
					ALUSrc <= 1'b0;
					// alu result is sent back to the register file
					MemToReg <= 1'b0;
					// writing data bact to register file
					RegWrite <= 1'b1;
					// not reading from memory
					MemRead <= 1'b0;
					// not reading to memory
					MemWrite <= 1'b0;
					// aluop 10 is R-type
					AluOP <= 2'b10;
					// increment PC
					PCSrc <= 1'b0;
				end
				LOAD_WORD 	: begin
					// writing mem data back to register file 
					RegDst <= 1'b0;
					// send the immediate value to the alu for addres offset
					ALUSrc <= 1'b1;
					// send RAM memory to register
					MemToReg <= 1'b1;
					// writing to register
					RegWrite <= 1'b1;
					// reading from memory
					MemRead <= 1'b1;
					// prevent memory corruption
					MemWrite <= 1'b0;
					// add address and immediate
					AluOP <= 2'b00;
					// increment PC
					PCSrc <= 1'b0;
				end
				STORE_WORD 	: begin
					// second data field not used
					RegDst <= 1'bX;
					// send immediate field to alu
					ALUSrc <= 1'b1;
					// not writing data back to register
					MemToReg <= 1'bX;
					// prevent register corruption
					RegWrite <= 1'b0;
					// prevent RAM corruption, this might not matter
					MemRead <= 1'b0;
					// write data to appropriate address
					MemWrite <= 1'b1; 
					// calculate address from immediate and PC+4
					AluOP <= 2'b00;
					// increment PC
					PCSrc <= 1'b0;
				end
				default begin
					
				end
			endcase
		end

		///////////////////////////////////////////////////////////////////////
		//
		//	Register File -> ID
		//	
		///////////////////////////////////////////////////////////////////////

		// TODO
		// write addresses need to be bussed through the pipeline
		wire [4:0] reg_file_write_address;
		// assign reg_file_write_address = RegDst ? ID_instruction[15:11] : 
		// 	ID_instruction[20:16];

		// assign write data after mem access
		wire [31:0] reg_file_write_data;
		wire [31:0] ID_read_data_1;
		wire [31:0] ID_read_data_2;

		register_file reg_file(
			.clk(clk),
			.ra1(ID_instruction[25:21]),
			.ra2(ID_instruction[20:16]),
			.wa(reg_file_write_address),
			.wd(reg_file_write_data),
			.rd1(ID_read_data_1),
			.rd2(ID_read_data_2),
			.regwrite(RegWrite)
			);

		///////////////////////////////////////////////////////////////////////
		//
		//	Sign Extender -> ID
		//
		///////////////////////////////////////////////////////////////////////

		wire [31:0] ID_sign_extended_immediate_16;

		sign_ext_16_32 sign_ext(
			.d(IDinstruction[15:0]),
			.q(ID_sign_extended_immediate_16)
			);

		// pipes the control signals, the register data, the immediate data
		reg [128:0] ID_EX_pipe;

		always @(posedge clk or posedge rst) begin
			if (rst)
				ID_EX_pipe <= 128'b0;

			else
				// 63:32 -> pc+4, 31:0 -> instruction
				ID_EX_pipe <= {ID_next_instruction, ID_read_data_1, 
					ID_read_data_2, ID_sign_extended_immediate_16};
		end

	///////////////////////////////////////////////////////////////////////////
	//
	// EX stage
	//
	///////////////////////////////////////////////////////////////////////////

		wire [31:0] EX_next_instruction;
		wire [31:0] EX_read_data_1;
		wire [31:0] EX_read_data_2;
		wire [31:0] EX_sign_ext_imm;

		assign EX_next_instruction = ID_EX_pipe[127 : 96];
		assign EX_read_data_1 = ID_EX_pipe[95:64];
		assign EX_read_data_2 = ID_EX_pipe[63:32];
		assign EX_sign_ext_imm = ID_EX_pipe[31:0];

		///////////////////////////////////////////////////////////////////////////
		//
		//	ALU -> EX
		//
		///////////////////////////////////////////////////////////////////////////	

		reg [3:0] alu_control;
		initial alu_control = 4'b0;

		localparam AND 	= 4'b0000;
		localparam OR 	= 4'b0001;
		localparam ADD 	= 4'b0010;
		localparam SUB 	= 4'b0110;
		localparam SLT 	= 4'b0111;
		localparam NOR 	= 4'b1100;

		wire [5:0] funct_control;
		assign funct_control = instruction[5:0];

		always @(*) begin

			// default add (LW and SW)
			if (~AluOP[1] && ~AluOP[0]) begin
				alu_control <= ADD;
			end

			// default sub (beq)
			else if (AluOP[0]) begin
				alu_control <= SUB;
			end

			// r-type
			else if(AluOP[1]) begin
				if(funct_control[3:0] == 4'b0000)
					alu_control <= ADD;
				else if(funct_control[3:0] == 4'b0010)
					alu_control <= SUB;
				else if(funct_control[3:0] == 4'b0100)
					alu_control <= AND;
				else if(funct_control[3:0] == 4'b0101)
					alu_control <= OR;
				else if(funct_control[3:0] == 4'b1010)
					alu_control <= SLT;
				else if(funct_control[3:0] == 4'b0111)
					alu_control <= NOR;
				else
					alu_control <= 4'bXXXX;
			end
			else
				alu_control <= 4'bXXXX;
		end

		wire [31:0] alu_input_1;
		wire [31:0] alu_input_2;
		wire [31:0] alu_result;
		wire alu_zero;

		assign alu_input_1 = read_data_1;
		assign alu_input_2 = ALUSrc ? sign_extended_immediate_16 : read_data_2;

		alu alu(
			.alucont(alu_control),
			.rd1(alu_input_1),
			.rd2(alu_input_2),
			.res(alu_result),
			.zero(alu_zero)
			);

		///////////////////////////////////////////////////////////////////////////
		//
		//	Address Calculation -> EX
		//	
		//	
		//	
		///////////////////////////////////////////////////////////////////////////	

		wire [31:0] address_calc;
		wire [31:0] immediate_shift_left_2;
		wire PCSrc;
		wire [31:0] MEM_next_instruction;
		wire [31:0] jump_address;

		assign jump_address = {program_counter_plus_4[31:28], instruction[25:0], 2'b0};
		assign PCSrc = Branch & alu_zero;
		assign immediate_shift_left_2 = {sign_extended_immediate_16[29:0], 2'b0};
		assign address_calc = program_counter_plus_4 + immediate_shift_left_2;

		reg [:] EX_MEM_pipe;

		always @(posedge clk or posedge rst) begin
			if (rst)
				EX_MEM_pipe <= 128'b0;

			else
				// 
				EX_MEM_pipe <= {};
		end


	///////////////////////////////////////////////////////////////////////////
	//
	// MEM stage
	//
	///////////////////////////////////////////////////////////////////////////

		wire [31:0] MEM_next_instruction;

		///////////////////////////////////////////////////////////////////////////
		//
		//	Data Memory -> MEM
		//	
		//	RAM
		//	
		///////////////////////////////////////////////////////////////////////////

		wire [31:0] data_mem_data;

		// lower 6 address bits are focused on because of the address size
		data_mem_64x32 data_mem(
			.clk(clk),
			.addr(alu_result[5:0]),
			.rd(data_mem_data),
			.wd(read_data_2),
			.memwrite(MemWrite),
			.memread(MemRead)
			);

		assign write_data = MemToReg ? data_mem_data : alu_result;

endmodule
