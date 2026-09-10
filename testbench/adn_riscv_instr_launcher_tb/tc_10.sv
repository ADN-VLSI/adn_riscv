task automatic tc_010_blocking_instruction();
  instr_t older;
  instr_t younger1;
  instr_t younger2;
  bit ok;

  apply_reset();
  instr_out_ready_i = 1'b1;

  older             = make_instr(8'd50, 1'b1,  // blocking
 3'd2, '0, 1'b0);

  younger1          = make_instr(8'd51, 1'b0, 3'd3, '0, 1'b0);

  younger2          = make_instr(8'd52, 1'b0, 3'd4, '0, 1'b0);

  drive_instr(older);
  drive_instr(younger1);
  drive_instr(younger2);

  wait_launch_count(3, 30, ok);

  check("TC010_all_launched", ok);
  check("TC010_no_hazard_violation", g_hazard_violations == 0);
  check("TC010_older_data_correct", data_ok[tag(older)]);
  check("TC010_younger1_data_correct", data_ok[tag(younger1)]);
  check("TC010_younger2_data_correct", data_ok[tag(younger2)]);
endtask
