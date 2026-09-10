task automatic tc_012_clear_flush();
  instr_t items[4];
  bit ok;

  apply_reset();
  instr_out_ready_i = 1'b0;

  for (int i = 0; i < NOS + 1; i++) begin
    items[i] = make_instr(byte'(70 + i), 1'b0, logic'(i), '0, 1'b0);

    drive_instr(items[i]);
  end

  tick();

  check("TC012_buffer_full_before_clear", instr_in_ready_o == 1'b0);

  // Flush the complete launcher.
  clear_i = 1'b1;
  tick();
  clear_i = 1'b0;

  // Output remains stalled, so any surviving instruction would be visible.
  repeat (3) tick();

  check("TC012_output_empty_after_clear", instr_out_valid_o == 1'b0);

  check("TC012_input_ready_after_clear", instr_in_ready_o == 1'b1);

  check("TC012_nothing_launched_after_clear", g_launched_id_q.size() == 0);

  // Verify that a fresh instruction can enter after the flush.
  instr_out_ready_i = 1'b1;

  drive_instr(items[0]);
  wait_launch_count(1, 20, ok);

  check("TC012_new_instruction_after_clear", ok);
  check("TC012_new_instruction_data_correct", ok && data_ok[tag(items[0])]);
endtask
