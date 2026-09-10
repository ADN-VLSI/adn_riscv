/*

TC_016 : Asynchronous reset mid-stream

TC_001 only ever observes reset behavior at the very start of a clean
simulation, applied through the clocked sequencing in apply_reset(). This
test instead loads real, resident state into the buffer and then yanks
arst_ni low directly - deliberately landing off any posedge - to confirm
the DUT's documented *asynchronous* reset actually clears state
independent of the clock, that no in-flight instruction leaks out across
the reset boundary, and that the launcher comes back up cleanly afterward.

Author : Md Sakhawat Hossain Sabbir
Date   : 2026-09-10
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

task automatic tc_016_async_reset_midstream();
  instr_t t;
  int     prior_launched;
  bit     ok;

  apply_reset();
  instr_out_ready_i <= 1'b0;  // keep output stalled so injected instrs stay resident
  tick();

  t = make_instr(8'd31, 1'b0, 3'd1, '0, 1'b0);
  drive_instr(t);
  t = make_instr(8'd32, 1'b0, 3'd2, '0, 1'b0);
  drive_instr(t);

  check("tc016_precondition_nothing_launched_yet", g_launched_id_q.size() == 0);
  prior_launched = g_launched_id_q.size();

  // Assert the asynchronous reset directly, off-clock, bypassing
  // apply_reset()'s own clocked entry/exit sequencing on purpose.
  arst_ni = 1'b0;
  #(CLK_PERIOD * 0.3);
  check("tc016_valid_deasserts_during_async_reset", instr_out_valid_o == 1'b0);

  #(CLK_PERIOD * 2);
  arst_ni = 1'b1;
  repeat (2) tick();

  check("tc016_no_launches_leaked_across_reset", g_launched_id_q.size() == prior_launched);
  check("tc016_ready_high_after_reset", instr_in_ready_o == 1'b1);
  check("tc016_valid_low_after_reset", instr_out_valid_o == 1'b0);

  // The DUT's own residency is gone - drop the matching TB-side bookkeeping
  // for ids 31/32 so the background hazard monitor doesn't compare a fresh
  // instruction against stale pre-reset entries.
  resident[8'd31] = 1'b0;
  resident[8'd32] = 1'b0;

  // A fresh instruction after reset should sail through clean, with no
  // interference or stale-data leakage from what was resident before.
  instr_out_ready_i <= 1'b1;
  t = make_instr(8'd33, 1'b0, 3'd3, '0, 1'b0);
  drive_instr(t);

  wait_launch_count(g_launched_id_q.size() + 1, HANDSHAKE_TIMEOUT, ok);
  check("tc016_post_reset_instr_launches", ok);
  if (ok) check("tc016_post_reset_data_ok", data_ok[8'd33]);
endtask