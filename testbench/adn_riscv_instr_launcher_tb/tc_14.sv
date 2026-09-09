task automatic tc_014_register_lock_release();
  instr_t blocked_instr;
  bit ok;

  apply_reset();

  instr_out_ready_i = 1'b1;

  // Instruction requires x2.
  blocked_instr     = make_instr(8'd90, 1'b0, 3'd1, 8'b0000_0100,  // x2 requested
 1'b0);

  // Lock x2 externally.
  locks_i           = 8'b0000_0100;

  drive_instr(blocked_instr);

  repeat (5) tick();

  check("TC014_locked_instruction_not_launched", g_launched_id_q.size() == 0);

  check("TC014_locked_instruction_not_visible", instr_out_valid_o == 1'b0);

  // Release x2.
  locks_i = '0;

  wait_launch_count(1, 20, ok);

  check("TC014_launch_after_lock_release", ok);
  check("TC014_data_correct_after_lock_release", ok && data_ok[tag(blocked_instr)]);
endtask
