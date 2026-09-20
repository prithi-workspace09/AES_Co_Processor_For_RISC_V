// SPDX-License-Identifier: MIT
//
// alu.v
//
// 32-bit Arithmetic Logic Unit (ALU) for a single-cycle RV32I processor.
//
// The ALU is the block that does the actual "computing" in the CPU: given
// two 32-bit numbers and an operation code, it produces one 32-bit result.
// It is pure combinational logic (no clock, no memory) - its output changes
// immediately whenever an input changes, just like a calculator with no
// "enter" button.

module alu (

  input  wire  [31:0] a,            // first operand  (e.g. value from register rs1)
  input  wire  [31:0] b,            // second operand (value from rs2, OR the immediate)
  input  wire  [2:0]  alu_control,  // selects which operation to perform
  output reg   [31:0] result,       // 32-bit output of the operation
  output wire          zero          // 1 if result == 0, else 0

  );

  // Operation codes for alu_control.
  // 3 bits is enough because we only need 6 operations right now.
  localparam ALU_ADD = 3'b000;  // a + b
  localparam ALU_SUB = 3'b001;  // a - b
  localparam ALU_AND = 3'b010;  // a & b   (bitwise AND)
  localparam ALU_OR  = 3'b011;  // a | b   (bitwise OR)
  localparam ALU_XOR = 3'b100;  // a ^ b   (bitwise XOR)
  localparam ALU_SLT = 3'b101;  // (signed) a < b ? 1 : 0

  // always @(*) means "re-evaluate this block whenever any input changes" -
  // this is how you describe combinational (not clocked) logic in Verilog.
  always @(*) begin
    case (alu_control)

      ALU_ADD: result = a + b;
      ALU_SUB: result = a - b;
      ALU_AND: result = a & b;
      ALU_OR : result = a | b;
      ALU_XOR: result = a ^ b;

      // RISC-V registers hold signed two's-complement numbers, so SLT
      // ("set less than") must compare them as SIGNED values, not as plain
      // unsigned bit patterns. $signed() tells Verilog to interpret the
      // bits that way for this comparison only.
      ALU_SLT: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;

      // default is required: without it, Verilog would infer a latch
      // (memory) for "result" instead of pure combinational logic, because
      // the case statement would not cover every possible alu_control value.
      default: result = 32'd0;

    endcase
  end

  // zero is 1 exactly when result is all zero bits.
  // This is a single continuous assignment (assign), since it never needs
  // to "remember" anything - it is always just a function of result.
  assign zero = (result == 32'd0);

endmodule
