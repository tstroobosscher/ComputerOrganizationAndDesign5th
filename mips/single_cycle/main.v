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

	wire RegDst;
	wire Branch;
	wire MemRead;
	wire MemToReg;
	wire [1:0] AluOP;
	wire MemWrite;
	wire ALUSrc;
	wire RegWrite;

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

	wire [31:0] instruction;

	inst_mem_64x32 inst_mem(
		ra(program_counter),
		rd(instruction)
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
		clk(clk),
		ra1(instruction[25:21]),
		ra2(instruction[20:16]),
		wa(write_address),
		wd(write_data),
		rd1(read_data_1),
		rd2(read_data_1),
		regwrite(RegWrite)
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

	wire alu_control;
	// TODO assign alucont

	wire [31:0] alu_input_1;
	wire [31:0] alu_input_2;
	wire [31:0] alu_result;
	wire alu_zero;

	assign alu_input_1 = read_data_1;
	assign alu_input_2 = ALUSrc ? sign_extended_immediate_16 : read_data_2;

	alu alu(
		alucont(alu_control),
		rd1(alu_input_1),
		rd2(alu_input_2),
		res(alu_result),
		zero(alu_zero)
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

	data_mem_64x32 data_mem(
		.clk(clk),
		.addr(alu_result),
		.rd(data_mem_data),
		.wd(read_data_2),
		.memwrite(MemWrite),
		.memread(MemRead)
		);

	assign write_data = MemToReg ? data_mem_data : alu_result;

endmodule
