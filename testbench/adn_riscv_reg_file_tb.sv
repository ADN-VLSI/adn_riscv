/*

| TEST CASE | DATE       | AUTHOR          | DESCRIPTION                                           |
|-----------|------------|-----------------|-------------------------------------------------------|
| TC_001    | 2026-08-16 | Motasim Faiyaz | Basic register write and read checks                   |
| TC_002    | 2026-08-16 | Motasim Faiyaz | Zero register behavior checks                          |
| TC_003    | 2026-08-16 | Motasim Faiyaz | Lock behavior and boundary address checks              |
| TC_004    | 2026-08-16 | Motasim Faiyaz | Asynchronous reset checks                              |

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-16 | Motasim Faiyaz  | Initial version                            
            |
| 1.0      | 2026-08-16 | Annim Jannat    | Stable release                                         |

Author : Annim Jannat (jannatannim@gmail.com)
Co_Author: Motasim Faiyaz (motasimfaiyaz@gmail.com)

This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_riscv_reg_file_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int NUM_RD     = 2;
  localparam int NUM_RS     = 2;
  localparam int NUM_REG    = 32;
  localparam int DATA_WIDTH = 64;
  localparam int NUM_ZERO   = 1;
  localparam bit OUTPUT_PL  = 0;
  localparam bit LOCKS_EN   = 1;
  localparam int AW         = (NUM_REG > 1) ? $clog2(NUM_REG) : 1;
  parameter bit VERBOSE_PASS = 1;

  typedef struct {
    string name;
    int checks;
    int pass;
    int fail;
    string status;
  } testcase_result_t;

  testcase_result_t tc_results[$];
  string current_tc_name;
  int current_tc_checks;
  int current_tc_pass;
  int current_tc_fail;
  int total_checks;
  int total_pass;
  int total_fail;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic clk;
  logic arst_n;
  logic [AW-1:0] rs_addr_i [NUM_RS];
  logic [DATA_WIDTH-1:0] rs_data_o [NUM_RS];
  logic [AW-1:0] rd_addr_i [NUM_RD];
  logic [DATA_WIDTH-1:0] rd_data_i [NUM_RD];
  logic rd_we_i [NUM_RD];
  logic [AW-1:0] rl_addr_i [NUM_RD];
  logic rl_we_i [NUM_RD];
  logic [NUM_REG-1:0] locks_o;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INSTANCES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_riscv_regfile #(
    .NUM_RD     (NUM_RD),
    .NUM_RS     (NUM_RS),
    .NUM_REG    (NUM_REG),
    .DATA_WIDTH (DATA_WIDTH),
    .NUM_ZERO   (NUM_ZERO),
    .OUTPUT_PL  (OUTPUT_PL),
    .LOCKS_EN   (LOCKS_EN)
  ) dut (
    .arst_ni   (arst_n),
    .clk_i     (clk),
    .rs_addr_i (rs_addr_i),
    .rs_data_o (rs_data_o),
    .rd_addr_i (rd_addr_i),
    .rd_data_i (rd_data_i),
    .rd_we_i   (rd_we_i),
    .rl_addr_i (rl_addr_i),
    .rl_we_i   (rl_we_i),
    .locks_o   (locks_o)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TASKS / FUNCTIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic clear_inputs();
    foreach (rs_addr_i[i]) rs_addr_i[i] = '0;
    foreach (rd_addr_i[i]) begin
      rd_addr_i[i] = '0;
      rd_data_i[i] = '0;
      rd_we_i[i]   = 1'b0;
    end
    foreach (rl_addr_i[i]) begin
      rl_addr_i[i] = '0;
      rl_we_i[i]   = 1'b0;
    end
  endtask

  task automatic reset_dut();
    arst_n = 1'b0;
    clear_inputs();
    clk = 1'b0;
    repeat (3) @(negedge clk);
    arst_n = 1'b1;
    repeat (2) @(negedge clk);
  endtask

  task automatic drive_write(
    input int idx,
    input int addr,
    input logic [DATA_WIDTH-1:0] data,
    input bit en
  );
    rd_addr_i[idx] = addr[AW-1:0];
    rd_data_i[idx] = data;
    rd_we_i[idx]   = en;
  endtask

  task automatic drive_lock(
    input int idx,
    input int addr,
    input bit en
  );
    rl_addr_i[idx] = addr[AW-1:0];
    rl_we_i[idx]   = en;
  endtask

  task automatic disable_writes();
    foreach (rd_we_i[i]) rd_we_i[i] = 1'b0;
  endtask

  task automatic disable_locks();
    foreach (rl_we_i[i]) rl_we_i[i] = 1'b0;
  endtask

  task automatic tc_begin(input string name);
    current_tc_name = name;
    current_tc_checks = 0;
    current_tc_pass = 0;
    current_tc_fail = 0;
    $display("\n--------------------------------------------------------------------");
    $display(">>> TESTCASE START: %s", current_tc_name);
    $display("--------------------------------------------------------------------");
  endtask

  task automatic tc_end();
    string status;

    status = (current_tc_fail == 0) ? "PASS" : "FAIL";
    $display("<<< TESTCASE END:   %s | checks=%0d pass=%0d fail=%0d | %s",
             current_tc_name, current_tc_checks, current_tc_pass, current_tc_fail, status);
    tc_results.push_back('{current_tc_name, current_tc_checks, current_tc_pass, current_tc_fail, status});
    note_case(current_tc_fail == 0);
    current_tc_name = "";
    current_tc_checks = 0;
    current_tc_pass = 0;
    current_tc_fail = 0;
  endtask

  function automatic void record_check(
    input string name,
    input bit pass,
    input string detail
  );
    total_checks++;
    current_tc_checks++;

    if (pass) begin
      total_pass++;
      current_tc_pass++;
      if (VERBOSE_PASS) begin
        $display("PASS @%0t: %s %s", $time, name, detail);
      end
    end else begin
      total_fail++;
      current_tc_fail++;
      $display("FAIL @%0t: %s %s", $time, name, detail);
    end
  endfunction

  function automatic void check_equal(
    input string name,
    input logic [DATA_WIDTH-1:0] got,
    input logic [DATA_WIDTH-1:0] exp
  );
    if (got === exp) begin
      record_check(name, 1'b1, $sformatf("got=%0h expected=%0h", got, exp));
    end else begin
      record_check(name, 1'b0, $sformatf("got=%0h expected=%0h", got, exp));
    end
  endfunction

  function automatic void check_bit(
    input string name,
    input logic got,
    input logic exp
  );
    if (got === exp) begin
      record_check(name, 1'b1, $sformatf("got=%0b expected=%0b", got, exp));
    end else begin
      record_check(name, 1'b0, $sformatf("got=%0b expected=%0b", got, exp));
    end
  endfunction

  task automatic print_tc_summary();
    int i;

    $display("\n=== FINAL TESTCASE SUMMARY ===");
    $display("%-22s %-7s %-7s %-7s %-7s", "TESTCASE", "CHECKS", "PASS", "FAIL", "STATUS");
    foreach (tc_results[i]) begin
      $display("%-22s %-7d %-7d %-7d %-7s",
               tc_results[i].name,
               tc_results[i].checks,
               tc_results[i].pass,
               tc_results[i].fail,
               tc_results[i].status);
    end
    $display("TOTAL: checks=%0d pass=%0d fail=%0d", total_checks, total_pass, total_fail);
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin : clk_gen
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin : main_initial

    logic [DATA_WIDTH-1:0] data_a;
    logic [DATA_WIDTH-1:0] data_b;

    reset_dut();

    // TC_001: basic write, immediate forwarding, and registered readback
    tc_begin("TC_001_basic_rw");
    data_a = 64'hA5A5_A5A5_A5A5_A5A5;
    data_b = 64'h5A5A_5A5A_5A5A_5A5A;

    drive_write(0, 5, data_a, 1'b1);
    rs_addr_i[0] = 5;
    rs_addr_i[1] = 7;
    #1;
    check_equal("TC_001_forwarding", rs_data_o[0], data_a);
    @(posedge clk);
    #1;
    disable_writes();
    #1;
    check_equal("TC_001_committed_read", rs_data_o[0], data_a);

    drive_write(0, 7, data_b, 1'b1);
    rs_addr_i[0] = 7;
    #1;
    check_equal("TC_001_write_then_read", rs_data_o[0], data_b);
    @(posedge clk);
    #1;
    disable_writes();
    tc_end();

    // TC_002: zero register is hardwired to zero
    tc_begin("TC_002_zero_reg");
    drive_write(0, 0, 64'hDEAD_BEEF_DEAD_BEEF, 1'b1);
    rs_addr_i[0] = 0;
    #1;
    check_equal("TC_002_zero_reg", rs_data_o[0], '0);
    @(posedge clk);
    #1;
    disable_writes();
    tc_end();

    // TC_003: lock mechanism and boundary write/read
    tc_begin("TC_003_lock_and_bounds");
    if (LOCKS_EN) begin
      drive_lock(0, 8, 1'b1);
      @(posedge clk);
      #1;
      disable_locks();
      #1;
      check_bit("TC_003_lock_set", locks_o[8], 1'b1);

      drive_write(0, 8, 64'h1111_2222_3333_4444, 1'b1);
      @(posedge clk);
      #1;
      disable_writes();
      #1;
      check_bit("TC_003_lock_clear", locks_o[8], 1'b0);
      rs_addr_i[0] = 8;
      #1;
      check_equal("TC_003_locked_write", rs_data_o[0], 64'h1111_2222_3333_4444);
    end

    drive_write(0, 31, 64'hCAFE_F00D_0000_0001, 1'b1);
    rs_addr_i[0] = 31;
    #1;
    check_equal("TC_003_last_reg", rs_data_o[0], 64'hCAFE_F00D_0000_0001);
    @(posedge clk);
    #1;
    disable_writes();
    tc_end();

    // TC_004: async reset mid-operation
    tc_begin("TC_004_async_reset");
    if (LOCKS_EN) begin
      drive_lock(0, 10, 1'b1);
      @(posedge clk);
      #1;
      disable_locks();
      #1;
      check_bit("TC_004_lock_before_reset", locks_o[10], 1'b1);
    end

    drive_write(0, 10, 64'hFFFF_FFFF_FFFF_FFFF, 1'b1);
    @(posedge clk);
    #1;
    disable_writes();
    #2;
    arst_n = 1'b0;
    #2;
    rs_addr_i[0] = 10;
    #1;
    check_equal("TC_004_async_reset_data", rs_data_o[0], '0);
    if (LOCKS_EN) begin
      check_bit("TC_004_async_reset_lock", locks_o[10], 1'b0);
    end
    arst_n = 1'b1;
    @(posedge clk);
    clear_inputs();
    tc_end();

    print_tc_summary();

    if (total_fail == 0) begin
      $display("TB PASS: adn_riscv_reg_file_tb");
    end else begin
      $display("TB FAIL: adn_riscv_reg_file_tb");
      $fatal(1, "adn_riscv_reg_file_tb failed");
    end
    $finish;
  end

endmodule
