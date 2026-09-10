/*

TC_015 : Same-rd instructions with no RAW read dependency

Four instructions all target the SAME destination register, but none of
them actually *reads* that register (reg_reqs = 0 for all), so there is no
RAW dependency between any pair of them per the launcher's own hazard
definition (reg_reqs bit vs. an older resident rd). This is deliberately
different from TC_005 / TC_009, which both hinge on an explicit
reg_reqs-vs-older-rd match: here we're checking that in-order dispatch is
driven purely by program order / injection sequence, and that matching rd
values alone never trips a spurious hazard nor gets treated as a shortcut
for out-of-order bypass.

Author : Md Sakhawat Hossain Sabbir
Date   : 2026-09-10
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

task automatic tc_015_same_rd_no_raw_ordering();
  instr_t t;
  bit     ok;
  int     pre_viol;
  int     n;
  byte    ids[4];

  ids[0] = 8'd21;
  ids[1] = 8'd22;
  ids[2] = 8'd23;
  ids[3] = 8'd24;

  apply_reset();
  instr_out_ready_i <= 1'b0;  // hold output stalled while we load up several same-rd instrs
  tick();

  pre_viol = g_hazard_violations;

  foreach (ids[i]) begin
    t = make_instr(ids[i], 1'b0, 3'd2, '0, 1'b0);  // every one targets rd=2, none REQUESTS rd=2
    drive_instr(t);
  end

  instr_out_ready_i <= 1'b1;

  wait_launch_count(g_launched_id_q.size() + 4, 4 * HANDSHAKE_TIMEOUT, ok);
  check("tc015_all_four_drained", ok);

  if (ok) begin
    n = g_launched_id_q.size();
    // launch order must exactly match injection order - purely FIFO, not
    // influenced one way or the other by every instruction sharing an rd.
    check("tc015_launch_order_preserved",
          (g_launched_id_q[n-4] == ids[0]) && (g_launched_id_q[n-3] == ids[1]) &&
          (g_launched_id_q[n-2] == ids[2]) && (g_launched_id_q[n-1] == ids[3]));
  end

  foreach (ids[i]) check($sformatf("tc015_data_ok_id%0d", ids[i]), data_ok[ids[i]]);

  check("tc015_no_spurious_hazard_violation", g_hazard_violations == pre_viol);
endtask