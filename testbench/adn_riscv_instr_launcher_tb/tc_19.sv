/*

TC_019 : Sustained hazard-free streaming throughput

TC_006/TC_007's randomized regressions deliberately mix in blocking,
bypass, mem_op, and clear-flush scenarios, and aren't concerned with cycle
efficiency. This test asks a different question: with no RAW deps, no
blocking, no mem_op, no locks, and the output never stalled, does a
back-to-back stream of instructions actually achieve close to
one-launch-per-cycle throughput, with no unexpected bubbles creeping in?
It's purely a performance/efficiency check layered on top of the
correctness checks the other tests already cover.

Author : Md Sakhawat Hossain Sabbir
Date   : 2026-09-10
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

task automatic tc_019_sustained_throughput();
  instr_t t;
  byte    id;
  time    start_time, end_time;
  int     elapsed_cycles;
  int     launched_before;
  bit     ok;

  apply_reset();
  instr_out_ready_i <= 1'b1;
  locks_i            = '0;

  launched_before = g_launched_id_q.size();
  start_time      = $time;

  for (int i = 0; i < N_RAND; i++) begin
    id = 8'(60 + i);
    t  = make_instr(id, 1'b0, (i % NR), '0, 1'b0);  // fully independent - no reg_reqs, no blocking
    drive_instr(t);
  end

  wait_launch_count(launched_before + N_RAND, N_RAND + 8 * (NOS + 1), ok);
  check("tc019_all_instructions_drained", ok);

  end_time       = $time;
  elapsed_cycles = int'((end_time - start_time) / CLK_PERIOD);

  // Generous bound: ideal is roughly N_RAND cycles plus one pipeline fill.
  // We allow extra slack rather than demanding an exact cycle-for-cycle
  // count, since that depends on internal split-pipeline latency this
  // testbench doesn't have visibility into - but a stream this far off
  // ideal would indicate real, unexpected bubbling.
  check("tc019_near_ideal_throughput", elapsed_cycles <= (N_RAND + 4 * (NOS + 1)));

  for (int i = 0; i < N_RAND; i++) begin
    id = 8'(60 + i);
    check($sformatf("tc019_data_ok_id%0d", id), data_ok[id]);
  end
endtask