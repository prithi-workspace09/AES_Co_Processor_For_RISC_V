// SPDX-License-Identifier: MIT
//
// immediate_generator_tb.v
//
// Testbench for immediate_generator.v.
// Each test instruction below was encoded by hand from a real assembly
// line and cross-checked with a Python reference encoder, so the expected
// immediate values are known-correct, not guessed.

`timescale 1ns / 1ps

module immediate_generator_tb;

  reg  [31:0] instruction;
  reg  [2:0]  imm_select;
  wire [31:0] immediate;

  immediate_generator uut (
    .instruction (instruction),
    .imm_select  (imm_select),
    .immediate   (immediate)
  );

  localparam IMM_I = 3'b000;
  localparam IMM_S = 3'b001;
  localparam IMM_B = 3'b010;
  localparam IMM_U = 3'b011;
  localparam IMM_J = 3'b100;

  initial begin

    // ---- I-type: addi x1, x0, 5  ->  0x00500093, imm = 5 ----
    instruction = 32'h00500093; imm_select = IMM_I; #10;
    $display("addi x1,x0,5   : immediate = %0d (expect 5)", $signed(immediate));

    // ---- I-type negative: addi x1, x0, -5  ->  0xFFB00093, imm = -5 ----
    instruction = 32'hFFB00093; imm_select = IMM_I; #10;
    $display("addi x1,x0,-5  : immediate = %0d (expect -5)", $signed(immediate));

    // ---- S-type: sw x2, 8(x1)  ->  0x0020A423, imm = 8 ----
    instruction = 32'h0020A423; imm_select = IMM_S; #10;
    $display("sw x2,8(x1)    : immediate = %0d (expect 8)", $signed(immediate));

    // ---- B-type: beq x1, x2, 8  ->  0x00208463, imm = 8 ----
    instruction = 32'h00208463; imm_select = IMM_B; #10;
    $display("beq x1,x2,8    : immediate = %0d (expect 8)", $signed(immediate));

    // ---- B-type backward branch: beq x1, x2, -4  ->  0xFE208EE3, imm = -4 ----
    instruction = 32'hFE208EE3; imm_select = IMM_B; #10;
    $display("beq x1,x2,-4   : immediate = %0d (expect -4)", $signed(immediate));

    // ---- U-type: lui x5, 0x12345  ->  0x123452B7, imm = 0x12345000 ----
    instruction = 32'h123452B7; imm_select = IMM_U; #10;
    $display("lui x5,0x12345 : immediate = 0x%08h (expect 0x12345000)", immediate);

    // ---- J-type: jal x1, 16  ->  0x010000EF, imm = 16 ----
    instruction = 32'h010000EF; imm_select = IMM_J; #10;
    $display("jal x1,16      : immediate = %0d (expect 16)", $signed(immediate));

    $display("Immediate generator testbench finished.");
    $finish;

  end

endmodule
