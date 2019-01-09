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

module five_stage_pipeline_mips_32(clk, rst);
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
		wire PC_stall;
		wire IF_stall;

		assign PC_stall = stall;
		assign IF_stall = stall;

		assign IF_program_counter_plus_4 = program_counter + 4;
		// PCSrc comes from the Mem stage
		assign IF_next_instruction = MEM_PCSrc ? MEM_branch_address : 
			IF_program_counter_plus_4;

		// save logic for reset and first instruction
		always @(posedge clk or posedge rst) begin
			if (rst) begin
				// reset precedence
				program_counter <= 32'bX;
				pc_init <= 1'b0;
			end
			else begin

				// PC has its own state logic
				if(~pc_init) begin
					program_counter <= 32'b0;
					pc_init <= 1'b1;
				end
				else begin

					// 	would probably be more accurate to build the PC enable
					// 	and invert the logic
					if (PC_stall) 
						program_counter <= program_counter;
					else
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
				if(IF_stall)
					IF_ID_pipe <= IF_ID_pipe;
				else 
					// 	63:32 -> pc+4, 31:0 -> instruction
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
		localparam BRANCH 		= 6'b000100;

		reg ID_RegDst;
		reg ID_Branch;
		reg ID_MemRead;
		reg ID_MemToReg;
		reg [1:0] ID_AluOP;
		reg ID_MemWrite;
		reg ID_ALUSrc;
		reg ID_RegWrite;

		initial ID_RegDst = 1'b0;
		initial ID_Branch = 1'b0;
		initial ID_MemRead = 1'b0;
		initial ID_MemToReg = 1'b0;
		initial ID_AluOP = 2'b00;
		initial ID_MemWrite = 1'b0;
		initial ID_ALUSrc = 1'b0;
		initial ID_RegWrite = 1'b0;

		always @(*) begin
			case(ID_instruction[31:26])
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
					ID_Branch <= 1'b0;
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
					ID_Branch <= 1'b0;
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
					ID_Branch <= 1'b0;
				end
				BRANCH 		: begin
					// second data field not used
					ID_RegDst <= 1'bX;
					// send immediate field to alu
					ID_ALUSrc <= 1'b0;
					// not writing data back to register
					ID_MemToReg <= 1'bX;
					// prevent register corruption
					ID_RegWrite <= 1'b0;
					// prevent RAM corruption, this might not matter
					ID_MemRead <= 1'b0;
					// write data to appropriate address
					ID_MemWrite <= 1'b0; 
					// sub
					ID_AluOP <= 2'b01;
					// branch
					ID_Branch <= 1'b1;
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
					ID_Branch <= 1'bX;
				end
			endcase
		end

		///////////////////////////////////////////////////////////////////////
		//
		//	Register File -> ID
		//	
		///////////////////////////////////////////////////////////////////////

		// assign write data after mem access
		wire [31:0] reg_file_write_data;
		wire [31:0] ID_read_data_1;
		wire [31:0] ID_read_data_2;

		register_file reg_file(
			.clk(clk),
			.rst(rst),
			.ra1(ID_instruction[25:21]),
			.ra2(ID_instruction[20:16]),
			.wa(WB_reg_file_write_address),
			.wd(WB_write_back_data),
			.rd1(ID_read_data_1),
			.rd2(ID_read_data_2),
			.regwrite(WB_RegWrite)
			);

		///////////////////////////////////////////////////////////////////////
		//
		//	Early Branch Forwarding Multiplexors -> ID
		//
		///////////////////////////////////////////////////////////////////////

		localparam EARLY_BRANCH_FORWARD_ID = 2'b00;
		localparam EARLY_BRANCH_FORWARD_MEM = 2'b01;
		localparam EARLY_BRANCH_FORWARD_WB = 2'b10;

		reg [1:0] FORWARD_BRANCH_A;
		reg [1:0] FORWARD_BRANCH_B;

		reg [31:0] ID_branch_data_1;
		reg [31:0] ID_branch_data_2;

		always @(*) begin
			case(FORWARD_BRANCH_A)
				EARLY_BRANCH_FORWARD_ID		:
					ID_branch_data_1 <= ID_read_data_1;
				EARLY_BRANCH_FORWARD_MEM	:
					ID_branch_data_1 <= MEM_alu_result;
				EARLY_BRANCH_FORWARD_WB		:
					ID_branch_data_1 <= WB_write_back_data;
			endcase
		end

		always @(*) begin
			case(FORWARD_BRANCH_B)
				EARLY_BRANCH_FORWARD_ID		:
					ID_branch_data_2 <= ID_read_data_2;
				EARLY_BRANCH_FORWARD_MEM	:
					ID_branch_data_2 <= MEM_alu_result;
				EARLY_BRANCH_FORWARD_WB		:
					ID_branch_data_2 <= WB_write_back_data;
			endcase
		end

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
		//	Hazard Detection Unit -> ID
		//
		///////////////////////////////////////////////////////////////////////

		wire stall;

		reg hazard_stall;

		initial hazard_stall = 0;

		//	test if load instruction in the EX stage, then check if the 
		//	subsequent instruction is dependent on the LW result

		always @(*) begin
			if(EX_MemRead & ((EX_rt == ID_rs) | (EX_rt == ID_rt)))
				hazard_stall <= 1'b1;
			else
				hazard_stall <= 1'b0;
		end

		reg early_branch_stall;

		always @(*) begin
			//	if there is a branch in ID that depends on the result in EX,
			//	must stall one cycle to get the correct value
			//	if a LW is followed by a branch, the branch must stall 2 cycles
			if(ID_Branch & EX_RegWrite & (ID_rs == EX_reg_file_write_address))
				early_branch_stall <= 1'b1;
			else if (ID_Branch & MEM_MemRead & 
				(ID_rs == MEM_reg_file_write_address))
				early_branch_stall <= 1'b1;
			else begin
				early_branch_stall <= 1'b0;
			end
		end

		assign stall = hazard_stall | early_branch_stall;

		///////////////////////////////////////////////////////////////////////
		//
		//	Early Branch Forwarding Logic -> ID
		//
		///////////////////////////////////////////////////////////////////////

		//	Control Hazards
		//	RS/RT and A/B respectively
		always @(*) begin
			//	if branch, and source address matches either MEM or WB 
			//	destination branch, forward that result over the register file

			if(ID_Branch & (ID_rs == MEM_reg_file_write_address))
				FORWARD_BRANCH_A <= EARLY_BRANCH_FORWARD_MEM;
			else if(ID_Branch & (ID_rs == WB_reg_file_write_address))
				FORWARD_BRANCH_A <= EARLY_BRANCH_FORWARD_WB;
			else
				FORWARD_BRANCH_A <= EARLY_BRANCH_FORWARD_ID;
		end

		always @(*) begin
			if(ID_Branch & (ID_rt == MEM_reg_file_write_address))
				FORWARD_BRANCH_B <= EARLY_BRANCH_FORWARD_MEM;
			else if(ID_Branch & (ID_rt == WB_reg_file_write_address))
				FORWARD_BRANCH_B <= EARLY_BRANCH_FORWARD_WB;
			else 
				FORWARD_BRANCH_B <= EARLY_BRANCH_FORWARD_ID;
		end

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
			ID_RegWrite, ID_MemRead, ID_MemWrite, ID_AluOP, ID_Branch};

		reg [159:0] ID_EX_pipe;
		initial ID_EX_pipe = 160'bX;

		wire [4:0] ID_rs;
		assign  ID_rs = ID_instruction[25:21];

		always @(posedge clk or posedge rst) begin
			if (rst)

				// can these be dynamically assigned?
				ID_EX_pipe <= 160'b0;

			else
				// 	8 extra 5 rs, 5 rt, 5 rd 9 control, 32 pc+4, 32 rd1,
				//	32 rd2, 32 imm
				ID_EX_pipe <= {8'b0, ID_rs, ID_rt, ID_rd, ID_control_signals, 
				ID_program_counter_plus_4, ID_branch_data_1, ID_branch_data_2, 
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
		wire [4:0] EX_rs;

		assign EX_rt = ID_EX_pipe[146:142];
		assign EX_rd = ID_EX_pipe[141:137];
		assign EX_rs = ID_EX_pipe[151:147];

		wire EX_RegDst;
		wire EX_ALUSrc;
		wire EX_MemToReg;
		wire EX_RegWrite;
		wire EX_MemRead;
		wire EX_MemWrite;
		wire EX_AluOP;
		wire EX_Branch;

		assign EX_RegDst = ID_EX_pipe[136];
		assign EX_ALUSrc = ID_EX_pipe[135];
		assign EX_MemToReg = ID_EX_pipe[134];
		assign EX_RegWrite = ID_EX_pipe[133];
		assign EX_MemRead = ID_EX_pipe[132];
		assign EX_MemWrite = ID_EX_pipe[131];
		assign EX_AluOP = ID_EX_pipe[130:129];
		assign EX_Branch = ID_EX_pipe[128];

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
		//	Forwarding Multiplexors -> EX
		//
		///////////////////////////////////////////////////////////////////////

		// Depending on forwarding signals, can either send EX, MEM, or WB
		// So far we are only forwarding from MEM/WB to EX
		// There needs to be a priority on MEM forwarding over WB forwarding
		// Since MEM has the most recent data, its value should be carried over
		// the WB value, which is slightly older

		localparam FORWARD_EX_EX = 00;
		localparam FORWARD_EX_MEM = 01;
		localparam FORWARD_EX_WB = 10;

		reg [1:0] FORWARD_A;
		reg [1:0] FORWARD_B;
		reg [31:0] EX_forward_res_1;
		reg [31:0] EX_forward_res_2;
		wire [31:0] EX_alu_input_1;
		wire [31:0] EX_alu_input_2;

		// A
		always @(*) begin
			case(FORWARD_A)
				FORWARD_EX_WB	:
					EX_forward_res_1 <= WB_write_back_data;
				FORWARD_EX_MEM	:
					EX_forward_res_1 <= MEM_alu_result;
				FORWARD_EX_EX	:
					EX_forward_res_1 <= EX_read_data_1;
				default 		:
					EX_forward_res_1 <= 32'bX;
			endcase
		end

		// B
		always @(*) begin
			case(FORWARD_B)
				FORWARD_EX_WB	:
					EX_forward_res_2 <= WB_write_back_data;
				FORWARD_EX_MEM	:
					EX_forward_res_2 <= MEM_alu_result;
				FORWARD_EX_EX	:
					EX_forward_res_2 <= EX_read_data_2;
				default 		:
					EX_forward_res_2 <= 32'bX;
			endcase
		end

		assign EX_alu_input_1 = EX_forward_res_1;
		assign EX_alu_input_2 = EX_ALUSrc ? EX_sign_ext_immediate_32 : 
			EX_forward_res_2;

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

		wire [31:0] EX_alu_result;
		wire EX_alu_zero;

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
		assign EX_branch_address = EX_program_counter_plus_4 + 
			EX_immediate_shift_left_2;

		///////////////////////////////////////////////////////////////////////
		//
		//	Forwarding Unit -> EX
		//
		///////////////////////////////////////////////////////////////////////

		//	forwarding to the RS
		always @(*) begin
			//	if write reg instruction, and destination isn't 0, and the 
			// 	destination address matches an the RS address in EX, then
			// 	send the MEM result to EX
			if (MEM_RegWrite & (MEM_reg_file_write_address != 0) &
				(MEM_reg_file_write_address == EX_rs)) begin
					FORWARD_A <= FORWARD_EX_MEM;
			end

			// 	else if write reg instruction in the WB stage and the
			//	destination isnt zero, then send the WB result to EX
			// 	Important! the MEM stage is given priority
			else if(WB_RegWrite & (WB_reg_file_write_address != 0) &  
				(WB_reg_file_write_address == EX_rs)) begin 
					FORWARD_A <= FORWARD_EX_WB;
			end

			else begin
					FORWARD_A <= FORWARD_EX_EX;
			end
		end

		// 	forwarding signals to the RT
		always @(*) begin
			if (MEM_RegWrite & (MEM_reg_file_write_address != 0) &
				(MEM_reg_file_write_address == EX_rt)) begin
					FORWARD_B <= FORWARD_EX_MEM;
			end

			else if(WB_RegWrite & (WB_reg_file_write_address != 0) &
				(WB_reg_file_write_address == EX_rt)) begin
					FORWARD_B <= FORWARD_EX_WB;
			end

			else begin
					FORWARD_B <= FORWARD_EX_EX;
			end
		end

		///////////////////////////////////////////////////////////////////////
		//
		//	EX/MEM Pipe signals
		//
		///////////////////////////////////////////////////////////////////////

		wire [4:0] EX_reg_file_write_address;
		assign EX_reg_file_write_address = EX_RegDst ? EX_rd : EX_rt;

		wire [4:0] EX_control_signals;
		assign EX_control_signals = {EX_MemToReg, EX_RegWrite, EX_MemRead, 
			EX_MemWrite, EX_Branch};

		// next inst, zero, ALU res, read_data_2
		reg [127:0] EX_MEM_pipe;
		initial EX_MEM_pipe = 128'bX;

		always @(posedge clk or posedge rst) begin
			if (rst)
				EX_MEM_pipe <= 128'b0;
			else
				// 	21 extra, 5 control, 1 zero, 5 WB addr, 
				//	32 branch address, 32 alures, 32 read data 2
				EX_MEM_pipe <= {21'b0, EX_control_signals, EX_alu_zero, 
					EX_reg_file_write_address, EX_branch_address, 
					EX_alu_result, EX_forward_res_2};
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
		wire MEM_Branch;
		wire MEM_PCSrc;

		assign MEM_MemToReg = EX_MEM_pipe[106];
		assign MEM_RegWrite = EX_MEM_pipe[105];
		assign MEM_MemRead = EX_MEM_pipe[104];
		assign MEM_MemWrite = EX_MEM_pipe[103];
		assign MEM_Branch = EX_MEM_pipe[102];
		assign MEM_PCSrc = MEM_Branch & MEM_zero;

		wire MEM_zero;
		wire [4:0] MEM_reg_file_write_address;
		wire [31:0] MEM_branch_address;
		wire [31:0] MEM_alu_result;
		wire [31:0] MEM_read_data_2;

		assign MEM_zero = EX_MEM_pipe[101];
		assign MEM_reg_file_write_address = EX_MEM_pipe[100:96];
		assign MEM_branch_address = EX_MEM_pipe[95:64];
		assign MEM_alu_result = EX_MEM_pipe[63:32];
		assign MEM_read_data_2 = EX_MEM_pipe[31:0];

		///////////////////////////////////////////////////////////////////////
		//
		//	Data Memory -> MEM
		//
		///////////////////////////////////////////////////////////////////////

		wire [31:0] MEM_mem_data;

		// lower 6 address bits are focused on because of the address size (64)
		data_mem_64x32 data_mem(
			.clk(clk),
			.rst(rst),
			.addr(MEM_alu_result[5:0]),
			.rd(MEM_mem_data),
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
		assign MEM_control_signals = {MEM_RegWrite, MEM_MemToReg};

		// next inst, zero, ALU res, read_data_2, ID_MemToReg
		reg [95:0] MEM_WB_pipe;
		initial MEM_WB_pipe = 96'bX;

		always @(posedge clk or posedge rst) begin
			if (rst)
				MEM_WB_pipe <= 64'b0;
			else
				// 25 extra, 5 address, 2 control, 32 LW data, 32 alu res
				MEM_WB_pipe <= {25'b0, MEM_reg_file_write_address, 
					MEM_control_signals, MEM_mem_data, MEM_alu_result};
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
		wire [4:0] WB_reg_file_write_address;

		assign WB_reg_file_write_address = MEM_WB_pipe[70:66];
		assign WB_RegWrite = MEM_WB_pipe[65];
		assign WB_MemToReg = MEM_WB_pipe[64];

		wire [31:0] WB_mem_data;
		wire [31:0] WB_alu_result;
		wire [31:0] WB_write_back_data;

		assign WB_mem_data = MEM_WB_pipe[63:32];
		assign WB_alu_result = MEM_WB_pipe[31:0];
		assign WB_write_back_data = WB_MemToReg ? WB_mem_data : WB_alu_result;

endmodule
