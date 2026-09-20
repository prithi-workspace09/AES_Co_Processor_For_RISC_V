// SPDX-License-Identifier: MIT
//
// riscv_core.v
//
// The complete RISC-V CPU: wires the datapath (Step 7) together with the
// instruction memory (Step 8) and data memory (Step 9) it depends on.
// Nothing new is DECIDED in this file - every control decision already
// happened inside control_unit.v, and every computation already happened
// inside alu.v/regfile.v/immediate_generator.v/program_counter.v. This
// module's only job is PLUMBING: connecting the datapath's memory
// interface ports to the two real memory modules that implement them.
//
// Complete signal flow, one clock cycle:
//   1. datapath outputs `pc`            -> instruction_memory's address input
//   2. instruction_memory outputs `instruction` -> datapath's instruction input
//      (datapath now has everything it needs to decode and execute)
//   3. datapath outputs `mem_addr`, `mem_write_data`, `mem_write`, `mem_read`
//      -> data_memory's address/write_data/mem_write/mem_read inputs
//   4. data_memory outputs `read_data` (asynchronously, same cycle)
//      -> datapath's mem_read_data input, used by the write-back mux for lw
//   5. on the next rising clk edge: the PC register updates, the register
//      file commits any write, and data_memory commits any store - all
//      three of those clocked updates happen simultaneously, and the next
//      cycle begins.

module riscv_core (

  input  wire clk,
  input  wire reset,

  // Debug/observation outputs - not needed for the CPU to function, but
  // very useful for a testbench or ILA (Integrated Logic Analyzer) probe
  // once we reach real hardware.
  output wire [31:0] pc_debug,
  output wire [31:0] instruction_debug,
  output wire [31:0] alu_result_debug,
  output wire        reg_write_debug,
  output wire [4:0]  rd_addr_debug,
  output wire [31:0] reg_write_data_debug,
  output wire        mem_write_debug,
  output wire [31:0] mem_addr_debug,
  output wire [31:0] mem_write_data_debug

  );

  // Wires connecting the datapath to the two memories.
  wire [31:0] pc;
  wire [31:0] instruction;
  wire [31:0] mem_addr;
  wire [31:0] mem_write_data;
  wire        mem_write;
  wire        mem_read;
  wire [31:0] mem_read_data;

  datapath datapath_inst (
    .clk               (clk),
    .reset             (reset),
    .pc                (pc),
    .instruction       (instruction),
    .mem_addr          (mem_addr),
    .mem_write_data    (mem_write_data),
    .mem_write         (mem_write),
    .mem_read          (mem_read),
    .mem_read_data     (mem_read_data),
    .alu_result_debug     (alu_result_debug),
    .reg_write_debug      (reg_write_debug),
    .rd_addr_debug        (rd_addr_debug),
    .reg_write_data_debug (reg_write_data_debug)
  );

  instruction_memory instruction_memory_inst (
    .address     (pc),
    .instruction (instruction)
  );

  data_memory data_memory_inst (
    .clk        (clk),
    .mem_write  (mem_write),
    .mem_read   (mem_read),
    .address    (mem_addr),
    .write_data (mem_write_data),
    .read_data  (mem_read_data)
  );

  assign pc_debug             = pc;
  assign instruction_debug    = instruction;
  assign mem_write_debug      = mem_write;
  assign mem_addr_debug       = mem_addr;
  assign mem_write_data_debug = mem_write_data;

endmodule
