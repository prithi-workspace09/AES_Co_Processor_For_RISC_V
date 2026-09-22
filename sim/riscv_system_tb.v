// SPDX-License-Identifier: MIT
//
// riscv_system_tb.v
//
// SYSTEM-LEVEL demonstration testbench for the complete, unmodified
// RISC-V processor (top.v). This exercises the REAL hierarchy exactly as
// built - no bypassed modules, no substituted logic, no shortcut signals:
//
//   top.v
//    `-- riscv_core_inst (riscv_core.v)
//         |-- datapath_inst (datapath.v)
//         |    |-- control_unit_inst (control_unit.v)
//         |    |-- regfile_inst (regfile.v)
//         |    |-- immediate_generator_inst (immediate_generator.v)
//         |    |-- alu_inst (alu.v)
//         |    `-- program_counter_inst (program_counter.v)
//         |-- instruction_memory_inst (instruction_memory.v)
//         `-- data_memory_inst (data_memory.v)
//
// Every internal signal displayed below is read via a hierarchical
// reference straight into the real instance names above (the same names
// Vivado's Elaborated Design view shows) - nothing here is a new wire
// that changes behavior, it's read-only observation for the console trace.
//
// This is a companion to sim/riscv_tb.v (the formal pass/fail sign-off
// testbench from Step 13), not a replacement for it - riscv_tb.v is left
// untouched. This file exists specifically to produce a narrated,
// cycle-by-cycle explanation suitable for a live demonstration, with a
// strong focus on the Program Counter's behavior (fetch address this
// cycle, and the next-PC decision that determines the following cycle),
// per the requirement to prove sequential (and correctly redirected)
// instruction flow.

