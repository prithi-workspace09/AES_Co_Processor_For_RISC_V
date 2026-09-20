// SPDX-License-Identifier: MIT
//
// control_unit.v
//
// The Control Unit is the "decision maker" of the CPU: it looks at the
// opcode (and, for some instructions, funct3/funct7) and decides how every
// other module should behave THIS cycle - whether to write a register,
// read/write memory, which ALU operation to run, and which immediate
// format to decode.
//
// It is pure combinational logic: for a given instruction, its outputs are
// fixed, with no memory of past cycles.
//
// This decoder currently supports exactly the instructions we plan to run:
//   R-type : add, sub, and, or, xor, slt
//   I-type : addi
//   Load   : lw
//   Store  : sw
//   Branch : beq
// JAL/JALR are intentionally NOT here yet - the roadmap adds them in a
// later step, and a decoder should only cover the instructions actually
// being used, not every RV32I instruction that theoretically exists.

module control_unit (

  input  wire [6:0] opcode,        // instruction[6:0]  - identifies instruction family
  input  wire [2:0] funct3,        // instruction[14:12] - narrows down the operation
  input  wire       funct7_bit5,   // instruction[30] - distinguishes add/sub (and srl/sra)

  output reg        reg_write,     // 1 = write ALU/memory result back into rd
  output reg        alu_src,       // 0 = ALU's 2nd operand is rs2, 1 = it's the immediate
  output reg        mem_write,     // 1 = store ALU result address's data into memory (sw)
  output reg        mem_read,      // 1 = read from memory at ALU result address (lw)
  output reg        mem_to_reg,    // 1 = write-back value comes from memory, not the ALU
  output reg        branch,        // 1 = this is a conditional branch (beq)
  output reg  [2:0] imm_select,    // which immediate format to decode
  output reg  [2:0] alu_control    // which ALU operation to perform

  );

  // Opcodes (instruction[6:0]) for the instructions we support.
  localparam OP_RTYPE  = 7'b0110011;  // add, sub, and, or, xor, slt
  localparam OP_ITYPE  = 7'b0010011;  // addi
  localparam OP_LOAD   = 7'b0000011;  // lw
  localparam OP_STORE  = 7'b0100011;  // sw
  localparam OP_BRANCH = 7'b1100011;  // beq

  // Must match the encoding used in alu.v.
  localparam ALU_ADD = 3'b000;
  localparam ALU_SUB = 3'b001;
  localparam ALU_AND = 3'b010;
  localparam ALU_OR  = 3'b011;
  localparam ALU_XOR = 3'b100;
  localparam ALU_SLT = 3'b101;

  // Must match the encoding used in immediate_generator.v.
  localparam IMM_I = 3'b000;
  localparam IMM_S = 3'b001;
  localparam IMM_B = 3'b010;

  always @(*) begin

    // Safe defaults: an unrecognized instruction does nothing (no register
    // write, no memory write) instead of doing something unpredictable.
    reg_write   = 1'b0;
    alu_src     = 1'b0;
    mem_write   = 1'b0;
    mem_read    = 1'b0;
    mem_to_reg  = 1'b0;
    branch      = 1'b0;
    imm_select  = IMM_I;
    alu_control = ALU_ADD;

    case (opcode)

      OP_RTYPE: begin
        reg_write = 1'b1;
        alu_src   = 1'b0;  // both operands come from registers
        // funct3 alone selects the operation, except add/sub which share
        // funct3=000 and are only told apart by funct7 bit 5 (instr[30]).
        case (funct3)
          3'b000:  alu_control = funct7_bit5 ? ALU_SUB : ALU_ADD; // sub : add
          3'b100:  alu_control = ALU_XOR;
          3'b110:  alu_control = ALU_OR;
          3'b111:  alu_control = ALU_AND;
          3'b010:  alu_control = ALU_SLT;
          default: alu_control = ALU_ADD;
        endcase
      end

      OP_ITYPE: begin // addi
        reg_write   = 1'b1;
        alu_src     = 1'b1;      // 2nd ALU operand is the sign-extended immediate
        imm_select  = IMM_I;
        alu_control = ALU_ADD;
      end

      OP_LOAD: begin // lw
        reg_write   = 1'b1;
        alu_src     = 1'b1;      // address = rs1 + immediate
        imm_select  = IMM_I;
        mem_read    = 1'b1;
        mem_to_reg  = 1'b1;      // write-back value comes from data memory
        alu_control = ALU_ADD;
      end

      OP_STORE: begin // sw
        alu_src     = 1'b1;      // address = rs1 + immediate
        imm_select  = IMM_S;
        mem_write   = 1'b1;
        alu_control = ALU_ADD;
      end

      OP_BRANCH: begin // beq
        alu_src     = 1'b0;      // compare rs1 directly against rs2
        imm_select  = IMM_B;
        branch      = 1'b1;
        alu_control = ALU_SUB;   // ALU's zero flag tells us rs1 == rs2
      end

      default: ; // unrecognized opcode: keep the safe defaults above

    endcase
  end

endmodule
