// SPDX-License-Identifier: MIT
//
// top.v
//
// Top-level module for SIMULATION. It exists as a thin, stable wrapper
// around riscv_core.v for one deliberate reason: riscv_core.v should stay
// a pure, hardware-agnostic CPU, while THIS file is where board-specific
// or simulation-specific concerns get added later without ever touching
// the CPU itself.
//
// Right now (RISC-V simulation stage) top.v does nothing but pass signals
// straight through to riscv_core.v. When we later reach the FPGA stage,
// a DIFFERENT top-level (with switches/LEDs wired to GPIO, no direct
// clk/reset from a testbench but from board pins instead) will replace
// what this file does - riscv_core.v itself won't need to change at all.
// That separation of concerns is why "top" and "core" are different files
// even though, for now, they look almost identical.

module top (

  input  wire clk,
  input  wire reset,

  // Debug signals, useful to observe directly in the waveform without
  // having to dig into the hierarchy (uut.datapath_inst.alu_inst.result
  // etc.) every time.
  output wire [31:0] pc,               // current instruction address
  output wire [31:0] instruction,      // instruction currently executing
  output wire [31:0] alu_result,       // this cycle's ALU output
  output wire        reg_write,        // 1 = this instruction writes a register
  output wire [4:0]  rd_addr,          // which register it writes (if reg_write=1)
  output wire [31:0] reg_write_data,   // the value being written into rd_addr
  output wire        mem_write,        // 1 = this instruction writes data memory (sw)
  output wire [31:0] mem_addr,         // data memory address being accessed
  output wire [31:0] mem_write_data    // value being stored (if mem_write=1)

  );

  riscv_core riscv_core_inst (
    .clk                   (clk),
    .reset                 (reset),
    .pc_debug              (pc),
    .instruction_debug     (instruction),
    .alu_result_debug      (alu_result),
    .reg_write_debug       (reg_write),
    .rd_addr_debug         (rd_addr),
    .reg_write_data_debug  (reg_write_data),
    .mem_write_debug       (mem_write),
    .mem_addr_debug        (mem_addr),
    .mem_write_data_debug  (mem_write_data)
  );

endmodule
