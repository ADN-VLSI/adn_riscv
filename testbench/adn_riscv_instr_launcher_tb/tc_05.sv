  task automatic tc_005_raw_hazard();
    instr_t a, b;
    bit     ok;
    apply_reset();
    instr_out_ready_i = 1'b1;
    locks_i           = 8'b0010_0000;  // externally lock reg5 (models an outstanding writeback)

    a = make_instr(8'd30, 1'b0, 3'd2, 8'b0010_0000, 1'b0);  // needs reg5 (locked) -> stalls itself
    b = make_instr(8'd31, 1'b0, 3'd6, 8'b0000_0100, 1'b0);  // needs reg2 == a.rd -> true RAW dep on a

    drive_instr(a);
    drive_instr(b);

    repeat (10) tick();
    check("TC005_no_launch_while_locked", g_launched_id_q.size() == 0);  // neither should have launched while reg5 is locked

    locks_i = '0;  // release the external lock
    wait_launch_count(2, 20, ok);
    check("TC005_both_launched_after_release", ok);
    check("TC005_order_a_then_b", ok && (g_launched_id_q[0] == byte'(tag(a))) && (g_launched_id_q[1] == byte'(tag(b))));
  endtask
