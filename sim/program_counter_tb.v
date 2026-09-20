// SPDX-License-Identifier: MIT
//
// program_counter_tb.v
//
// Testbench for program_counter.v.
// Since the real next-PC mux (PC+4 vs. branch vs. jump) lives in the
// datapath, not in this module, the testbench drives pc_next by hand to
// exercise both behaviors: normal sequential increment, and an external
// "jump" (as if a branch/jump had just been resolved).

`timescale 1ns / 1ps

module program_counter_tb;

  reg         clk;
  reg         reset;
  reg  [31:0] pc_next;
  wire [31:0] pc;
  wire [31:0] pc_plus4;

  program_counter uut (
    .clk      (clk),
    .reset    (reset),
    .pc_next  (pc_next),
    .pc       (pc),
    .pc_plus4 (pc_plus4)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  initial begin

    // ---- Test 1: reset must force pc to 0 ----
    reset   = 1'b1;
    pc_next = 32'hDEADBEEF;  // deliberately garbage, to prove reset wins
    @(posedge clk); #1;
    $display("Test1: after reset, pc = 0x%08h (expect 0x00000000)", pc);

    // ---- Test 2: release reset, walk PC forward using pc_plus4 ----
    // This mimics what the datapath will do every normal cycle: feed
    // pc_plus4 back into pc_next.
    reset = 1'b0;

    pc_next = pc_plus4;      // pc is currently 0, so pc_plus4 = 4
    @(posedge clk); #1;
    $display("Test2a: pc = %0d (expect 4)", pc);

    pc_next = pc_plus4;      // pc is now 4, so pc_plus4 = 8
    @(posedge clk); #1;
    $display("Test2b: pc = %0d (expect 8)", pc);

    pc_next = pc_plus4;      // pc is now 8, so pc_plus4 = 12
    @(posedge clk); #1;
    $display("Test2c: pc = %0d (expect 12)", pc);

    // ---- Test 3: simulate a taken branch/jump loading an arbitrary target ----
    pc_next = 32'd100;       // as if control logic resolved a branch to address 100
    @(posedge clk); #1;
    $display("Test3: pc = %0d (expect 100, simulating a taken branch)", pc);

    // ---- Test 4: normal increment resumes correctly after the jump ----
    pc_next = pc_plus4;      // pc is now 100, so pc_plus4 = 104
    @(posedge clk); #1;
    $display("Test4: pc = %0d (expect 104)", pc);

    $display("Program counter testbench finished.");
    $finish;

  end

endmodule
