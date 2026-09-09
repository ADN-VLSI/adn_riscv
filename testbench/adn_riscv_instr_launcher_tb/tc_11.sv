task automatic tc_011_memory_ordering();
  instr_t mem0;
  instr_t mem1;
  instr_t alu0;
  bit ok;

  apply_reset();
  instr_out_ready_i = 1'b1;

  mem0 = make_instr(8'd60, 1'b0, 3'd1, '0, 1'b1);

  mem1 = make_instr(8'd61, 1'b0, 3'd2, '0, 1'b1);

  alu0 = make_instr(8'd62, 1'b0, 3'd3, '0, 1'b0);

  drive_instr(mem0);
  drive_instr(mem1);
  drive_instr(alu0);

  wait_launch_count(3, 30, ok);

  check("TC011_all_launched", ok);
  check("TC011_no_hazard_violation", g_hazard_violations == 0);
  check("TC011_mem0_data_correct", data_ok[tag(mem0)]);
  check("TC011_mem1_data_correct", data_ok[tag(mem1)]);
  check("TC011_alu_data_correct", data_ok[tag(alu0)]);
endtask
