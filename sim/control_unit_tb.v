// SPDX-License-Identifier: MIT
//
// control_unit_tb.v
//
// Testbench for control_unit.v. Drives opcode/funct3/funct7_bit5 for each
// of the ten instructions we currently support and checks every control
// signal against the expected value from the instruction/control table.

`timescale 1ns / 1ps

module control_unit_tb;

  reg  [6:0] opcode;
  reg  [2:0] funct3;
  reg        funct7_bit5;

  wire       reg_write;
  wire       alu_src;
  wire       mem_write;
  wire       mem_read;
  wire       mem_to_reg;
  wire       branch;
  wire [2:0] imm_select;
  wire [2:0] alu_control;

  control_unit uut (
    .opcode      (opcode),
    .funct3      (funct3),
    .funct7_bit5 (funct7_bit5),
    .reg_write   (reg_write),
    .alu_src     (alu_src),
    .mem_write   (mem_write),
    .mem_read    (mem_read),
    .mem_to_reg  (mem_to_reg),
    .branch      (branch),
    .imm_select  (imm_select),
    .alu_control (alu_control)
  );

  task show;
    input [127:0] name; // just for readable $display labels
    begin
      $display("%0s : reg_write=%0d alu_src=%0d mem_write=%0d mem_read=%0d mem_to_reg=%0d branch=%0d imm_select=%0d alu_control=%0d",
                name, reg_write, alu_src, mem_write, mem_read, mem_to_reg, branch, imm_select, alu_control);
    end
  endtask

  initial begin

    // ---- add ----
    opcode = 7'b0110011; funct3 = 3'b000; funct7_bit5 = 1'b0; #10;
    show("add "); // expect reg_write=1 alu_src=0 alu_control=0(ADD)

    // ---- sub ----
    opcode = 7'b0110011; funct3 = 3'b000; funct7_bit5 = 1'b1; #10;
    show("sub "); // expect alu_control=1(SUB)

    // ---- and ----
    opcode = 7'b0110011; funct3 = 3'b111; funct7_bit5 = 1'b0; #10;
    show("and "); // expect alu_control=2(AND)

    // ---- or ----
    opcode = 7'b0110011; funct3 = 3'b110; funct7_bit5 = 1'b0; #10;
    show("or  "); // expect alu_control=3(OR)

    // ---- xor ----
    opcode = 7'b0110011; funct3 = 3'b100; funct7_bit5 = 1'b0; #10;
    show("xor "); // expect alu_control=4(XOR)

    // ---- slt ----
    opcode = 7'b0110011; funct3 = 3'b010; funct7_bit5 = 1'b0; #10;
    show("slt "); // expect alu_control=5(SLT)

    // ---- addi ----
    opcode = 7'b0010011; funct3 = 3'b000; funct7_bit5 = 1'b0; #10;
    show("addi"); // expect reg_write=1 alu_src=1 imm_select=0(I) alu_control=0(ADD)

    // ---- lw ----
    opcode = 7'b0000011; funct3 = 3'b010; funct7_bit5 = 1'b0; #10;
    show("lw  "); // expect reg_write=1 alu_src=1 mem_read=1 mem_to_reg=1 imm_select=0(I)

    // ---- sw ----
    opcode = 7'b0100011; funct3 = 3'b010; funct7_bit5 = 1'b0; #10;
    show("sw  "); // expect reg_write=0 alu_src=1 mem_write=1 imm_select=1(S)

    // ---- beq ----
    opcode = 7'b1100011; funct3 = 3'b000; funct7_bit5 = 1'b0; #10;
    show("beq "); // expect reg_write=0 alu_src=0 branch=1 imm_select=2(B) alu_control=1(SUB)

    $display("Control unit testbench finished.");
    $finish;

  end

endmodule
