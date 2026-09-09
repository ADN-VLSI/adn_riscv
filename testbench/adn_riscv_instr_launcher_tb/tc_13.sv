task automatic tc_013_clear_while_output_stalled();
  instr_t a;
  instr_t b;
  bit ok;

  apply_reset();

  instr_out_ready_i = 1'b0;

  a = make_instr(8'd80, 1'b0, 3'd1, '0, 1'b0);

  b = make_instr(8'd81, 1'b0, 3'd2, '0, 1'b0);

  drive_instr(a);
  drive_instr(b);

  repeat (3) tick();

  check("TC013_output_valid_gated", instr_out_valid_o == 1'b0);

  check("TC013_no_launch_before_clear", g_launched_id_q.size() == 0);

  // Flush while stalled.
  clear_i = 1'b1;
  tick();
  clear_i = 1'b0;

  repeat (2) tick();

  check("TC013_buffer_empty_after_clear", instr_out_valid_o == 1'b0);

  // Release output and make sure the old instructions do not reappear.
  instr_out_ready_i = 1'b1;

  repeat (4) tick();

  check("TC013_flushed_instructions_not_launched", g_launched_id_q.size() == 0);

  // Verify launcher still works.
  drive_instr(a);
  wait_launch_count(1, 20, ok);

  check("TC013_post_clear_instruction_launches", ok);
  check("TC013_post_clear_data_correct", ok && data_ok[tag(a)]);
endtask
