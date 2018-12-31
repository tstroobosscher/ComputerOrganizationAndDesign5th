`timescale 1ns/1ns

/*
	single cycle mips implementation
 */

module single_cycle_mips_32(clk, rst);
	input clk;
	input rst;

	///////////////////////////////////////////////////////////////////////////
	//
	//	Control Lines
	//	
	//	Need control module for control lines, maps instruction[31:26] to lines
	//
	///////////////////////////////////////////////////////////////////////////

	localparam R_TYPE 		= 6'b000000;
	localparam LOAD_WORD 	= 6'b100011;
	localparam STORE_WORD 	= 6'b101011;
	localparam BRANCH_EQ	= 6'b000100;

	reg RegDst;
	reg Branch;
	reg MemRead;
	reg MemToReg;
	reg [1:0] AluOP;
	reg MemWrite;
	reg ALUSrc;
	reg RegWrite;

	wire [31:0] instruction;

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
				// increment PC;
				Branch <= 1'b0;
				// aluop 10 is R-type
				AluOP <= 2'b10;
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
				// increment PC
				Branch <= 1'b0;
				// add address and immediate
				AluOP <= 2'b00;
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
				// increment pc
				Branch <= 1'b0;
				// calculate address from immediate and PC+4
				AluOP <= 2'b00;
			end
			BRANCH_EQ 	: begin
				// no third field necessary
				RegDst <= 1'bX;
				// send second data field to alu
				ALUSrc <= 1'b0;
				// not writing back from memory to register
				MemToReg <= 1'bX;
				// not writing to register, prevent corruption
				RegWrite <= 1'b0;
				// not reading from register
				MemRead <= 1'b0;
				// not writing to memory
				MemWrite <= 1'b0;
				// branch if zero
				Branch = 1'b1;
				// check if zero subtract
				AluOP <= 2'b01;
			end
			default begin
				
			end
		endcase
	end

	///////////////////////////////////////////////////////////////////////////
	//
	//	PC
	//	There are 64 instruction memory locations, log2(64) = 6 address bits
	//	and then there are 4 byte locations inside each 32 bit address
	//		---> 8 address bits needed, 32 given, possibe address space: 4G
	///////////////////////////////////////////////////////////////////////////

	wire [31:0] next_instruction;
	reg [31:0] program_counter;

	// assign next_instruction after address calculation modules

	always @(posedge clk or posedge rst) begin
		if (rst) begin
			// reset precedence
			program_counter <= 32'b0;
		end
		else begin
			program_counter <= next_instruction;
		end
	end

	wire [31:0] program_counter_plus_4;
	assign program_counter_plus_4 = program_counter + 4;

	///////////////////////////////////////////////////////////////////////////
	//
	//	Instruction Memory
	//	Needs to be loaded before execution
	//
	//
	///////////////////////////////////////////////////////////////////////////	

	inst_mem_64x32 inst_mem(
		.ra(program_counter[5:0]),
		.rd(instruction)
		);

	///////////////////////////////////////////////////////////////////////////
	//
	//	Register File
	//	
	//
	//
	///////////////////////////////////////////////////////////////////////////

	wire [4:0] write_address;
	assign write_address = RegDst ? instruction[15:11] : instruction[20:16];

	// assign write data after mem access
	wire [31:0] write_data;
	wire [31:0] read_data_1;
	wire [31:0] read_data_2;

	register_file reg_file(
		.clk(clk),
		.ra1(instruction[25:21]),
		.ra2(instruction[20:16]),
		.wa(write_address),
		.wd(write_data),
		.rd1(read_data_1),
		.rd2(read_data_1),
		.regwrite(RegWrite)
		);

	///////////////////////////////////////////////////////////////////////////
	//
	//	Sign Extender
	//	
	//
	//
	///////////////////////////////////////////////////////////////////////////

	wire [31:0] sign_extended_immediate_16;

	sign_ext_16_32 sign_ext(
		.d(instruction[15:0]),
		.q(sign_extended_immediate_16)
		);

	///////////////////////////////////////////////////////////////////////////
	//
	//	ALU
	//	
	//	Need ALU control unit, takes in AluOP and funct field
	//	and outputs the alu control lines
	///////////////////////////////////////////////////////////////////////////	

	reg [3:0] alu_control;

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
	//	Address Calculation
	//	
	//	
	//	
	///////////////////////////////////////////////////////////////////////////	

	wire [31:0] address_calc;
	wire [31:0] immediate_shift_left_2;
	wire PCSrc;

	assign PCSrc = Branch & alu_zero;
	assign immediate_shift_left_2 = {sign_extended_immediate_16[29:2], 2'b0};
	assign address_calc = program_counter_plus_4 + immediate_shift_left_2;
	assign next_instruction = PCSrc ? address_calc : program_counter_plus_4;

	///////////////////////////////////////////////////////////////////////////
	//
	//	Data Memory
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
