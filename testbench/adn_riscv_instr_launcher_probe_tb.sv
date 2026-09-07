/*

PROBE / DIAGNOSTIC TESTBENCH — trace which signal is x-source after reset.

Purpose: run against the ORIGINAL adn_riscv_instr_launcher.sv (seed-after-loop `clears`,
only .NR(NR) applied) in xsim. This dumps EVERY signal in the clears -> splits -> arb ->
gnt_idx -> clears loop, individually, starting from the very first cycle after reset,
BEFORE any instruction is driven. That tells us which node goes x first and drives the rest.

Run:  make simulate TOP=adn_riscv_instr_launcher_xtrace_tb

Read the log like this:
  - Look at the FIRST line (right after reset, no instruction in flight yet).
  - If gnt_idx is x there -> the x originates in the arbiter/encoder path and feeds clears.
  - If clears is x but gnt_idx is clean -> the x originates in the clears block itself.
  - If arb_req is x while pl_outs_valid is clean -> order_checker inputs (locks/mem_busy) are x.
This isolates the true source instead of guessing.

Author : Adnan Sami Anirban (adnananirban259@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License

*/

module adn_riscv_instr_launcher_probe_tb;

  `include "vip/adn_common_tb_headers.sv"

  localparam int NR         = 8;
  localparam int NOS        = 3;
  localparam int CLK_PERIOD = 10;

  typedef struct packed {
    logic [7:0]            id;
    logic                  blocking;
    logic [$clog2(NR)-1:0] rd;
    logic [NR-1:0]         reg_req;
    logic                  mem_op;
  } instr_t;

  logic arst_ni, clk_i, clear_i;
  instr_t instr_in_i;  logic instr_in_valid_i, instr_in_ready_o;
  logic [NR-1:0] locks_i;
  instr_t instr_out_o; logic instr_out_valid_o, instr_out_ready_i;

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

  initial clk_i = 1'b0;
  always #(CLK_PERIOD / 2) clk_i = ~clk_i;

  task automatic dump(input string tag);
    // dump every node in the clears/arb/gnt loop, one signal per field
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

  initial begin
    // hold everything at known, then release reset. NO instruction driven yet.
    arst_ni = 1'b0; clear_i = 1'b0; instr_in_valid_i = 1'b0; instr_in_i = '0;
    instr_out_ready_i = 1'b0; locks_i = '0;

    repeat (3) @(posedge clk_i);
    dump("=== during reset (arst_ni=0) ===");

    arst_ni = 1'b1;
    @(posedge clk_i);
    dump("=== 1 cycle after reset release, NOTHING driven ===");
    @(posedge clk_i);
    dump("=== 2 cycles after reset release ===");
    @(posedge clk_i);
    dump("=== 3 cycles after reset release ===");

    $finish;
  end

endmodule