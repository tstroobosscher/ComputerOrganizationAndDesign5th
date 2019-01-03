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
		ID/EX {control, inst_pre_jump, rd1, rd2, sign_ext_imm}
		EX/MEM {control, next_inst, zero, ALU_res, rd2}
		MEM/WB {control, mem_rd, alu_res}

	Is there anyway to avoid the hardcoding of buswidths and wire indexes?
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
		// PCSrc comes from the Mem stage
		assign IF_next_instruction = ID_PCSrc ? MEM_next_instruction : 
			IF_program_counter_plus_4;

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
		initial IF_ID_pipe = 64'bX;

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
		wire [31:0] ID_program_counter_plus_4;

		assign ID_instruction = IF_ID_pipe[31:0];
		assign ID_program_counter_plus_4 = IF_ID_pipe[63:32];

		///////////////////////////////////////////////////////////////////////
		//
		//	Control Lines -> ID
		//
		///////////////////////////////////////////////////////////////////////

		localparam R_TYPE 		= 6'b000000;
		localparam LOAD_WORD 	= 6'b100011;
		localparam STORE_WORD 	= 6'b101011;

		reg ID_RegDst;
		reg ID_PCSrc;
		reg ID_MemRead;
		reg ID_MemToReg;
		reg [1:0] ID_AluOP;
		reg ID_MemWrite;
		reg ID_ALUSrc;
		reg ID_RegWrite;

		initial ID_RegDst = 1'b0;
		initial ID_PCSrc = 1'b0;
		initial ID_MemRead = 1'b0;
		initial ID_MemToReg = 1'b0;
		initial ID_AluOP = 2'b00;
		initial ID_MemWrite = 1'b0;
		initial ID_ALUSrc = 1'b0;
		initial ID_RegWrite = 1'b0;

		always @(*) begin
			case(instruction[31:26])
				R_TYPE 	: begin
					// R type uses both data addresses and a result address
					ID_RegDst <= 1'b1;
					// second data reg goes to alu
					ID_ALUSrc <= 1'b0;
					// alu result is sent back to the register file
					ID_MemToReg <= 1'b0;
					// writing data bact to register file
					ID_RegWrite <= 1'b1;
					// not reading from memory
					ID_MemRead <= 1'b0;
					// not reading to memory
					ID_MemWrite <= 1'b0;
					// aluop 10 is R-type
					ID_AluOP <= 2'b10;
					// increment PC
					ID_PCSrc <= 1'b0;
				end
				LOAD_WORD 	: begin
					// writing mem data back to register file 
					ID_RegDst <= 1'b0;
					// send the immediate value to the alu for addres offset
					ID_ALUSrc <= 1'b1;
					// send RAM memory to register
					ID_MemToReg <= 1'b1;
					// writing to register
					ID_RegWrite <= 1'b1;
					// reading from memory
					ID_MemRead <= 1'b1;
					// prevent memory corruption
					ID_MemWrite <= 1'b0;
					// add address and immediate
					ID_AluOP <= 2'b00;
					// increment PC
					ID_PCSrc <= 1'b0;
				end
				STORE_WORD 	: begin
					// second data field not used
					ID_RegDst <= 1'bX;
					// send immediate field to alu
					ID_ALUSrc <= 1'b1;
					// not writing data back to register
					ID_MemToReg <= 1'bX;
					// prevent register corruption
					ID_RegWrite <= 1'b0;
					// prevent RAM corruption, this might not matter
					ID_MemRead <= 1'b0;
					// write data to appropriate address
					ID_MemWrite <= 1'b1; 
					// calculate address from immediate and PC+4
					ID_AluOP <= 2'b00;
					// increment PC
					ID_PCSrc <= 1'b0;
				end
				default begin

					// illegal option
					ID_RegDst <= 1'bX;
					ID_ALUSrc <= 1'bX;
					ID_MemToReg <= 1'bX;
					ID_RegWrite <= 1'bX;
					ID_MemRead <= 1'bX;
					ID_MemWrite <= 1'bX; 
					ID_AluOP <= 2'bXX;
					ID_PCSrc <= 1'bX;
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
			.regwrite(WB_RegWrite)
			);

		///////////////////////////////////////////////////////////////////////
		//
		//	Sign Extender -> ID
		//
		///////////////////////////////////////////////////////////////////////

		wire [31:0] ID_sign_ext_immediate_32;

		sign_ext_16_32 sign_ext(
			.d(ID_instruction[15:0]),
			.q(ID_sign_ext_immediate_32)
			);

		///////////////////////////////////////////////////////////////////////
		//
		//	ID/EX Pipe signals
		//
		///////////////////////////////////////////////////////////////////////

		wire [4:0] ID_rt;
		assign ID_rt = ID_instruction[20:16];

		wire [4:0] ID_rd;
		assign ID_rd = ID_instruction[15:11];

		wire [8:0] ID_control_signals;
		assign ID_control_signals = {ID_RegDst, ID_ALUSrc, ID_MemToReg, 
			ID_RegWrite, ID_MemRead, ID_MemWrite, ID_AluOP, ID_PCSrc};

		// pipes the control signals, the register data, the immediate data
		// TODO: will need to add more lines for write address
		reg [159:0] ID_EX_pipe;
		initial ID_EX_pipe = 160'bX;

		always @(posedge clk or posedge rst) begin
			if (rst)

				// can these be dynamically assigned?
				ID_EX_pipe <= 160'b0;

			else
				// 	13 extra, 5 rt, 5 rd 9 control, 32 pc+4, 32 rd1, 32 rd2, 
				//	32 imm
				ID_EX_pipe <= {13'b0, ID_rt, ID_rd, ID_control_signals, 
				ID_program_counter_plus_4, ID_read_data_1, ID_read_data_2, 
				ID_sign_ext_immediate_32};
		end

	///////////////////////////////////////////////////////////////////////////
	//
	// 	EX stage
	//
	//	Needed control signals: RegDst, ALUSrc, ALUOp
	//
	///////////////////////////////////////////////////////////////////////////

		wire [4:0] EX_rt;
		wire [4:0] EX_rd;

		assign EX_rt = ID_EX_pipe[146:142];
		assign EX_rd = ID_EX_pipe[141:137];

		wire EX_RegDst;
		wire EX_ALUSrc;
		wire EX_MemToReg;
		wire EX_RegWrite;
		wire EX_MemRead;
		wire EX_MemWrite;
		wire EX_AluOP;
		wire EX_PCSrc;

		assign EX_RegDst = ID_EX_pipe[136];
		assign EX_ALUSrc = ID_EX_pipe[135];
		assign EX_MemToReg = ID_EX_pipe[134];
		assign EX_RegWrite = ID_EX_pipe[133];
		assign EX_MemRead = ID_EX_pipe[132];
		assign EX_MemWrite = ID_EX_pipe[131];
		assign EX_AluOP = ID_EX_pipe[130:129];
		assign EX_PCSrc = ID_EX_pipe[128];

		wire [31:0] EX_program_counter_plus_4;
		wire [31:0] EX_read_data_1;
		wire [31:0] EX_read_data_2;
		wire [31:0] EX_sign_ext_immediate_32;

		assign EX_program_counter_plus_4 = ID_EX_pipe[127:96];
		assign EX_read_data_1 = ID_EX_pipe[95:64];
		assign EX_read_data_2 = ID_EX_pipe[63:32];
		assign EX_sign_ext_immediate_32 = ID_EX_pipe[31:0];

		///////////////////////////////////////////////////////////////////////
		//
		//	ALU -> EX
		//
		///////////////////////////////////////////////////////////////////////

		reg [3:0] alu_control;
		initial alu_control = 4'b0;

		localparam AND 	= 4'b0000;
		localparam OR 	= 4'b0001;
		localparam ADD 	= 4'b0010;
		localparam SUB 	= 4'b0110;
		localparam SLT 	= 4'b0111;
		localparam NOR 	= 4'b1100;

		wire [5:0] funct_control;

		// dual purpose, carries lower 6 bits of instruction also
		assign funct_control = EX_sign_ext_immediate_32[5:0];

		always @(*) begin

			// default add (LW and SW)
			if (~ID_AluOP[1] && ~ID_AluOP[0]) begin
				alu_control <= ADD;
			end

			// default sub (beq)
			else if (ID_AluOP[0]) begin
				alu_control <= SUB;
			end

			// r-type
			else if(ID_AluOP[1]) begin
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

		wire [31:0] EX_alu_input_1;
		wire [31:0] EX_alu_input_2;
		wire [31:0] EX_alu_result;
		wire EX_alu_zero;

		assign EX_alu_input_1 = EX_read_data_1;
		assign EX_alu_input_2 = EX_ALUSrc ? EX_sign_ext_immediate_32 : 
			EX_read_data_2;

		alu alu(
			.alucont(alu_control),
			.rd1(EX_alu_input_1),
			.rd2(EX_alu_input_2),
			.res(EX_alu_result),
			.zero(EX_alu_zero)
			);

		///////////////////////////////////////////////////////////////////////
		//
		//	Address Calculation -> EX
		//
		///////////////////////////////////////////////////////////////////////

		wire [31:0] EX_immediate_shift_left_2;
		wire [31:0] EX_branch_address;

		assign EX_immediate_shift_left_2 = {EX_sign_ext_immediate_32[29:0], 
			2'b0};
		assign EX_branch_address = program_counter_plus_4 + 
			EX_immediate_shift_left_2;

		///////////////////////////////////////////////////////////////////////
		//
		//	EX/MEM Pipe signals
		//
		///////////////////////////////////////////////////////////////////////

		assign EX_reg_file_write_address = EX_RegDst ? EX_rd : EX_rt;

		wire [4:0] EX_control_signals;
		assign EX_control_signals = {EX_MemToReg, EX_RegWrite, EX_MemRead, 
			EX_MemWrite, EX_PCSrc};

		// next inst, zero, ALU res, read_data_2
		reg [159:0] EX_MEM_pipe;
		initial EX_MEM_pipe = 160'bX;

		always @(posedge clk or posedge rst) begin
			if (rst)
				EX_MEM_pipe <= 160'b0;
			else
				// 	26 extra,, 5 control, 1 zero, 32 WB addr, 
				//	32 branch address, 32 alures, 32 read data 2
				EX_MEM_pipe <= {26'b0, EX_control_signals, EX_alu_zero, 
					EX_reg_file_write_address, EX_branch_address, 
					EX_alu_result, EX_read_data_2};
		end


	///////////////////////////////////////////////////////////////////////////
	//
	// 	MEM stage
	//
	//	Needed control signals: MemWrite, MemRead, PCSrc
	//
	///////////////////////////////////////////////////////////////////////////

		wire MEM_MemToReg;
		wire MEM_RegWrite;
		wire MEM_MemRead;
		wire MEM_MemWrite;
		wire MEM_PCSrc;

		assign MEM_MemToReg = EX_MEM_pipe[133];
		assign MEM_RegWrite = EX_MEM_pipe[132];
		assign MEM_MemRead = EX_MEM_pipe[131];
		assign MEM_MemWrite = EX_MEM_pipe[130];
		assign MEM_PCSrc = EX_MEM_pipe[129];

		wire MEM_zero;
		wire [31:0] MEM_reg_file_write_address;
		wire [31:0] MEM_branch_address;
		wire [31:0] MEM_alu_result;
		wire [31:0] MEM_read_data_2;

		// for branch equality
		assign MEM_zero = EX_MEM_pipe[128];

		// write back address
		assign MEM_reg_file_write_address = EX_MEM_pipe[127:96];

		// for IF
		assign MEM_branch_address = EX_MEM_pipe[95:64];

		// can also bypass data and go straight to WB
		assign MEM_alu_result = EX_MEM_pipe[63:32];

		// SW data
		assign MEM_read_data_2 = EX_MEM_pipe[31:0];

		///////////////////////////////////////////////////////////////////////
		//
		//	Data Memory -> MEM
		//
		///////////////////////////////////////////////////////////////////////

		wire [31:0] MEM_data;

		// lower 6 address bits are focused on because of the address size
		data_mem_64x32 data_mem(
			.clk(clk),
			.addr(MEM_alu_result[5:0]),
			.rd(MEM_data),
			.wd(MEM_read_data_2),
			.memwrite(MEM_MemWrite),
			.memread(MEM_MemRead)
			);

		///////////////////////////////////////////////////////////////////////
		//
		//	MEM/WB Pipe signals
		//
		///////////////////////////////////////////////////////////////////////

		wire [1:0] MEM_control_signals;
		assign MEM_control_signals = {RegWrite, MemToReg}

		// next inst, zero, ALU res, read_data_2, ID_MemToReg
		reg [96:0] MEM_WB_pipe;
		initial MEM_WB_pipe = 96'bX;

		always @(posedge clk or posedge rst) begin
			if (rst)
				MEM_WB_pipe <= 64'b0;
			else
				// 30 extra, 2 control, 32 LW data, 32 alu res
				MEM_WB_pipe <= {30'b0, MEM_control_signals, MEM_data, 
					MEM_alu_result};
		end

	///////////////////////////////////////////////////////////////////////////
	//
	// 	WB stage
	//
	//	Needed control signals: RegWrite, MemToReg
	//
	///////////////////////////////////////////////////////////////////////////

		wire WB_RegWrite;
		wire WB_MemToReg;

		assign WB_RegWrite = MEM_WB_pipe[65];
		assign WB_MemToReg = MEM_WB_pipe[64];

		wire [31:0] WB_data;
		wire [31:0] WB_alu_result;
		wire [31:0] WB_write_back;

		assign WB_data = MEM_WB_pipe[63:32];
		assign WB_alu_result = MEM_WB_pipe[31:0];
		assign WB_write_back = WB_MemToReg ? WB_data : WB_alu_result;

endmodule
