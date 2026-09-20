// SPDX-License-Identifier: MIT
//
// instruction_memory.v
//
// Holds the program the CPU executes: a small ROM-like memory (in
// simulation and on the FPGA it's implemented in block RAM, but the
// processor never writes to it, so it behaves like read-only program
// storage). The CPU reads one 32-bit instruction per cycle from the
// address given by the Program Counter.

module instruction_memory (

  input  wire [31:0] address,      // byte address (from PC) - must be word-aligned (multiple of 4)
  output wire [31:0] instruction   // 32-bit instruction word stored at that address

  );

  // 256 words x 32 bits = 1KB of instruction storage. That is comfortably
  // more than our current 12-instruction test program needs, with room to
  // grow, without wasting FPGA block RAM on a size we don't need yet.
  localparam MEM_SIZE_WORDS = 256;

  reg [31:0] mem [0:MEM_SIZE_WORDS-1];

  integer i;
  initial begin

    // Fill every word with a NOP (addi x0, x0, 0 = 0x00000013) first, so
    // that fetching past the end of a loaded program returns a harmless
    // no-op instead of simulation 'x' (unknown), or whatever leftover
    // value happened to be in block RAM on real hardware.
    for (i = 0; i < MEM_SIZE_WORDS; i = i + 1)
      mem[i] = 32'h00000013;

    // $readmemh loads the actual program on top of that: a plain text
    // file with one 32-bit hex value per line, loaded starting at mem[0].
    // This is a standard Verilog-2001 system task, fully supported by
    // Vivado 2016 for both simulation AND synthesis - Vivado turns this
    // initial block into the block RAM's initial contents when it builds
    // the bitstream, so the program is already "burned in" at power-up.
    $readmemh("instruction_memory.mem", mem);

  end

  // The CPU addresses memory in BYTES (PC increments by 4), but each
  // instruction is stored as one 32-bit WORD. address[1:0] are always 0
  // for a word-aligned fetch, so they carry no information here and are
  // dropped; address[9:2] (8 bits, since 2^8 = 256) selects which word.
  assign instruction = mem[address[9:2]];

endmodule
