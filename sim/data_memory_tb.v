// SPDX-License-Identifier: MIT
//
// data_memory_tb.v
//
// Testbench for data_memory.v. Checks:
//   1. an unwritten address reads back as 0 (zero-fill worked)
//   2. sw-style write, then lw-style read-back at the same address
//   3. writes to DIFFERENT addresses land in different words, not aliased
//   4. mem_write = 0 must not modify memory, even with valid address/data

`timescale 1ns / 1ps

module data_memory_tb;

  reg         clk;
  reg         mem_write;
  reg         mem_read;
  reg  [31:0] address;
  reg  [31:0] write_data;
  wire [31:0] read_data;

  data_memory uut (
    .clk        (clk),
    .mem_write  (mem_write),
    .mem_read   (mem_read),
    .address    (address),
    .write_data (write_data),
    .read_data  (read_data)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  initial begin

    mem_write  = 1'b0;
    mem_read   = 1'b0;
    address    = 32'd0;
    write_data = 32'd0;

    // ---- Test 1: address 100 was never written - must read back as 0 ----
    address = 32'd100;
    mem_read = 1'b1;
    #1;
    $display("Test1: mem[100] = %0d (expect 0, never written)", read_data);

    // ---- Test 2: sw x3,0(x0) equivalent - write 15 to address 0, read it back ----
    address    = 32'd0;
    write_data = 32'd15;
    mem_write  = 1'b1;
    @(posedge clk); #1;
    mem_write = 1'b0;
    mem_read  = 1'b1;
    #1;
    $display("Test2: mem[0] = %0d (expect 15)", read_data);

    // ---- Test 3: write a DIFFERENT value to a DIFFERENT address (4) ----
    address    = 32'd4;
    write_data = 32'd77;
    mem_write  = 1'b1;
    @(posedge clk); #1;
    mem_write = 1'b0;
    #1;
    $display("Test3a: mem[4] = %0d (expect 77)", read_data);

    // Confirm address 0 was NOT disturbed by the write to address 4.
    address = 32'd0;
    #1;
    $display("Test3b: mem[0] = %0d (expect 15, unchanged by the write to mem[4])", read_data);

    // ---- Test 4: mem_write = 0 must block a write, even with valid data ----
    address    = 32'd8;
    write_data = 32'd999;
    mem_write  = 1'b0;   // deliberately low
    @(posedge clk); #1;
    #1;
    $display("Test4: mem[8] = %0d (expect 0, mem_write was low so no write happened)", read_data);

    $display("Data memory testbench finished.");
    $finish;

  end

endmodule
