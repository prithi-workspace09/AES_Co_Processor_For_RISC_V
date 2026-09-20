// SPDX-License-Identifier: MIT
//
// datapath.v
//
// Wires together everything built so far - Program Counter, Register File,
// Immediate Generator, ALU, and Control Unit - into a complete single-cycle
// CPU datapath. Instruction memory and data memory are NOT instantiated
// here: this module only exposes ports for them (Steps 8 and 9 build the
// actual memories; Step 10, riscv_core.v, connects everything).
//
// Block diagram (data flows left to right, control signals flow top-down
// from control_unit into the muxes/enables they steer):
//
//                    +-----------------+
//        +---------->|  Instr. Memory  |----+   (external, Step 8)
//        |  pc       +-----------------+    | instruction
//        |                                   v
//  +------------+                    +----------------+
//  |    PC      |                    |  Control Unit  |
//  | (register) |                    +----------------+
//  +------------+                     |  |  |  |   |  |
//        ^  pc_plus4                  |  |  |  |   |  |
//        |                       reg_write | mem_read | branch
//        |                        alu_src  mem_write mem_to_reg
//        |                            |  |  |  |   |  |
//  branch_target = pc + imm           v  v  v  v   v  v
//        ^                    +--------------------------+
//        |                    |      Register File       |
//   pc_next mux <--- zero     |  rs1 --> read_data1       |
//   (branch ? target : +4)    |  rs2 --> read_data2       |
//                              +--------------------------+
//                                |read_data1      |read_data2
//                                |                 |
//                        +---------------+         |
//         instruction -->| Immediate Gen |         |
//                        +---------------+         |
//                                | immediate        |
//                                v                   |
//                          ALUSrc mux (imm vs read_data2)
//                                |                   |
//                                v                   v
//                            +--------+       (also goes to
//                            |  ALU   |        data memory as
//                            +--------+        the store value)
//                                | result, zero
//                                v
//                       +-------------------+
//                       |   Data Memory     |  (external, Step 9)
//                       +-------------------+
//                                | mem_read_data
//                                v
//                       MemtoReg mux (mem_read_data vs alu result)
//                                |
//                                v
//                        write_data (back into rd)