`timescale 1ns / 1ps

module riscv_system_tb;

  // ---- Clock / reset, and top.v's own ports ----
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

  // The DUT: the real, unmodified top.v.
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

  // ---- Internal signals, pulled by hierarchical reference for display ----
  // (read-only observation - these are the ACTUAL wires already inside
  // datapath.v, addressed by their real names, not new logic)
  wire [6:0]  opcode         = uut.riscv_core_inst.datapath_inst.opcode;
  wire [2:0]  funct3         = uut.riscv_core_inst.datapath_inst.funct3;
  wire        funct7_bit5    = uut.riscv_core_inst.datapath_inst.funct7_bit5;
  wire [4:0]  rs1_addr       = uut.riscv_core_inst.datapath_inst.rs1_addr;
  wire [4:0]  rs2_addr       = uut.riscv_core_inst.datapath_inst.rs2_addr;
  wire [31:0] read_data1     = uut.riscv_core_inst.datapath_inst.read_data1;
  wire [31:0] read_data2     = uut.riscv_core_inst.datapath_inst.read_data2;
  wire [31:0] immediate      = uut.riscv_core_inst.datapath_inst.immediate;
  wire [2:0]  alu_control    = uut.riscv_core_inst.datapath_inst.ctrl_alu_control;
  wire [31:0] alu_operand_b  = uut.riscv_core_inst.datapath_inst.alu_operand_b;
  wire        ctrl_alu_src   = uut.riscv_core_inst.datapath_inst.ctrl_alu_src;
  wire        ctrl_mem_to_reg = uut.riscv_core_inst.datapath_inst.ctrl_mem_to_reg;
  wire        ctrl_branch    = uut.riscv_core_inst.datapath_inst.ctrl_branch;
  wire        mem_read       = uut.riscv_core_inst.datapath_inst.mem_read;
  wire [31:0] mem_read_data  = uut.riscv_core_inst.datapath_inst.mem_read_data;
  wire [31:0] pc_next        = uut.riscv_core_inst.datapath_inst.pc_next;
  wire [31:0] pc_plus4       = uut.riscv_core_inst.datapath_inst.pc_plus4;
  wire [31:0] pc_branch_target = uut.riscv_core_inst.datapath_inst.pc_branch_target;
  wire        branch_taken   = uut.riscv_core_inst.datapath_inst.branch_taken;

  // ---- Clock generation ----
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // ---- Reset generation: held for 2 full cycles before release ----
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

  // ---- Instruction mnemonic decoder, for readable console output only ----
  // (this is testbench-side decoding for display purposes - it duplicates
  // NO logic from control_unit.v; control_unit.v's actual decoding is what
  // drives the real control signals printed alongside this label)
  function [63:0] decode_op;
    input [6:0] f_opcode;
    input [2:0] f_funct3;
    input       f_funct7_bit5;
    begin
      case (f_opcode)
        7'b0110011: begin
          case (f_funct3)
            3'b000:  decode_op = f_funct7_bit5 ? "SUB" : "ADD";
            3'b111:  decode_op = "AND";
            3'b110:  decode_op = "OR";
            3'b100:  decode_op = "XOR";
            3'b010:  decode_op = "SLT";
            default: decode_op = "R-??";
          endcase
        end
        7'b0010011: decode_op = "ADDI";
        7'b0000011: decode_op = "LW";
        7'b0100011: decode_op = "SW";
        7'b1100011: decode_op = "BEQ";
        default:    decode_op = "NOP";
      endcase
    end
  endfunction

  integer cycle_count;

  task print_cycle;
    begin
      cycle_count = cycle_count + 1;
      $display("----------------------------------------------------");
      $display("Cycle %0d   (t=%0t ns)", cycle_count, $time);
      $display("----------------------------------------------------");
      $display("PC          = %08h", pc);
      $display("Instruction = %08h   [%0s]", instruction, decode_op(opcode, funct3, funct7_bit5));
      // Real assembly-style operand syntax, per instruction FORMAT - not
      // every instruction uses rs2 or the immediate (e.g. R-type has no
      // immediate; I-type has no real rs2 field, those bits are part of
      // its immediate). The Control/ALU/Memory lines below still show
      // every raw signal value regardless of format, since the hardware
      // itself computes them every cycle whether or not they're used
      // (Step 4/7's "immediate generator and register file always run"
      // point) - this line just avoids printing a misleading "operand"
      // for a field the instruction doesn't actually have.
      case (opcode)
        7'b0110011: $display("Operation   = %0s x%0d, x%0d, x%0d",
                              decode_op(opcode, funct3, funct7_bit5), rd_addr, rs1_addr, rs2_addr);
        7'b0010011: $display("Operation   = ADDI x%0d, x%0d, %0d", rd_addr, rs1_addr, $signed(immediate));
        7'b0000011: $display("Operation   = LW x%0d, %0d(x%0d)", rd_addr, $signed(immediate), rs1_addr);
        7'b0100011: $display("Operation   = SW x%0d, %0d(x%0d)", rs2_addr, $signed(immediate), rs1_addr);
        7'b1100011: $display("Operation   = BEQ x%0d, x%0d, %0d", rs1_addr, rs2_addr, $signed(immediate));
        default:    $display("Operation   = NOP (unrecognized opcode)");
      endcase
      $display("Control     : RegWrite=%0d ALUSrc=%0d MemWrite=%0d MemRead=%0d MemToReg=%0d Branch=%0d",
                reg_write, ctrl_alu_src, mem_write, mem_read, ctrl_mem_to_reg, ctrl_branch);
      $display("ALU         : a=%0d  alu_control=%0d  b=%0d  ->  result=%0d",
                $signed(read_data1), alu_control, $signed(alu_operand_b), $signed(alu_result));
      if (mem_write || mem_read)
        $display("Memory      : addr=%0d  write_data=%0d  read_data=%0d",
                  mem_addr, mem_write_data, mem_read_data);
      else
        $display("Memory      : (not accessed this cycle)");
      if (reg_write)
        $display("Write-back  : x%0d <= %0d", rd_addr, $signed(reg_write_data));
      else
        $display("Write-back  : (none - this instruction does not write a register)");
      $display("Next PC     : branch_taken=%0d  ->  pc_next = %0d   (pc_plus4=%0d, branch_target=%0d)",
                branch_taken, pc_next, pc_plus4, pc_branch_target);
      $display("");
    end
  endtask

  integer i;
  integer pass;

  initial begin

    cycle_count = 0;
    pass = 1;

    $display("====================================================");
    $display("RISC-V SYSTEM LEVEL SIMULATION");
    $display("====================================================");
    $display("");

    // Wait for reset to fully release before narrating cycles - the two
    // reset cycles themselves are not part of the instruction trace.
    @(posedge clk);
    @(posedge clk);
    #1;

    // Narrate one cycle per posedge for the full 13-instruction program,
    // plus 2 extra cycles to show the CPU safely idling on NOPs afterward.
    for (i = 0; i < 15; i = i + 1) begin
      print_cycle;
      @(posedge clk);
      #1;
    end

    $display("====================================================");
    $display("FINAL PROCESSOR STATE");
    $display("====================================================");
    $display("");

    check_reg(1,  5);
    check_reg(2,  10);
    check_reg(3,  15);
    check_reg(4,  5);
    check_reg(5,  0);
    check_reg(6,  15);
    check_reg(7,  15);
    check_reg(8,  15);
    check_reg(9,  0);
    check_reg(10, 111);
    check_reg(11, 1);
    check_mem(0,  15);

    $display("");
    $display("====================================================");
    if (pass)
      $display("RESULT: PASS - complete RISC-V processor verified end-to-end");
    else
      $display("RESULT: FAIL - see mismatches above");
    $display("====================================================");

    $finish;
  end

  task check_reg;
    input [4:0]  reg_num;
    input [31:0] expected;
    reg   [31:0] actual;
    begin
      actual = uut.riscv_core_inst.datapath_inst.regfile_inst.registers[reg_num];
      if (actual === expected) begin
        $display("Register x%0d = %0d   (expected %0d)   PASS", reg_num, $signed(actual), $signed(expected));
      end else begin
        $display("Register x%0d = %0d   (expected %0d)   *** FAIL ***", reg_num, $signed(actual), $signed(expected));
        pass = 0;
      end
    end
  endtask

  task check_mem;
    input [31:0] addr_word;
    input [31:0] expected;
    reg   [31:0] actual;
    begin
      actual = uut.riscv_core_inst.data_memory_inst.mem[addr_word];
      if (actual === expected) begin
        $display("Memory[%0d]  = %0d   (expected %0d)   PASS", addr_word, $signed(actual), $signed(expected));
      end else begin
        $display("Memory[%0d]  = %0d   (expected %0d)   *** FAIL ***", addr_word, $signed(actual), $signed(expected));
        pass = 0;
      end
    end
  endtask

endmodule
