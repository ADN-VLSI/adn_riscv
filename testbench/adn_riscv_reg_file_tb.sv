/*

| TEST CASE   | DATE       | AUTHOR          | DESCRIPTION                                            |
|-------------|------------|-----------------|--------------------------------------------------------|
| TC_RST_01   | 2026-08-19 | Motasim Faiyaz  | Asynchronous reset assertion while idle                |
| TC_RST_02   | 2026-08-19 | Motasim Faiyaz  | Asynchronous reset assertion mid-write                 |
| TC_RST_03   | 2026-08-19 | Motasim Faiyaz  | Reset de-assertion recovery                            |
| TC_BASIC_01 | 2026-08-19 | Motasim Faiyaz  | Write then immediate forwarded read                    |
| TC_BASIC_02 | 2026-08-19 | Annim Jannat    | Write then committed read after write disables         |
| TC_ZERO_01  | 2026-08-19 | Annim Jannat    | Zero register hardwired-to-zero check                  |
| TC_LOCK_01  | 2026-08-19 | Annim Jannat    | Lock set on request, cleared by its own write-back     |
| TC_LOCK_02  | 2026-08-19 | Annim Jannat    | Lock persists across idle cycles until write-back      |
| TC_LOCK_03  | 2026-08-19 | Annim Jannat    | Coincident lock-request and write-back, request wins   |
| TC_LOCK_04  | 2026-08-19 | Annim Jannat    | Independent locks on multiple distinct registers       |
| TC_COL_01   | 2026-08-19 | Annim Jannat    | Write port collision, higher-index port wins           |
| TC_GATE_01  | 2026-08-19 | Annim Jannat    | Write enable gating prevents modification              |
| TC_BOUND_01 | 2026-08-19 | Annim Jannat    | Boundary register (last index) access                  |
| TC_STR_01   | 2026-08-19 | Annim Jannat    | Back-to-back writes to the same register               |
| TC_STR_02   | 2026-08-19 | Annim Jannat    | Full register file sweep, write then read all          |
| TC_ROB_01   | 2026-08-19 | Annim Jannat    | Reset asserted while a lock is pending                 |
| TC_RAND_01  | 2026-08-19 | Annim Jannat    | Randomized directed write/read regression              |
| TC_ALL      | 2026-08-19 | Annim Jannat    | Run all test cases in sequence                         |

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                                 |
|----------|------------|-----------------|-------------------------------------------------------------|
| 0.1      | 2026-08-16 | Motasim Faiyaz  | Initial version, monolithic per-check style                 |
| 1.0      | 2026-08-16 | Annim Jannat    | Stable release                                              |
| 2.0      | 2026-08-19 | Annim Jannat    | Rebuilt around a generalized continuous scoreboard checker  |

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

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int  NUM_RD     = 2;
  localparam int  NUM_RS     = 2;
  localparam int  NUM_REG    = 32;
  localparam int  DATA_WIDTH = 64;
  localparam int  NUM_ZERO   = 1;
  localparam bit  OUTPUT_PL  = 0;
  localparam bit  LOCKS_EN   = 1;
  localparam int  AW         = (NUM_REG > 1) ? $clog2(NUM_REG) : 1;
  localparam time CLKPeriod  = 10ns;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic                  clk;
  logic                  arst_n;
  logic [AW-1:0]         rs_addr_i [NUM_RS];
  logic [DATA_WIDTH-1:0] rs_data_o [NUM_RS];
  logic [AW-1:0]         rd_addr_i [NUM_RD];
  logic [DATA_WIDTH-1:0] rd_data_i [NUM_RD];
  logic                  rd_we_i   [NUM_RD];
  logic [AW-1:0]         rl_addr_i [NUM_RD];
  logic                  rl_en_i   [NUM_RD];
  logic [NUM_REG-1:0]    locks_o;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  bit is_clk_edge_aligned;  // safe window after posedge for driving new stimulus

  // Reference / shadow model: mirrors the DUT's committed architectural state.
  // The continuous checker (see METHODS) folds in any writes/locks currently
  // asserted on top of this to reproduce the DUT's combinational forwarding.
  logic [DATA_WIDTH-1:0] shadow_regs  [NUM_REG];
  logic [NUM_REG-1:0]    shadow_locks;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
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
    .rl_en_i   (rl_en_i),
    .locks_o   (locks_o)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // none required - all reference state is maintained procedurally in METHODS

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  always @(posedge clk) begin
    is_clk_edge_aligned <= arst_n;
    #1ns;
    is_clk_edge_aligned <= '0;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Task to apply reset and clear all DUT inputs plus the shadow model
  task automatic apply_reset();
    #100ns;
    clk    <= '0;
    arst_n <= '0;
    foreach (rs_addr_i[i]) rs_addr_i[i] <= '0;
    foreach (rd_addr_i[i]) begin
      rd_addr_i[i] <= '0;
      rd_data_i[i] <= '0;
      rd_we_i[i]   <= 1'b0;
    end
    foreach (rl_addr_i[i]) begin
      rl_addr_i[i] <= '0;
      rl_en_i[i]   <= 1'b0;
    end
    foreach (shadow_regs[i]) shadow_regs[i] <= '0;
    shadow_locks <= '0;
    #100ns;
    arst_n <= '1;
    #100ns;
  endtask

  task automatic start_clock();
    fork
      forever #(CLKPeriod / 2) clk <= ~clk;
    join_none
    @(posedge clk);
  endtask

  // Wait for the aligned window right after a posedge before driving new stimulus
  task automatic wait_drive_window();
    wait (is_clk_edge_aligned);
  endtask

  // Set one write port's inputs without advancing the clock (for same-cycle
  // multi-port scenarios); pair with advance_clk() once all ports are set
  task automatic set_write(input int idx, input int addr, input logic [DATA_WIDTH-1:0] data, input bit en);
    wait_drive_window();
    rd_addr_i[idx] <= addr[AW-1:0];
    rd_data_i[idx] <= data;
    rd_we_i[idx]   <= en;
  endtask

  task automatic set_lock(input int idx, input int addr, input bit en);
    wait_drive_window();
    rl_addr_i[idx] <= addr[AW-1:0];
    rl_en_i[idx]   <= en;
  endtask

  task automatic set_read(input int idx, input int addr);
    rs_addr_i[idx] <= addr[AW-1:0];
  endtask

  task automatic advance_clk();
    @(posedge clk);
  endtask

  // Convenience wrappers: drive a single port and advance one cycle
  task automatic drive_write(input int idx, input int addr, input logic [DATA_WIDTH-1:0] data, input bit en);
    set_write(idx, addr, data, en);
    advance_clk();
  endtask

  task automatic drive_lock(input int idx, input int addr, input bit en);
    set_lock(idx, addr, en);
    advance_clk();
  endtask

  task automatic clear_all_writes();
    wait_drive_window();
    foreach (rd_we_i[i]) rd_we_i[i] <= 1'b0;
  endtask

  task automatic clear_all_locks();
    wait_drive_window();
    foreach (rl_en_i[i]) rl_en_i[i] <= 1'b0;
  endtask

  // Expected value for a read port right now: committed shadow value with any
  // write currently asserted on that address folded in, last matching port wins
  function automatic logic [DATA_WIDTH-1:0] expected_forward_reg(input int addr);
    logic [DATA_WIDTH-1:0] val;
    val = (addr < NUM_ZERO) ? '0 : shadow_regs[addr];
    if (addr >= NUM_ZERO) begin
      for (int i = 0; i < NUM_RD; i++)
        if (rd_we_i[i] && (rd_addr_i[i] == addr)) val = rd_data_i[i];
    end
    return val;
  endfunction

  // Expected lock bit right now: committed shadow lock with a same-cycle
  // write-back clear applied first, then a same-cycle new request re-asserting
  // it - matching the DUT's observed priority where the issuing op always wins
  function automatic logic expected_forward_lock(input int addr);
    logic val;
    val = shadow_locks[addr];
    if (addr >= NUM_ZERO) begin
      for (int i = 0; i < NUM_RD; i++)
        if (rd_we_i[i] && (rd_addr_i[i] == addr)) val = 1'b0;
      for (int i = 0; i < NUM_RD; i++)
        if (rl_en_i[i] && (rl_addr_i[i] == addr)) val = 1'b1;
    end
    return val;
  endfunction

  `define CHECK_EQ(__EXP__, __GOT__, __LABEL__)                                 \
    if (``__EXP__`` === ``__GOT__``) begin                                      \
      note_case(1);                                                             \
      if (debug) begin                                                         \
        $display(`"``__LABEL__`` MATCH: got=%0h exp=%0h [%0t]`",               \
                  ``__GOT__``, ``__EXP__``, $realtime);                        \
      end                                                                      \
    end else begin                                                             \
      note_case(0);                                                            \
      $display(`"``__LABEL__`` MISMATCH: got=%0h exp=%0h [%0t]`",              \
                ``__GOT__``, ``__EXP__``, $realtime);                          \
    end

  `define CHECK_BIT(__EXP__, __GOT__, __LABEL__)                                \
    if (``__EXP__`` === ``__GOT__``) begin                                      \
      note_case(1);                                                             \
      if (debug) begin                                                         \
        $display(`"``__LABEL__`` MATCH: got=%0b exp=%0b [%0t]`",               \
                  ``__GOT__``, ``__EXP__``, $realtime);                        \
      end                                                                      \
    end else begin                                                             \
      note_case(0);                                                            \
      $display(`"``__LABEL__`` MISMATCH: got=%0b exp=%0b [%0t]`",              \
                ``__GOT__``, ``__EXP__``, $realtime);                          \
    end

  task automatic check_reads();
    for (int p = 0; p < NUM_RS; p++) begin
      `CHECK_EQ(expected_forward_reg(rs_addr_i[p]), rs_data_o[p], REG_READ)
    end
  endtask

  task automatic check_locks();
    if (LOCKS_EN) begin
      for (int a = 0; a < NUM_REG; a++) begin
        `CHECK_BIT(expected_forward_lock(a), locks_o[a], LOCK)
      end
    end
  endtask

  `undef CHECK_EQ
  `undef CHECK_BIT

  // Continuous scoreboard: runs identically for every test case. One process
  // commits architectural state at each clock edge (and clears it on reset);
  // the other re-validates DUT outputs any time a relevant input changes.
  // Individual TC tasks only need to drive stimulus - no manual checks.
  task automatic start_checking();
    fork
      forever @(posedge clk or negedge arst_n) begin
        if (~arst_n) begin
          foreach (shadow_regs[i]) shadow_regs[i] <= '0;
          shadow_locks <= '0;
        end else begin
          for (int i = 0; i < NUM_RD; i++)
            if (rd_we_i[i] && (rd_addr_i[i] >= NUM_ZERO)) shadow_regs[rd_addr_i[i]] <= rd_data_i[i];

          for (int i = 0; i < NUM_RD; i++)
            if (rd_we_i[i] && (rd_addr_i[i] >= NUM_ZERO)) shadow_locks[rd_addr_i[i]] <= 1'b0;
          for (int i = 0; i < NUM_RD; i++)
            if (rl_en_i[i] && (rl_addr_i[i] >= NUM_ZERO)) shadow_locks[rl_addr_i[i]] <= 1'b1;
        end
      end

      forever @(rs_addr_i[0], rs_addr_i[1],
                rd_addr_i[0], rd_addr_i[1], rd_data_i[0], rd_data_i[1], rd_we_i[0], rd_we_i[1],
                rl_addr_i[0], rl_addr_i[1], rl_en_i[0], rl_en_i[1]) begin
        if (arst_n) begin
          #0;
          check_reads();
          check_locks();
        end
      end
    join_none
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST CASE TASKS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic run_tc_rst_01();
    apply_reset();
    set_read(0, 11);
    advance_clk();
  endtask

  task automatic run_tc_rst_02();
    apply_reset();
    set_write(0, 9, 64'hFEED_FACE_0000_0001, 1'b1);
    arst_n <= '0;
    #(CLKPeriod / 2);
    apply_reset();
    set_read(0, 9);
    advance_clk();
  endtask

  task automatic run_tc_rst_03();
    apply_reset();
    drive_write(0, 4, 64'h1122_3344_5566_7788, 1'b1);
    clear_all_writes();
    advance_clk();
  endtask

  task automatic run_tc_basic_01();
    apply_reset();
    set_write(0, 5, 64'hA5A5_A5A5_A5A5_A5A5, 1'b1);
    set_read(0, 5);
    advance_clk();
    clear_all_writes();
    advance_clk();
  endtask

  task automatic run_tc_basic_02();
    apply_reset();
    drive_write(0, 7, 64'h5A5A_5A5A_5A5A_5A5A, 1'b1);
    clear_all_writes();
    set_read(0, 7);
    advance_clk();
  endtask

  task automatic run_tc_zero_01();
    apply_reset();
    drive_write(0, 0, 64'hDEAD_BEEF_DEAD_BEEF, 1'b1);
    clear_all_writes();
    set_read(0, 0);
    advance_clk();
  endtask

  task automatic run_tc_lock_01();
    apply_reset();
    drive_lock(0, 8, 1'b1);
    clear_all_locks();
    advance_clk();
    drive_write(0, 8, 64'h1111_2222_3333_4444, 1'b1);
    clear_all_writes();
    advance_clk();
  endtask

  task automatic run_tc_lock_02();
    apply_reset();
    drive_lock(0, 12, 1'b1);
    clear_all_locks();
    repeat (5) advance_clk();
    drive_write(0, 12, 64'h0000_0000_0000_0001, 1'b1);
    clear_all_writes();
    advance_clk();
  endtask

  task automatic run_tc_lock_03();
    apply_reset();
    set_lock(0, 15, 1'b1);
    set_write(1, 15, 64'h9999_8888_7777_6666, 1'b1);
    advance_clk();
    clear_all_locks();
    clear_all_writes();
    advance_clk();
    drive_write(0, 15, 64'hAAAA_BBBB_CCCC_DDDD, 1'b1);
    clear_all_writes();
    advance_clk();
  endtask

  task automatic run_tc_lock_04();
    apply_reset();
    set_lock(0, 3, 1'b1);
    set_lock(1, 21, 1'b1);
    advance_clk();
    clear_all_locks();
    advance_clk();
    drive_write(0, 3, 64'h1, 1'b1);
    clear_all_writes();
    advance_clk();
    drive_write(0, 21, 64'h1, 1'b1);
    clear_all_writes();
    advance_clk();
  endtask

  task automatic run_tc_col_01();
    apply_reset();
    set_write(0, 14, 64'hAAAA_AAAA_AAAA_AAAA, 1'b1);
    set_write(1, 14, 64'hBBBB_BBBB_BBBB_BBBB, 1'b1);
    advance_clk();
    clear_all_writes();
    set_read(0, 14);
    advance_clk();
  endtask

  task automatic run_tc_gate_01();
    apply_reset();
    drive_write(0, 25, 64'h1111_1111_1111_1111, 1'b1);
    clear_all_writes();
    drive_write(0, 25, 64'hFFFF_FFFF_FFFF_FFFF, 1'b0);
    clear_all_writes();
    set_read(0, 25);
    advance_clk();
  endtask

  task automatic run_tc_bound_01();
    apply_reset();
    drive_write(0, NUM_REG - 1, 64'hCAFE_F00D_0000_0001, 1'b1);
    clear_all_writes();
    set_read(0, NUM_REG - 1);
    advance_clk();
  endtask

  task automatic run_tc_str_01();
    apply_reset();
    drive_write(0, 18, 64'h0000_0000_0000_0001, 1'b1);
    drive_write(0, 18, 64'h0000_0000_0000_0002, 1'b1);
    drive_write(0, 18, 64'h0000_0000_0000_0003, 1'b1);
    clear_all_writes();
    set_read(0, 18);
    advance_clk();
  endtask

  task automatic run_tc_str_02();
    apply_reset();
    for (int a = NUM_ZERO; a < NUM_REG; a++) drive_write(0, a, DATA_WIDTH'(a), 1'b1);
    clear_all_writes();
    for (int a = NUM_ZERO; a < NUM_REG; a++) begin
      set_read(0, a);
      advance_clk();
    end
  endtask

  task automatic run_tc_rob_01();
    apply_reset();
    set_lock(0, 6, 1'b1);
    advance_clk();
    clear_all_locks();
    arst_n <= '0;
    #(CLKPeriod / 2);
    apply_reset();
  endtask

  task automatic run_tc_rand_01();
    int                    addr_rand;
    logic [DATA_WIDTH-1:0] data_rand;

    apply_reset();
    for (int iter = 0; iter < 60; iter++) begin
      addr_rand = $urandom_range(NUM_REG - 1, 0);
      data_rand = {$urandom, $urandom};
      drive_write(0, addr_rand, data_rand, 1'b1);
      clear_all_writes();
      set_read(0, addr_rand);
      advance_clk();
    end
  endtask

  task automatic run_tc_all();
    run_tc_rst_01();
    run_tc_rst_02();
    run_tc_rst_03();
    run_tc_basic_01();
    run_tc_basic_02();
    run_tc_zero_01();
    run_tc_lock_01();
    run_tc_lock_02();
    run_tc_lock_03();
    run_tc_lock_04();
    run_tc_col_01();
    run_tc_gate_01();
    run_tc_bound_01();
    run_tc_str_01();
    run_tc_str_02();
    run_tc_rob_01();
    run_tc_rand_01();
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin

    apply_reset();

    start_clock();

    start_checking();

    case (test_name)
      "TC_RST_01"   :  run_tc_rst_01();
      "TC_RST_02"   :  run_tc_rst_02();
      "TC_RST_03"   :  run_tc_rst_03();
      "TC_BASIC_01" :  run_tc_basic_01();
      "TC_BASIC_02" :  run_tc_basic_02();
      "TC_ZERO_01"  :  run_tc_zero_01();
      "TC_LOCK_01"  :  run_tc_lock_01();
      "TC_LOCK_02"  :  run_tc_lock_02();
      "TC_LOCK_03"  :  run_tc_lock_03();
      "TC_LOCK_04"  :  run_tc_lock_04();
      "TC_COL_01"   :  run_tc_col_01();
      "TC_GATE_01"  :  run_tc_gate_01();
      "TC_BOUND_01" :  run_tc_bound_01();
      "TC_STR_01"   :  run_tc_str_01();
      "TC_STR_02"   :  run_tc_str_02();
      "TC_ROB_01"   :  run_tc_rob_01();
      "TC_RAND_01"  :  run_tc_rand_01();
      "TC_ALL"      :  run_tc_all();

      default: run_tc_all();
    endcase

    #100ns;
    // Finish simulation
    $finish;
  end

endmodule
