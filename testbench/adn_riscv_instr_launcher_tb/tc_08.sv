task automatic tc_008_simultaneous_enqueue_dequeue();
  instr_t a, b, c;
  bit ok;

  apply_reset();
  instr_out_ready_i = 1'b1;

  a = make_instr(8'd30, 1'b0, 3'd1, '0, 1'b0);
  b = make_instr(8'd31, 1'b0, 3'd2, '0, 1'b0);
  c = make_instr(8'd32, 1'b0, 3'd3, '0, 1'b0);

  drive_instr(a);
  drive_instr(b);
  drive_instr(c);

  wait_launch_count(3, 20, ok);

  check("TC008_all_three_launched", ok);
  check("TC008_a_data_correct", data_ok[tag(a)]);
  check("TC008_b_data_correct", data_ok[tag(b)]);
  check("TC008_c_data_correct", data_ok[tag(c)]);
  check("TC008_no_duplicate_or_loss", g_launched_id_q.size() == 3);
  check("TC008_input_ready_restored", instr_in_ready_o == 1'b1);
endtask
