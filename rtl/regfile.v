// SPDX-License-Identifier: MIT
//
// regfile.v
//
// Register file for a single-cycle RV32I processor.
//
// RV32I defines 32 general-purpose registers, x0 through x31, each 32 bits
// wide. This module IS that register set: a small, fast internal memory
// that the datapath reads from and writes to on every instruction.
//
// - Two READ ports (rs1, rs2): almost every RV32I instruction reads at most
//   two source registers at once (e.g. "add rd, rs1, rs2" needs both rs1
//   and rs2 in the same cycle), so we need two independent read paths.
// - One WRITE port (rd): an instruction only ever produces one result, so
//   one write port is enough.
// - Reads are ASYNCHRONOUS (combinational): the moment rs1_addr/rs2_addr
//   change, read_data1/read_data2 change too, with no clock edge needed.
//   This matches a single-cycle CPU, where the ALU must have its operands
//   available immediately after decode, within the same cycle.
// - Writes are SYNCHRONOUS: a new value only lands in a register on the
//   rising edge of clk, and only if reg_write is asserted. This models a
//   real register file, which is built from clocked flip-flops/RAM, not
//   transparent latches.
// - x0 is hardwired to zero: RV32I guarantees reading x0 always returns 0,
//   and writes to x0 are silently discarded. Software relies on this (e.g.
//   "x0" is used as a throwaway destination, or as a zero source operand).

module regfile (

  input  wire        clk,          // clock - writes happen on its rising edge
  input  wire        reg_write,    // write enable: 1 = commit write_data into rd
  input  wire [4:0]  rs1_addr,     // which register to read onto read_data1 (0-31)
  input  wire [4:0]  rs2_addr,     // which register to read onto read_data2 (0-31)
  input  wire [4:0]  rd_addr,      // which register to write write_data into
  input  wire [31:0] write_data,   // value to write into register rd_addr
  output wire [31:0] read_data1,   // current value of register rs1_addr
  output wire [31:0] read_data2    // current value of register rs2_addr

  );

  // The register array itself: 32 registers, each 32 bits wide.
  // Verilog memory syntax: reg [word_width-1:0] name [0:depth-1].
  reg [31:0] registers [0:31];

  // Only used to zero-initialize the array for simulation, so waveforms and
  // $display output start from known values instead of X (unknown). This
  // loop is simulation/init convenience - it does not represent a reset
  // wire in real hardware, and x0 stays correct on real hardware anyway
  // because of the read-side mux below, not because of this loop.
  integer i;
  initial begin
    for (i = 0; i < 32; i = i + 1)
      registers[i] = 32'd0;
  end

  // Asynchronous (combinational) reads.
  // x0 is forced to 0 here regardless of what is actually stored in
  // registers[0] - this is what guarantees "x0 always reads as zero" even
  // if something upstream ever mistakenly tried to write to it.
  assign read_data1 = (rs1_addr == 5'd0) ? 32'd0 : registers[rs1_addr];
  assign read_data2 = (rs2_addr == 5'd0) ? 32'd0 : registers[rs2_addr];

  // Synchronous write, on the rising edge of clk only.
  // The rd_addr != 0 check is what makes writes to x0 a no-op, matching
  // the RV32I spec (this is actually belt-and-braces, since the read mux
  // above already guarantees x0 is read as 0 even if this check were
  // removed - but skipping the write also avoids ever burning a clock
  // cycle's worth of write energy on a register nobody can read back).
  always @(posedge clk) begin
    if (reg_write && (rd_addr != 5'd0)) begin
      registers[rd_addr] <= write_data;
    end
  end

endmodule
