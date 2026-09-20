// SPDX-License-Identifier: MIT
//
// datapath_tb.v
//
// Testbench for datapath.v. Instruction memory and data memory don't exist
// yet (Steps 8-9), so this testbench stands in for both with small,
// obviously-correct behavioral models, just to prove the datapath wiring
// itself is correct before we build the real memories.
//
// Test program (machine code cross-checked with a Python reference
// encoder):
//   addr  0: addi x1, x0, 5        x1 = 5
//   addr  4: addi x2, x0, 10       x2 = 10
//   addr  8: add  x3, x1, x2       x3 = 15
//   addr 12: sub  x4, x2, x1       x4 = 5
//   addr 16: and  x5, x1, x2       x5 = 5 & 10 = 0
//   addr 20: or   x6, x1, x2       x6 = 5 | 10 = 15
//   addr 24: xor  x7, x1, x2       x7 = 5 ^ 10 = 15
//   addr 28: sw   x3, 0(x0)        mem[0] = 15
//   addr 32: lw   x8, 0(x0)        x8 = 15
//   addr 36: beq  x1, x1, 8        taken (x1==x1) -> pc jumps to 44
//   addr 40: addi x9, x0, 999      MUST be skipped by the branch
//   addr 44: addi x10, x0, 111     x10 = 111 (branch landed here)

`timescale 1ns / 1ps

module datapath_tb;

  reg clk;
  reg reset;

  wire [31:0] pc;
  reg  [31:0] instruction;

  wire [31:0] mem_addr;
  wire [31:0] mem_write_data;
  wire        mem_write;
  wire        mem_read;
  reg  [31:0] mem_read_data;

  wire [31:0] alu_result_debug;
  wire        reg_write_debug;
  wire [4:0]  rd_addr_debug;

  datapath uut (
    .clk               (clk),
    .reset             (reset),
    .pc                (pc),
    .instruction       (instruction),
    .mem_addr          (mem_addr),
    .mem_write_data    (mem_write_data),
    .mem_write         (mem_write),
    .mem_read          (mem_read),
    .mem_read_data     (mem_read_data),
    .alu_result_debug  (alu_result_debug),
    .reg_write_debug   (reg_write_debug),
    .rd_addr_debug     (rd_addr_debug)
  );

  // ---- Fake instruction memory: combinational lookup by pc ----
  always @(*) begin
    case (pc)
      32'd0 : instruction = 32'h00500093; // addi x1,x0,5
      32'd4 : instruction = 32'h00A00113; // addi x2,x0,10
      32'd8 : instruction = 32'h002081B3; // add  x3,x1,x2
      32'd12: instruction = 32'h40110233; // sub  x4,x2,x1
      32'd16: instruction = 32'h0020F2B3; // and  x5,x1,x2
      32'd20: instruction = 32'h0020E333; // or   x6,x1,x2
      32'd24: instruction = 32'h0020C3B3; // xor  x7,x1,x2
      32'd28: instruction = 32'h00302023; // sw   x3,0(x0)
      32'd32: instruction = 32'h00002403; // lw   x8,0(x0)
      32'd36: instruction = 32'h00108463; // beq  x1,x1,8
      32'd40: instruction = 32'h3E700493; // addi x9,x0,999  (must be skipped)
      32'd44: instruction = 32'h06F00513; // addi x10,x0,111 (branch target)
      default: instruction = 32'h00000013; // addi x0,x0,0 (NOP) past the program
    endcase
  end

  // ---- Fake data memory: one 32-bit word at address 0 ----
  reg [31:0] fake_data_mem;

  always @(*) begin
    mem_read_data = fake_data_mem; // only ever one address used in this test
  end

  always @(posedge clk) begin
    if (mem_write)
      fake_data_mem <= mem_write_data;
  end

  // ---- Clock generation ----
  initial clk = 1'b0;
  always #5 clk = ~clk;

  initial begin

    fake_data_mem = 32'hDEADDEAD; // obviously-wrong seed value, must be overwritten by sw

    reset = 1'b1;
    @(posedge clk); #1;
    reset = 1'b0;

    // Run 12 instructions worth of cycles (one instruction commits per
    // rising edge in this single-cycle design).
    repeat (12) begin
      @(posedge clk); #1;
      $display("t=%0t pc=%0d instr=0x%08h alu_result=%0d reg_write=%0d rd=%0d",
                $time, pc, instruction, alu_result_debug, reg_write_debug, rd_addr_debug);
    end

    // ---- Check final register values directly inside the regfile ----
    $display("---- final register check ----");
    $display("x1  = %0d (expect 5)",   uut.regfile_inst.registers[1]);
    $display("x2  = %0d (expect 10)",  uut.regfile_inst.registers[2]);
    $display("x3  = %0d (expect 15)",  uut.regfile_inst.registers[3]);
    $display("x4  = %0d (expect 5)",   uut.regfile_inst.registers[4]);
    $display("x5  = %0d (expect 0)",   uut.regfile_inst.registers[5]);
    $display("x6  = %0d (expect 15)",  uut.regfile_inst.registers[6]);
    $display("x7  = %0d (expect 15)",  uut.regfile_inst.registers[7]);
    $display("x8  = %0d (expect 15, loaded back from memory)", uut.regfile_inst.registers[8]);
    $display("x9  = %0d (expect 0, MUST be skipped by the branch)", uut.regfile_inst.registers[9]);
    $display("x10 = %0d (expect 111, branch target executed)", uut.regfile_inst.registers[10]);
    $display("mem[0] = %0d (expect 15)", fake_data_mem);

    $display("Datapath testbench finished.");
    $finish;

  end

endmodule
