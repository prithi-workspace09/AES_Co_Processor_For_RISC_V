// SPDX-License-Identifier: MIT
//
// data_memory.v
//
// General-purpose read/write memory for `lw` and `sw`. Unlike instruction
// memory, the CPU can both read AND write this memory during normal
// execution. It also supports being preloaded with initial values (like a
// compiled program's ".data" section of initialized global variables),
// the same way instruction memory is preloaded with the program itself.
//
// Reads are ASYNCHRONOUS (combinational): a `lw` needs the loaded value
// available within the same cycle it was requested, so the write-back mux
// in the datapath can select it immediately - there's no clock edge to
// wait for, matching the single-cycle design.
// Writes are SYNCHRONOUS: a `sw` only actually commits its value into
// memory on the next rising clock edge, and only when mem_write is high -
// exactly like the register file's write port in Step 3.
//
// mem_read gates the read output: read_data only reflects the addressed
// word when mem_read=1, and reads 0 otherwise. This mirrors how a real
// block RAM's read-enable pin behaves, and means read_data only toggles
// on cycles that actually need it (lower switching activity than an
// always-on read). It's safe to gate this way because the datapath only
// ever selects read_data into the write-back mux when MemtoReg=1, which
// is asserted on exactly the same cycles as mem_read (both only true for
// `lw`) - so no instruction that needs the value ever sees it gated off.

module data_memory (

  input  wire        clk,          // clock - writes happen on its rising edge
  input  wire        mem_write,    // 1 = commit write_data into memory this cycle (sw)
  input  wire        mem_read,     // 1 = this cycle is a load (lw) - gates the read output below
  input  wire [31:0] address,      // byte address (from the ALU: rs1 + immediate)
  input  wire [31:0] write_data,   // value to store (always rs2's value, from the datapath)
  output wire [31:0] read_data     // value at address when mem_read=1, else 0

  );

  // 256 words x 32 bits = 1KB of data storage - matches instruction
  // memory's size, comfortably more than our test program needs.
  localparam MEM_SIZE_WORDS = 256;

  reg [31:0] mem [0:MEM_SIZE_WORDS-1];

  integer i;
  initial begin

    // Zero-fill everything first, so uninitialized locations read back as
    // a known value (0) instead of simulation 'x' (unknown).
    for (i = 0; i < MEM_SIZE_WORDS; i = i + 1)
      mem[i] = 32'd0;

    // Optionally preload known initial values (e.g. a program's
    // initialized global variables), the same $readmemh mechanism used
    // for instruction_memory.v in Step 8. Our current test program
    // doesn't rely on any preloaded data - it writes its own value with
    // `sw` before ever reading it back with `lw` - but the mechanism is
    // here and ready for when a real compiled program needs it.
    $readmemh("data_memory.mem", mem);

  end

  // Same byte-address -> word-index conversion as instruction memory:
  // address[1:0] are dropped (always 0 for a word-aligned access), and
  // address[9:2] (8 bits) selects one of the 256 words. This design only
  // supports word-aligned lw/sw - byte/half-word loads and stores (lb,
  // lh, sb, sh) are not part of the instruction subset we chose to build.
  wire [7:0] word_index = address[9:2];

  assign read_data = mem_read ? mem[word_index] : 32'd0;

  always @(posedge clk) begin
    if (mem_write)
      mem[word_index] <= write_data;
  end

endmodule
