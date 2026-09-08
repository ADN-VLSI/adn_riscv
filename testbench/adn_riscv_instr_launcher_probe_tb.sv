/*

PROBE / DIAGNOSTIC TESTBENCH — pinpoints the source of the `x` on `clears`.

Purpose: run against the ORIGINAL adn_riscv_instr_launcher.sv (the `clears` block with the
seed `clears[NOS] = clear_i` assigned AFTER the loop, only .NR(NR) applied) in xsim. It dumps
every node in the clears -> splits -> arb -> gnt_idx -> clears path, one signal per line,
starting from the very first cycle after reset, BEFORE any instruction is driven.

How to read the log (look at the FIRST post-reset dump):
  - clears shows x while gnt_idx / arb_req / arb_gnt are clean 0
        -> the x is created INSIDE the clears block itself (this is what we observed).
  - gnt_idx is x
        -> the x would be coming from the arbiter/encoder path instead.
  - arb_req is x while pl_outs_valid is clean
        -> the x would be coming from the order_checker inputs (locks / mem_busy).
This isolates the real source instead of guessing.

Run:  make simulate TOP=adn_riscv_instr_launcher_probe_tb

Author : Adnan Sami Anirban (adnananirban259@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License

*/

module adn_riscv_instr_launcher_probe_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `include "vip/adn_common_tb_headers.sv"

  // real architecture types: rv_op_t (opcode enum) and the ADN_RISCV_T struct macro
  import adn_riscv_pkg::*;
  `include "adn_riscv/typedef.svh"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int NR         = 8;   // number of tracked registers
  localparam int CLOG2_NR   = 3;   // $clog2(NR); 2**CLOG2_NR must equal NR
  localparam int XLEN       = 32;  // register / pc width
  localparam int NOS        = 3;   // number of pipeline stages
  localparam int CLK_PERIOD = 10;  // ns

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Real decoded-instruction type from the architecture header (same type the DUT expects).
  `ADN_RISCV_T(adn, CLOG2_NR, XLEN)
  typedef adn_decoded_instr_t instr_t;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic          arst_ni, clk_i, clear_i;
  instr_t        instr_in_i;
  logic          instr_in_valid_i, instr_in_ready_o;
  logic [NR-1:0] locks_i;
  instr_t        instr_out_o;
  logic          instr_out_valid_o, instr_out_ready_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_riscv_instr_launcher #(
      .decoded_instr_t(instr_t),
      .NR             (NR),
      .NOS            (NOS)
  ) u_dut (
      .arst_ni          (arst_ni),
      .clk_i            (clk_i),
      .clear_i          (clear_i),
      .instr_in_i       (instr_in_i),
      .instr_in_valid_i (instr_in_valid_i),
      .instr_in_ready_o (instr_in_ready_o),
      .locks_i          (locks_i),
      .instr_out_o      (instr_out_o),
      .instr_out_valid_o(instr_out_valid_o),
      .instr_out_ready_i(instr_out_ready_i)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial clk_i = 1'b0;
  always #(CLK_PERIOD / 2) clk_i = ~clk_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Dump every node in the clears/arb/gnt loop, one signal per line.
  task automatic dump(input string tag);
    $display("[%0t] %s", $time, tag);
    $display("      clear_i     = %b", clear_i);
    $display("      clears      = %b", u_dut.clears);
    $display("      gnt_idx     = %b", u_dut.gnt_idx);
    $display("      arb_req     = %b", u_dut.arb_req);
    $display("      arb_gnt     = %b", u_dut.arb_gnt);
    $display("      pl_outs_val = %b", u_dut.pl_outs_valid);
    $display("      pl_ins_val  = %b", u_dut.pl_ins_valid);
    $display("      pl_ins_rdy  = %b", u_dut.pl_ins_ready);
    $display("      out_valid   = %b", instr_out_valid_o);
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin
    // Hold all inputs at known values, then release reset. NO instruction is ever driven,
    // so if `clears` still goes x, the x cannot have come from any input we supplied.
    arst_ni            <= 1'b0; 
    clear_i            <= 1'b0; 
    instr_in_valid_i   <= 1'b0; 
    instr_in_i         <= '0;
    instr_out_ready_i  <= 1'b0; 
    locks_i            <= '0;

    repeat (3) @(posedge clk_i);
    dump("=== during reset (arst_ni=0) ===");

    arst_ni <= 1'b1;
    @(posedge clk_i);
    dump("=== 1 cycle after reset release, NOTHING driven ===");
    @(posedge clk_i);
    dump("=== 2 cycles after reset release ===");
    @(posedge clk_i);
    dump("=== 3 cycles after reset release ===");

    $finish;
  end

endmodule