// SPDX-License-Identifier: MIT
//
// riscv_tb.v
//
// The formal, top-level testbench for the whole CPU. Everything built in
// Steps 2-11 gets exercised together here, running the real test program
// (Step 12) through the real top.v wrapper - no more fake stand-in
// memories, no more per-module isolation. This is the single testbench
// you run to confirm "the RISC-V core works," end to end.

`timescale 1ns / 1ps

module riscv_tb;

  reg clk;
  reg reset;

  wire [31:0] pc;
  wire [31:0] instruction;
  wire [31:0] alu_result;
  wire        reg_write;
  wire [4:0]  rd_addr;
  wire [31:0] reg_write_data;
  wire        mem_write;
  wire [31:0] mem_addr;
  wire [31:0] mem_write_data;

  top uut (
    .clk             (clk),
    .reset           (reset),
    .pc              (pc),
    .instruction     (instruction),
    .alu_result      (alu_result),
    .reg_write       (reg_write),
    .rd_addr         (rd_addr),
    .reg_write_data  (reg_write_data),
    .mem_write       (mem_write),
    .mem_addr        (mem_addr),
    .mem_write_data  (mem_write_data)
  );

  // ---- Clock generation ----
  // #5 half-period -> 10ns full period. This is purely a simulation-time
  // choice (see the clock-divider discussion after Step 11) - it is NOT
  // tied to any real oscillator yet; that only matters once we reach the
  // FPGA stage.
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // ---- Reset generation ----
  // Hold reset high for two full clock edges before releasing it, giving
  // the PC register a clean, unambiguous start at address 0.
  initial begin
    reset = 1'b1;
    @(posedge clk);
    @(posedge clk);
    // Non-blocking on purpose: this deassertion and program_counter.v's
    // own reset check both trigger on this same clock edge, from two
    // separate initial/always blocks. A blocking assign here is a race
    // (which one 'wins' is simulator-defined, not spec-defined) - the
    // non-blocking form guarantees every block sees the OLD value of
    // reset during this edge's evaluation, and only the NEXT edge sees
    // it cleared, identically across every compliant simulator.
    reset <= 1'b0;
  end

  // ---- Continuous signal monitor ----
  // $monitor prints ONE line per simulation time step in which any of its
  // listed signals changed, automatically, for as long as the simulation
  // runs - unlike $display, which only prints once, at the exact line
  // it's written. This gives a full cycle-by-cycle trace without having to
  // manually call $display after every clock edge.
  initial begin
    $monitor("t=%0t reset=%0d pc=%0d instr=0x%08h alu_result=%0d reg_write=%0d rd=%0d reg_write_data=%0d mem_write=%0d",
              $time, reset, pc, instruction, alu_result, reg_write, rd_addr, reg_write_data, mem_write);
  end

  // ---- Waveform dump (VCD format) ----
  // Vivado's own waveform viewer records signals natively and does not
  // strictly need this, but $dumpfile/$dumpvars are standard Verilog and
  // work in Vivado's simulator (XSim) too, producing a portable .vcd file
  // that can also be opened in GTKWave or other third-party viewers.
  initial begin
    $dumpfile("riscv_tb.vcd");
    $dumpvars(0, riscv_tb);
  end

  // ---- Run the program, then check final results ----
  initial begin

    // Reset takes 20ns (2 cycles), the 13-instruction program takes
    // another 130ns (13 cycles) to fully commit, so 200ns leaves a
    // comfortable margin to observe the CPU settle into NOPs afterward.
    #200;

    $display("-----------------------------------------------");
    $display(" Final register check ");
    $display("-----------------------------------------------");
    $display("x1  = %0d (expect 5)",   uut.riscv_core_inst.datapath_inst.regfile_inst.registers[1]);
    $display("x2  = %0d (expect 10)",  uut.riscv_core_inst.datapath_inst.regfile_inst.registers[2]);
    $display("x3  = %0d (expect 15)",  uut.riscv_core_inst.datapath_inst.regfile_inst.registers[3]);
    $display("x4  = %0d (expect 5)",   uut.riscv_core_inst.datapath_inst.regfile_inst.registers[4]);
    $display("x5  = %0d (expect 0)",   uut.riscv_core_inst.datapath_inst.regfile_inst.registers[5]);
    $display("x6  = %0d (expect 15)",  uut.riscv_core_inst.datapath_inst.regfile_inst.registers[6]);
    $display("x7  = %0d (expect 15)",  uut.riscv_core_inst.datapath_inst.regfile_inst.registers[7]);
    $display("x8  = %0d (expect 15, loaded back from memory)", uut.riscv_core_inst.datapath_inst.regfile_inst.registers[8]);
    $display("x9  = %0d (expect 0, must be skipped by the branch)", uut.riscv_core_inst.datapath_inst.regfile_inst.registers[9]);
    $display("x10 = %0d (expect 111, branch target executed)", uut.riscv_core_inst.datapath_inst.regfile_inst.registers[10]);
    $display("x11 = %0d (expect 1, slt: 5 < 10 is true)", uut.riscv_core_inst.datapath_inst.regfile_inst.registers[11]);
    $display("mem[0] = %0d (expect 15)", uut.riscv_core_inst.data_memory_inst.mem[0]);
    $display("-----------------------------------------------");

    $finish;

  end

endmodule
