// SPDX-License-Identifier: MIT
//
// regfile_tb.v
//
// Testbench for regfile.v. Checks:
//   1. writing a value and reading it back
//   2. a second register holding a different value at the same time
//   3. x0 refusing to be written (stays 0 no matter what)
//   4. both read ports working at once, independently

`timescale 1ns / 1ps

module regfile_tb;

  reg         clk;
  reg         reg_write;
  reg  [4:0]  rs1_addr;
  reg  [4:0]  rs2_addr;
  reg  [4:0]  rd_addr;
  reg  [31:0] write_data;
  wire [31:0] read_data1;
  wire [31:0] read_data2;

  regfile uut (
    .clk        (clk),
    .reg_write  (reg_write),
    .rs1_addr   (rs1_addr),
    .rs2_addr   (rs2_addr),
    .rd_addr    (rd_addr),
    .write_data (write_data),
    .read_data1 (read_data1),
    .read_data2 (read_data2)
  );

  // Free-running clock: 10ns period (5ns high, 5ns low).
  initial clk = 1'b0;
  always #5 clk = ~clk;

  initial begin

    reg_write = 1'b0;
    rs1_addr  = 5'd0;
    rs2_addr  = 5'd0;
    rd_addr   = 5'd0;
    write_data = 32'd0;

    // ---- Test 1: write 100 into x1, then read it back on port 1 ----
    reg_write  = 1'b1;
    rd_addr    = 5'd1;
    write_data = 32'd100;
    @(posedge clk);   // the write commits on this edge
    #1;               // let the write settle before we change addresses
    reg_write = 1'b0;
    rs1_addr  = 5'd1;
    #1;
    $display("Test1: x1 = %0d (expect 100)", read_data1);

    // ---- Test 2: write 200 into x2, read it back on port 2 ----
    reg_write  = 1'b1;
    rd_addr    = 5'd2;
    write_data = 32'd200;
    @(posedge clk);
    #1;
    reg_write = 1'b0;
    rs2_addr  = 5'd2;
    #1;
    $display("Test2: x2 = %0d (expect 200)", read_data2);

    // ---- Test 3: try to write 999 into x0 - it must stay 0 ----
    reg_write  = 1'b1;
    rd_addr    = 5'd0;
    write_data = 32'd999;
    @(posedge clk);
    #1;
    reg_write = 1'b0;
    rs1_addr  = 5'd0;
    #1;
    $display("Test3: x0 = %0d (expect 0, write to x0 must be ignored)", read_data1);

    // ---- Test 4: read x1 and x2 through both ports AT THE SAME TIME ----
    // Proves the two read ports are independent of each other.
    rs1_addr = 5'd1;
    rs2_addr = 5'd2;
    #1;
    $display("Test4: simultaneous read -> x1=%0d, x2=%0d (expect 100, 200)", read_data1, read_data2);

    // ---- Test 5: reg_write = 0 must not write, even with valid rd_addr ----
    reg_write  = 1'b0;
    rd_addr    = 5'd3;
    write_data = 32'd555;
    @(posedge clk);
    #1;
    rs1_addr = 5'd3;
    #1;
    $display("Test5: x3 = %0d (expect 0, reg_write was low so no write happened)", read_data1);

    $display("Register file testbench finished.");
    $finish;

  end

endmodule
