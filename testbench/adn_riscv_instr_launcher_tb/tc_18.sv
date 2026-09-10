/*

TC_018 : Clear while completely full AND output-stalled

TC_003 fills the buffer to capacity and just watches an ordered drain.
TC_012 flushes with clear_i but not necessarily at full capacity. TC_013
clears while the output is stalled but the buffer isn't necessarily full.
This test compounds all three conditions at once: fill every one of the
NOS+1 slots (engaging input backpressure), keep the output stalled too,
and only then pulse clear_i. It verifies the buffer is fully wiped (no
stale launches sneak out once output is un-stalled), instr_in_ready_o
comes back immediately, and a freshly injected instruction afterward is
completely unaffected by what was flushed.

Author : Md Sakhawat Hossain Sabbir
Date   : 2026-09-10
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

task automatic tc_018_clear_while_full();
  instr_t t;
  int     c;
  byte    ids[4];
  bit     ok;
  int     pre_launched;

  ids[0] = 8'd51;
  ids[1] = 8'd52;
  ids[2] = 8'd53;
  ids[3] = 8'd54;

  apply_reset();
  instr_out_ready_i <= 1'b0;  // nobody drains - forces the buffer to fill completely

  foreach (ids[i]) begin
    t = make_instr(ids[i], 1'b0, 3'd0, '0, 1'b0);
    drive_instr(t);
  end

  c = 0;
  while (instr_in_ready_o && c < HANDSHAKE_TIMEOUT) begin
    tick();
    c++;
  end
  check("tc018_buffer_reports_full_before_clear", !instr_in_ready_o);

  pre_launched = g_launched_id_q.size();

  clear_i <= 1'b1;
  tick();
  tick();
  clear_i <= 1'b0;

  foreach (ids[i]) resident[ids[i]] = 1'b0;  // flushed - stop scoreboarding as pending

  repeat (3) tick();
  check("tc018_nothing_launched_out_of_a_full_flushed_buffer", g_launched_id_q.size() == pre_launched);
  check("tc018_valid_low_after_full_flush", instr_out_valid_o == 1'b0);
  check("tc018_ready_returns_after_full_flush", instr_in_ready_o == 1'b1);

  // buffer must genuinely be empty and healthy - a fresh instruction should
  // sail through clean, with no leftover data from ids 51-54.
  instr_out_ready_i <= 1'b1;
  t = make_instr(8'd55, 1'b0, 3'd1, '0, 1'b0);
  drive_instr(t);

  wait_launch_count(g_launched_id_q.size() + 1, HANDSHAKE_TIMEOUT, ok);
  check("tc018_post_flush_instr_launches", ok);
  if (ok) check("tc018_post_flush_data_ok", data_ok[8'd55]);
endtask