module datapath (

  input  wire        clk,
  input  wire        reset,

  // Instruction memory interface
  output wire [31:0] pc,              // address to fetch from instruction memory
  input  wire [31:0] instruction,     // instruction word fetched at that address

  // Data memory interface
  output wire [31:0] mem_addr,        // address for load/store (ALU result)
  output wire [31:0] mem_write_data,  // value to store (always read_data2)
  output wire        mem_write,       // 1 = this cycle is a store (sw)
  output wire        mem_read,        // 1 = this cycle is a load (lw)
  input  wire [31:0] mem_read_data,   // value loaded back from data memory

  // Debug/observation outputs - handy for the testbench and waveform, not
  // needed for the CPU to function.
  output wire [31:0] alu_result_debug,
  output wire        reg_write_debug,
  output wire [4:0]  rd_addr_debug,
  output wire [31:0] reg_write_data_debug

  );

  //-----------------------------------------------------------------
  // Instruction field extraction
  //-----------------------------------------------------------------
  // These are just wire slices of the instruction word - no logic, just
  // naming the fixed bit positions the RV32I formats agree on.
  wire [6:0] opcode      = instruction[6:0];
  wire [4:0] rd_addr     = instruction[11:7];
  wire [2:0] funct3      = instruction[14:12];
  wire [4:0] rs1_addr    = instruction[19:15];
  wire [4:0] rs2_addr    = instruction[24:20];
  wire       funct7_bit5 = instruction[30];

  //-----------------------------------------------------------------
  // Control Unit
  //-----------------------------------------------------------------
  wire        ctrl_reg_write;
  wire        ctrl_alu_src;
  wire        ctrl_mem_write;
  wire        ctrl_mem_read;
  wire        ctrl_mem_to_reg;
  wire        ctrl_branch;
  wire [2:0]  ctrl_imm_select;
  wire [2:0]  ctrl_alu_control;

  control_unit control_unit_inst (
    .opcode      (opcode),
    .funct3      (funct3),
    .funct7_bit5 (funct7_bit5),
    .reg_write   (ctrl_reg_write),
    .alu_src     (ctrl_alu_src),
    .mem_write   (ctrl_mem_write),
    .mem_read    (ctrl_mem_read),
    .mem_to_reg  (ctrl_mem_to_reg),
    .branch      (ctrl_branch),
    .imm_select  (ctrl_imm_select),
    .alu_control (ctrl_alu_control)
  );

  //-----------------------------------------------------------------
  // Register File
  //-----------------------------------------------------------------
  wire [31:0] read_data1;
  wire [31:0] read_data2;
  wire [31:0] write_back_data;

  regfile regfile_inst (
    .clk        (clk),
    .reg_write  (ctrl_reg_write),
    .rs1_addr   (rs1_addr),
    .rs2_addr   (rs2_addr),
    .rd_addr    (rd_addr),
    .write_data (write_back_data),
    .read_data1 (read_data1),
    .read_data2 (read_data2)
  );

  //-----------------------------------------------------------------
  // Immediate Generator
  //-----------------------------------------------------------------
  wire [31:0] immediate;

  immediate_generator immediate_generator_inst (
    .instruction (instruction),
    .imm_select  (ctrl_imm_select),
    .immediate   (immediate)
  );

  //-----------------------------------------------------------------
  // ALU, with the ALUSrc mux feeding its second operand
  //-----------------------------------------------------------------
  wire [31:0] alu_operand_b = ctrl_alu_src ? immediate : read_data2;
  wire [31:0] alu_result;
  wire        alu_zero;

  alu alu_inst (
    .a           (read_data1),
    .b           (alu_operand_b),
    .alu_control (ctrl_alu_control),
    .result      (alu_result),
    .zero        (alu_zero)
  );

  //-----------------------------------------------------------------
  // Write-back mux: register file gets either the ALU result, or the
  // value just loaded from data memory.
  //-----------------------------------------------------------------
  assign write_back_data = ctrl_mem_to_reg ? mem_read_data : alu_result;

  //-----------------------------------------------------------------
  // Program Counter and next-PC selection
  //-----------------------------------------------------------------
  wire [31:0] pc_reg;
  wire [31:0] pc_plus4;
  wire [31:0] pc_next;

  program_counter program_counter_inst (
    .clk      (clk),
    .reset    (reset),
    .pc_next  (pc_next),
    .pc       (pc_reg),
    .pc_plus4 (pc_plus4)
  );

  // Branch target = address of the BRANCH instruction itself, plus the
  // signed B-type offset (not pc_plus4 - RISC-V branch offsets are always
  // relative to the branch instruction's own address).
  wire [31:0] pc_branch_target = pc_reg + immediate;

  // A branch is only actually taken when the control unit says this
  // instruction IS a branch (ctrl_branch) AND the ALU's comparison came
  // out equal (alu_zero, from Step 2's beq-reuses-the-subtractor trick).
  wire branch_taken = ctrl_branch & alu_zero;

  assign pc_next = branch_taken ? pc_branch_target : pc_plus4;

  //-----------------------------------------------------------------
  // External interface wiring
  //-----------------------------------------------------------------
  assign pc             = pc_reg;
  assign mem_addr       = alu_result;   // lw/sw address = rs1 + immediate = ALU result
  assign mem_write_data = read_data2;   // sw always stores the rs2 value
  assign mem_write      = ctrl_mem_write;
  assign mem_read       = ctrl_mem_read;

  assign alu_result_debug     = alu_result;
  assign reg_write_debug      = ctrl_reg_write;
  assign rd_addr_debug        = rd_addr;
  assign reg_write_data_debug = write_back_data;

endmodule
