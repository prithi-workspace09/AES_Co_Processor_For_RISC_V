// SPDX-License-Identifier: MIT
//
// instruction_memory_tb.v
//
// Testbench for instruction_memory.v. Checks that every address in our
// 12-instruction test program returns the exact instruction word we
// expect (same program used in datapath_tb.v / Step 7), and that an
// address past the end of the program returns a NOP rather than garbage.

`timescale 1ns / 1ps

module instruction_memory_tb;

  reg  [31:0] address;
  wire [31:0] instruction;

  instruction_memory uut (
    .address     (address),
    .instruction (instruction)
  );

  task check;
    input [31:0] addr;
    input [31:0] expected;
    begin
      address = addr;
      #1;
      if (instruction === expected)
        $display("PASS  address=%0d  instruction=0x%08h", addr, instruction);
      else
        $display("FAIL  address=%0d  instruction=0x%08h  (expected 0x%08h)", addr, instruction, expected);
    end
  endtask

  initial begin

    check(32'd0,  32'h00500093); // addi x1,x0,5
    check(32'd4,  32'h00A00113); // addi x2,x0,10
    check(32'd8,  32'h002081B3); // add  x3,x1,x2
    check(32'd12, 32'h40110233); // sub  x4,x2,x1
    check(32'd16, 32'h0020F2B3); // and  x5,x1,x2
    check(32'd20, 32'h0020E333); // or   x6,x1,x2
    check(32'd24, 32'h0020C3B3); // xor  x7,x1,x2
    check(32'd28, 32'h00302023); // sw   x3,0(x0)
    check(32'd32, 32'h00002403); // lw   x8,0(x0)
    check(32'd36, 32'h00108463); // beq  x1,x1,8
    check(32'd40, 32'h3E700493); // addi x9,x0,999
    check(32'd44, 32'h06F00513); // addi x10,x0,111

    // Past the end of the loaded program - must be a NOP, not garbage.
    check(32'd48,  32'h00000013);
    check(32'd200, 32'h00000013);

    $display("Instruction memory testbench finished.");
    $finish;

  end

endmodule
