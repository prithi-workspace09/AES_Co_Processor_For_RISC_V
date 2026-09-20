// SPDX-License-Identifier: MIT
//
// alu_tb.v
//
// Simple testbench for alu.v.
// A testbench is not synthesized into hardware - it only exists in
// simulation, to drive inputs into the design and check that the outputs
// come out correct. `timescale` sets the unit of time used by #10 etc.
// below: 1ns per unit, with 1ps simulation precision.

`timescale 1ns / 1ps

module alu_tb;

  // reg: things WE (the testbench) drive - our stimulus
  reg  [31:0] a;
  reg  [31:0] b;
  reg  [2:0]  alu_control;

  // wire: things the ALU drives - what we observe
  wire [31:0] result;
  wire        zero;

  // Instantiate the ALU under test. "uut" = Unit Under Test, a common name.
  alu uut (
    .a           (a),
    .b           (b),
    .alu_control (alu_control),
    .result      (result),
    .zero        (zero)
  );

  initial begin

    $display("time  op    a            b            result       zero");

    // ---- ADD: 10 + 5 = 15 ----
    a = 32'd10; b = 32'd5; alu_control = 3'b000; #10;
    $display("%0t\tADD\t%0d\t%0d\t%0d\t%0d", $time, a, b, result, zero);

    // ---- SUB: 10 - 5 = 5 ----
    a = 32'd10; b = 32'd5; alu_control = 3'b001; #10;
    $display("%0t\tSUB\t%0d\t%0d\t%0d\t%0d", $time, a, b, result, zero);

    // ---- SUB with equal operands: 5 - 5 = 0, zero should go high ----
    // This is exactly the case BEQ relies on later.
    a = 32'd5; b = 32'd5; alu_control = 3'b001; #10;
    $display("%0t\tSUB\t%0d\t%0d\t%0d\t%0d  <- zero flag, this is what BEQ checks", $time, a, b, result, zero);

    // ---- AND: 0xFF & 0x0F = 0x0F ----
    a = 32'hFF; b = 32'h0F; alu_control = 3'b010; #10;
    $display("%0t\tAND\t%0h\t%0h\t%0h\t%0d", $time, a, b, result, zero);

    // ---- OR: 0xF0 | 0x0F = 0xFF ----
    a = 32'hF0; b = 32'h0F; alu_control = 3'b011; #10;
    $display("%0t\tOR \t%0h\t%0h\t%0h\t%0d", $time, a, b, result, zero);

    // ---- XOR: 0xFF ^ 0x0F = 0xF0 ----
    a = 32'hFF; b = 32'h0F; alu_control = 3'b100; #10;
    $display("%0t\tXOR\t%0h\t%0h\t%0h\t%0d", $time, a, b, result, zero);

    // ---- SLT: 3 < 7  -> true  -> result = 1 ----
    a = 32'd3; b = 32'd7; alu_control = 3'b101; #10;
    $display("%0t\tSLT\t%0d\t%0d\t%0d\t%0d", $time, a, b, result, zero);

    // ---- SLT: 7 < 3  -> false -> result = 0 ----
    a = 32'd7; b = 32'd3; alu_control = 3'b101; #10;
    $display("%0t\tSLT\t%0d\t%0d\t%0d\t%0d", $time, a, b, result, zero);

    // ---- SLT with a NEGATIVE number: -1 < 1 -> true -> result = 1 ----
    // This checks that the comparison is SIGNED, not unsigned.
    // As an unsigned 32-bit number, -1 is 0xFFFFFFFF, which is huge -
    // if the comparison were unsigned, this would (wrongly) say -1 is NOT less than 1.
    a = -32'd1; b = 32'd1; alu_control = 3'b101; #10;
    $display("%0t\tSLT\t%0d\t%0d\t%0d\t%0d  <- signed comparison check (a = -1)", $time, $signed(a), b, result, zero);

    $display("ALU testbench finished.");
    $finish;

  end

endmodule
