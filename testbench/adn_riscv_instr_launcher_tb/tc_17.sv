/*

TC_017 : Multi-bit register lock - partial release must still block

TC_014 exercises a single relevant lock bit being released. This test
gives one instruction TWO required source registers (reg_reqs bits 1 and
2) held locked simultaneously, plus a decoy lock bit (register 5) the
instruction never requests. It checks three distinct points TC_014 does
not: (1) launch stays blocked while both required bits are locked, (2)
releasing only ONE of the two required bits must NOT be enough to launch,
and (3) an irrelevant locked bit the instruction never asked for must
never hold it back once its real dependencies clear.

Author : Md Sakhawat Hossain Sabbir
Date   : 2026-09-10
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

task automatic tc_017_partial_lock_release();
  instr_t          t;
  bit              ok;
  int              pre_launched;
  logic [NR-1:0]   req;

  apply_reset();
  instr_out_ready_i <= 1'b1;

  req    = '0;
  req[1] = 1'b1;
  req[2] = 1'b1;

  locks_i    = '0;
  locks_i[1] = 1'b1;
  locks_i[2] = 1'b1;
  locks_i[5] = 1'b1;  // decoy: never requested by this instruction, must never matter

  t = make_instr(8'd41, 1'b0, 3'd0, req, 1'b0);
  drive_instr(t);

  pre_launched = g_launched_id_q.size();
  repeat (6) tick();
  check("tc017_blocked_while_both_bits_locked", g_launched_id_q.size() == pre_launched);

  locks_i[1] = 1'b0;  // release only ONE of the two required bits
  repeat (6) tick();
  check("tc017_still_blocked_after_partial_release", g_launched_id_q.size() == pre_launched);

  locks_i[2] = 1'b0;  // release the second required bit; decoy bit 5 stays locked throughout

  wait_launch_count(pre_launched + 1, HANDSHAKE_TIMEOUT, ok);
  check("tc017_launches_once_all_required_bits_clear", ok);
  if (ok) check("tc017_data_ok_id41", data_ok[8'd41]);

  locks_i = '0;
endtask