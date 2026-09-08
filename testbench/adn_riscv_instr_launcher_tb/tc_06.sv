// TC_006 : a blocking instruction must hold back a younger instruction even when their
// registers are disjoint (blocking locks everything behind it, not just overlapping regs).
  task automatic tc_006_blocking_stalls_disjoint();
    instr_t c, d;
    bit     ok;
    apply_reset();
    instr_out_ready_i = 1'b1;
    locks_i           = 8'b1000_0000;  // externally lock reg7 so c itself stalls for a while

    c = make_instr(8'd40, 1'b1, 3'd0, 8'b1000_0000, 1'b0);  // blocking=1, needs reg7 (locked)
    d = make_instr(8'd41, 1'b0, 3'd1, 8'b0000_0001, 1'b0);  // needs reg0 - disjoint from c

    drive_instr(c);
    drive_instr(d);

    repeat (10) tick();
    // d must be held back purely by c's blocking flag, not by any real shared-register dep
    check("TC006_no_launch_while_c_blocking", g_launched_id_q.size() == 0);

    locks_i = '0;
    wait_launch_count(2, 20, ok);
    check("TC006_both_launched_after_release", ok);
    check("TC006_order_c_then_d", ok && (g_launched_id_q[0] == byte'(tag(c))) && (g_launched_id_q[1] == byte'(tag(d))));
  endtask
