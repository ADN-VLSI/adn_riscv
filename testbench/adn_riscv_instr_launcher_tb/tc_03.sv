
  task automatic tc_003_depth_and_backpressure();
    instr_t items[4];
    bit     ok;
    apply_reset();
    instr_out_ready_i = 1'b0;  // hold output back so the buffer actually fills up

    for (int i = 0; i < NOS + 1; i++)
      items[i] = make_instr(8'(10 + i), 1'b0, logic'(i), '0, 1'b0);

    foreach (items[i]) drive_instr(items[i]);

    // buffer should now be at capacity (NOS+1 slots occupied) -> input backpressure expected
    tick();
    check("TC003_full_backpressure", instr_in_ready_o == 1'b0);

    // now drain: release output ready and let all four come out in order
    instr_out_ready_i = 1'b1;
    wait_launch_count(NOS + 1, 30, ok);
    check("TC003_all_drained", ok);
    ok = 1'b1;
    for (int i = 0; i < NOS + 1; i++) begin
      instr_t exp_item;
      byte    got_id;
      byte    exp_id;
      exp_item = items[i];
      exp_id   = byte'(tag(exp_item));
      got_id   = g_launched_id_q[i];
      if (got_id != exp_id) ok = 1'b0;
    end
    check("TC003_drain_order_correct", ok);

    // buffer now empty -> in_ready should be back up
    check("TC003_ready_after_drain", instr_in_ready_o == 1'b1);
  endtask