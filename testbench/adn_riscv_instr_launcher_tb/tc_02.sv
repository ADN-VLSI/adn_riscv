task automatic tc_002_single_passthrough();
    instr_t exp;
    bit     ok;
    apply_reset();
    instr_out_ready_i = 1'b1;
    exp = make_instr(8'd1, 1'b0, 3'd3, 8'b0000_0000, 1'b0);
    drive_instr(exp);
    wait_launch_count(1, 20, ok);
    check("TC002_launched", ok);
    check("TC002_data_matches", ok && data_ok[tag(exp)]);
endtask