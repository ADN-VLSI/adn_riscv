task automatic tc_009_raw_dependency_chain();
  instr_t i0, i1, i2, i3;
  bit ok;

  apply_reset();
  instr_out_ready_i = 1'b1;

  // I0 produces x1
  i0 = make_instr(8'd40, 1'b0, 3'd1, 8'b0000_0000, 1'b0);

  // I1 consumes x1 and produces x2
  i1 = make_instr(8'd41, 1'b0, 3'd2, 8'b0000_0010, 1'b0);

  // I2 consumes x2 and produces x3
  i2 = make_instr(8'd42, 1'b0, 3'd3, 8'b0000_0100, 1'b0);

  // I3 consumes x3
  i3 = make_instr(8'd43, 1'b0, 3'd4, 8'b0000_1000, 1'b0);

  drive_instr(i0);
  drive_instr(i1);
  drive_instr(i2);
  drive_instr(i3);

  wait_launch_count(4, 30, ok);

  check("TC009_all_launched", ok);
  check("TC009_no_hazard_violation", g_hazard_violations == 0);

  check("TC009_i0_data_correct", data_ok[tag(i0)]);
  check("TC009_i1_data_correct", data_ok[tag(i1)]);
  check("TC009_i2_data_correct", data_ok[tag(i2)]);
  check("TC009_i3_data_correct", data_ok[tag(i3)]);
endtask
