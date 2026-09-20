// SPDX-License-Identifier: MIT
//
// program_counter.v
//
// The Program Counter (PC): a single 32-bit register holding the address
// of the instruction currently being fetched. It is the only piece of
// state in the CPU that changes on EVERY clock cycle, no matter what
// instruction is executing - it is what makes the CPU "move forward"
// through a program.
//
// This module only holds and updates the PC. It does NOT decide what the
// next PC should be (plain PC+4, a taken branch target, or a jump target) -
// that decision is a multiplexer that lives in the datapath (Step 7),
// because the PC register itself doesn't need to know why its value is
// changing, only what the new value is.
//
// pc_plus4 is provided as an output because it is needed in two different
// places downstream: as the default "next instruction" address, and as the
// return address that JAL/JALR must save into a register.

module program_counter (

  input  wire        clk,        // clock - pc updates on its rising edge
  input  wire        reset,      // synchronous reset - forces pc back to 0
  input  wire [31:0] pc_next,    // the value pc should take on next
  output reg  [31:0] pc,         // current instruction address
  output wire [31:0] pc_plus4    // pc + 4 (next sequential instruction address)

  );

  always @(posedge clk) begin
    if (reset)
      pc <= 32'd0;      // start fetching from address 0 on reset
    else
      pc <= pc_next;    // otherwise load whatever address was selected
  end

  // Byte-addressed memory, 4-byte (32-bit) instructions -> next sequential
  // instruction is always 4 addresses further along, never +1.
  assign pc_plus4 = pc + 32'd4;

endmodule
