// TC_007 : an older instruction stalled on an EXTERNAL lock (not blocking) must not hold back
  // an independent younger instruction - the younger one may bypass and launch first.
task automatic tc_007_independent_bypass();
    instr_t e, f;
    bit     ok;
    apply_reset();
    instr_out_ready_i = 1'b1;
    locks_i           = 8'b1000_0000;  // lock reg7

    e = make_instr(8'd50, 1'b0, 3'd4, 8'b1000_0000, 1'b0);  // stuck on reg7, not blocking
    f = make_instr(8'd51, 1'b0, 3'd2, 8'b0000_0010, 1'b0);  // needs reg1, disjoint from e (rd=4)

    drive_instr(e);
    drive_instr(f);

    wait_launch_count(1, 15, ok);
    check("TC007_something_launched", ok);
    // f should be the one that got through, while e is still stuck on the external lock
    check("TC007_f_bypassed_e", ok && (g_launched_id_q[0] == byte'(tag(f))));
    check("TC007_e_still_resident", resident[tag(e)] == 1'b1);

    locks_i = '0;  // release; e can now launch too
    wait_launch_count(2, 15, ok);
    check("TC007_e_launches_after_release", ok);
  endtask