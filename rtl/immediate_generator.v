// SPDX-License-Identifier: MIT
//
// immediate_generator.v
//
// Extracts and sign-extends the immediate (constant) value embedded inside
// an RV32I instruction. RISC-V does not store immediates in one fixed
// place - the bit positions depend on the instruction FORMAT (I/S/B/U/J),
// because the ISA designers scattered the immediate bits around to keep
// rs1, rs2, rd, funct3, and opcode in the same fixed positions across every
// format (so the register file and decoder logic can stay simple - only
// the immediate extraction differs).
//
// This module is pure combinational logic: given the raw instruction and a
// format selector, it produces the sign-extended 32-bit immediate value.

module immediate_generator (

  input  wire [31:0] instruction,  // the full 32-bit instruction word
  input  wire [2:0]  imm_select,   // which format to decode (from Control Unit)
  output reg  [31:0] immediate     // sign-extended immediate result

  );

  // Format selector codes.
  localparam IMM_I = 3'b000;  // addi, lw, jalr
  localparam IMM_S = 3'b001;  // sw
  localparam IMM_B = 3'b010;  // beq
  localparam IMM_U = 3'b011;  // lui (not required yet, included for completeness)
  localparam IMM_J = 3'b100;  // jal

  always @(*) begin
    case (imm_select)

      // I-type: immediate is one contiguous 12-bit field, instruction[31:20].
      // Sign-extend by replicating the sign bit (instruction[31]) 20 times.
      IMM_I: immediate = {{20{instruction[31]}}, instruction[31:20]};

      // S-type: the 12-bit immediate is SPLIT into two pieces so that rs1,
      // rs2, and funct3 can stay in the same bit positions as every other
      // format. Upper 7 bits live at [31:25], lower 5 bits live at [11:7].
      IMM_S: immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};

      // B-type: 13-bit signed offset, always EVEN (bit 0 is always 0,
      // because branch targets are 2-byte aligned at minimum). The bits are
      // scrambled across the instruction; reassembled here as
      // {imm[12], imm[11], imm[10:5], imm[4:1], 1'b0}.
      IMM_B: immediate = {{19{instruction[31]}}, instruction[31], instruction[7],
                           instruction[30:25], instruction[11:8], 1'b0};

      // U-type: the top 20 bits of the instruction directly become the top
      // 20 bits of the immediate; the bottom 12 bits are zero. Used to
      // build large constants in two instructions (lui + addi).
      IMM_U: immediate = {instruction[31:12], 12'b0};

      // J-type: 21-bit signed offset, always even (bit 0 = 0). Bits are
      // reassembled as {imm[20], imm[19:12], imm[11], imm[10:1], 1'b0}.
      IMM_J: immediate = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                           instruction[20], instruction[30:21], 1'b0};

      default: immediate = 32'd0;

    endcase
  end

endmodule
