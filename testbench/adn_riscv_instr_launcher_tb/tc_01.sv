  task automatic tc_001_reset_state();
    apply_reset();
    check("TC001_reset_in_ready_high", instr_in_ready_o == 1'b1);
    check("TC001_reset_out_valid_low", instr_out_valid_o == 1'b0);
  endtask
