task automatic tc_004_valid_ready_gating();
    instr_t exp;
    bit     ok;
    apply_reset();
    instr_out_ready_i = 1'b0;
    exp = make_instr(8'd20, 1'b0, 3'd1, '0, 1'b0);
    drive_instr(exp);

    repeat (4) tick();
    check("TC004_valid_gated_off", instr_out_valid_o == 1'b0);  // valid is gated off while ready is low
    check("TC004_nothing_lost_while_stalled", g_launched_id_q.size() == 0);  // and nothing was lost/skipped

    instr_out_ready_i = 1'b1;
    wait_launch_count(1, 10, ok);
    check("TC004_launches_intact_after_stall", ok && data_ok[tag(exp)]);  // same instruction still shows up intact
  endtask
