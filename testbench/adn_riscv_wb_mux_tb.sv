/*
| TEST CASE   | DATE       | AUTHOR              | DESCRIPTION                                                                           |
| ----------- | ---------- | ------------------- | ------------------------------------------------------------------------------------- |
| TC_RST_01   | 2026-09-13 | Ahasan Ullah Khalid | Idle/reset condition verification with zero requests                                  |
| TC_PRIO_01  | 2026-09-13 | Ahasan Ullah Khalid | Single-port isolated request and routing verification across all channels             |
| TC_PRIO_02  | 2026-09-13 | Ahasan Ullah Khalid | Full contention priority resolution (arbitration under simultaneous requests)         |
| TC_SIGN_01  | 2026-09-13 | Ahasan Ullah Khalid | Sign-extension and zero-extension validation on sub-word write data                   |
| TC_B2B_01   | 2026-09-13 | Ahasan Ullah Khalid | Back-to-back switching of active requester channels across consecutive cycles         |
| TC_ALL      | 2026-09-13 | Ahasan Ullah Khalid | Regression suite executing all write-back multiplexer test cases sequentially         |

| REVISION | DATE       | AUTHOR              | DESCRIPTION                                                                           |
| -------- | ---------- | ------------------- | ------------------------------------------------------------------------------------- |
| 1.0      | 2026-09-13 | Ahasan Ullah Khalid | Initial testbench adhering to ADN VIP verification standards                          |

Author : Ahasan Ullah Khalid (aukhalid02@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information
*/

module adn_riscv_wb_mux_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS & INCLUDES
  //////////////////////////////////////////////////////////////////////////////////////////////////
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS & TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  localparam time CLKPeriod = 10ns;
  localparam time CLKHalfPeriod = 5ns;

  localparam int NUM_REQ = 4;
  localparam bit HIGH_INDEX_PRIORITY = 1'b0;

  // Packed structure matching DUT's internal member accesses: .addr, .data, .size, .sign
  typedef struct packed {
    logic [5:0]  addr;
    logic [63:0] data;
    logic [1:0]  size;
    logic        sign;
  } write_back_t;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  logic                      clk;
  logic                      rst_n;

  write_back_t [NUM_REQ-1:0] wb_i;
  logic        [NUM_REQ-1:0] req_i;
  logic        [NUM_REQ-1:0] gnt_o;
  logic        [        5:0] rd_addr_o;
  logic        [       63:0] rd_data_o;
  logic                      rd_en_o;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////
  bit                        is_clk_edge_aligned;

  typedef struct {
    logic [NUM_REQ-1:0] exp_gnt;
    logic [5:0]         exp_rd_addr;
    logic [63:0]        exp_rd_data;
    logic               exp_rd_en;
  } exp_wb_t;

  exp_wb_t exp_fifo[$];

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  adn_riscv_wb_mux #(
      .write_back_t       (write_back_t),
      .NUM_REQ            (NUM_REQ),
      .HIGH_INDEX_PRIORITY(HIGH_INDEX_PRIORITY)
  ) u_dut (
      .wb_i     (wb_i),
      .req_i    (req_i),
      .gnt_o    (gnt_o),
      .rd_addr_o(rd_addr_o),
      .rd_data_o(rd_data_o),
      .rd_en_o  (rd_en_o)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  always @(posedge clk) begin
    is_clk_edge_aligned <= rst_n;
    #1ns;
    is_clk_edge_aligned <= '0;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // HELPER FUNCTIONS & METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  function automatic logic [63:0] sign_extend_model(input logic [63:0] in_data,
                                                    input logic [1:0] size, input logic sign);
    logic [63:0] result;
    case ({
      size, sign
    })
      3'b000:  result = {56'b0, in_data[7:0]};
      3'b001:  result = {{56{in_data[7]}}, in_data[7:0]};
      3'b010:  result = {48'b0, in_data[15:0]};
      3'b011:  result = {{48{in_data[15]}}, in_data[15:0]};
      3'b100:  result = {32'b0, in_data[31:0]};
      3'b101:  result = {{32{in_data[31]}}, in_data[31:0]};
      default: result = in_data;
    endcase
    return result;
  endfunction

  function automatic exp_wb_t compute_expected(input write_back_t [NUM_REQ-1:0] wbs,
                                               input logic [NUM_REQ-1:0] reqs);
    exp_wb_t exp;
    int winner;
    bit found;

    winner = -1;
    found = 1'b0;
    exp.exp_gnt = '0;

    if (HIGH_INDEX_PRIORITY) begin
      for (int i = NUM_REQ - 1; i >= 0; i--) begin
        if (reqs[i] && !found) begin
          winner         = i;
          found          = 1'b1;
          exp.exp_gnt[i] = 1'b1;
        end
      end
    end else begin
      for (int i = 0; i < NUM_REQ; i++) begin
        if (reqs[i] && !found) begin
          winner         = i;
          found          = 1'b1;
          exp.exp_gnt[i] = 1'b1;
        end
      end
    end

    if (found) begin
      exp.exp_rd_addr = wbs[winner].addr;
      exp.exp_rd_en   = 1'b1;
      exp.exp_rd_data = sign_extend_model(wbs[winner].data, wbs[winner].size, wbs[winner].sign);
    end else begin
      exp.exp_rd_addr = '0;
      exp.exp_rd_en   = 1'b0;
      exp.exp_rd_data = '0;
    end

    return exp;
  endfunction

  task automatic start_clock();
    fork
      forever #CLKHalfPeriod clk <= ~clk;
    join_none
    @(posedge clk);
  endtask

  task automatic apply_reset();
    rst_n <= 1'b0;
    wb_i  <= '0;
    req_i <= '0;
    exp_fifo.delete();
    repeat (5) @(posedge clk);
    rst_n <= 1'b1;
    repeat (5) @(posedge clk);
  endtask

  task automatic send_cycle_stimulus(input write_back_t [NUM_REQ-1:0] wbs,
                                     input logic [NUM_REQ-1:0] reqs);
    exp_wb_t exp;
    exp = compute_expected(wbs, reqs);
    exp_fifo.push_back(exp);

    wait (is_clk_edge_aligned);
    wb_i  <= wbs;
    req_i <= reqs;
    @(posedge clk);
  endtask

  task automatic start_checking();
    fork
      forever
      @(posedge clk) begin
        #1ps;
        if (rst_n && exp_fifo.size() > 0) begin
          exp_wb_t exp = exp_fifo.pop_front();

          // Grant vector check
          if (gnt_o === exp.exp_gnt) begin
            note_case(1);
          end else begin
            note_case(0);
            $display("[%s] [FAIL] Grant mismatch! Got: %b, Exp: %b [%0t]", test_name, gnt_o,
                     exp.exp_gnt, $realtime);
          end

          // Write enable check
          if (rd_en_o === exp.exp_rd_en) begin
            note_case(1);
          end else begin
            note_case(0);
            $display("[%s] [FAIL] Write enable mismatch! Got: %b, Exp: %b [%0t]", test_name,
                     rd_en_o, exp.exp_rd_en, $realtime);
          end

          // Address and Data verification when transaction is active
          if (exp.exp_rd_en) begin
            if (rd_addr_o === exp.exp_rd_addr) begin
              note_case(1);
            end else begin
              note_case(0);
              $display("[%s] [FAIL] Selected address mismatch! Got: 0x%02x, Exp: 0x%02x [%0t]",
                       test_name, rd_addr_o, exp.exp_rd_addr, $realtime);
            end

            if (rd_data_o === exp.exp_rd_data) begin
              note_case(1);
              if (debug) begin
                $display("[%s] [PASS] Mux output match! Addr: 0x%02x, Data: 0x%016x [%0t]",
                         test_name, rd_addr_o, rd_data_o, $realtime);
              end
            end else begin
              note_case(0);
              $display("[%s] [FAIL] Selected data mismatch! Got: 0x%016x, Exp: 0x%016x [%0t]",
                       test_name, rd_data_o, exp.exp_rd_data, $realtime);
            end
          end
        end
      end
    join_none
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST CASE TASKS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic run_tc_rst_01();
    apply_reset();
    #1ps;
    if (gnt_o === '0 && rd_en_o === 1'b0) begin
      note_case(1);
    end else begin
      note_case(0);
      $display("[%s] [FAIL] Default reset state check failed! gnt_o=%b, rd_en_o=%b [%0t]",
               test_name, gnt_o, rd_en_o, $realtime);
    end
    repeat (5) @(posedge clk);
  endtask

  task automatic run_tc_prio_01();
    write_back_t [NUM_REQ-1:0] test_wbs;
    logic        [NUM_REQ-1:0] test_reqs;

    apply_reset();

    for (int i = 0; i < NUM_REQ; i++) begin
      test_wbs         = '0;
      test_reqs        = '0;

      test_wbs[i].addr = 6'(i + 1);
      test_wbs[i].data = 64'h1000_2000_3000_4000 | (64'(i) << 32);
      test_wbs[i].size = 2'b11;  // 64-bit doubleword
      test_wbs[i].sign = 1'b0;
      test_reqs[i]     = 1'b1;

      send_cycle_stimulus(test_wbs, test_reqs);
    end

    send_cycle_stimulus('0, '0);
    repeat (5) @(posedge clk);
  endtask

  task automatic run_tc_prio_02();
    write_back_t [NUM_REQ-1:0] test_wbs;
    logic        [NUM_REQ-1:0] test_reqs;

    apply_reset();

    for (int i = 0; i < NUM_REQ; i++) begin
      test_wbs[i].addr = 6'(i + 10);
      test_wbs[i].data = 64'hAAAA_BBBB_CCCC_DDD0 | 64'(i);
      test_wbs[i].size = 2'b11;
      test_wbs[i].sign = 1'b0;
    end

    // Port 0, 1, 2, 3 requesting simultaneously -> Port 0 should win (LOW_INDEX_PRIORITY)
    test_reqs = 4'b1111;
    send_cycle_stimulus(test_wbs, test_reqs);

    // Port 1, 2, 3 requesting -> Port 1 wins
    test_reqs = 4'b1110;
    send_cycle_stimulus(test_wbs, test_reqs);

    // Port 2, 3 requesting -> Port 2 wins
    test_reqs = 4'b1100;
    send_cycle_stimulus(test_wbs, test_reqs);

    // Only Port 3 requesting -> Port 3 wins
    test_reqs = 4'b1000;
    send_cycle_stimulus(test_wbs, test_reqs);

    send_cycle_stimulus('0, '0);
    repeat (5) @(posedge clk);
  endtask

  task automatic run_tc_sign_01();
    write_back_t [NUM_REQ-1:0] test_wbs;
    logic        [NUM_REQ-1:0] test_reqs;

    apply_reset();

    test_wbs         = '0;
    test_reqs        = '0;
    test_reqs[0]     = 1'b1;
    test_wbs[0].addr = 6'd22;

    // 8-bit negative sign extension: 0x9F -> 0xFFFF_FFFF_FFFF_FF9F
    test_wbs[0].data = 64'h0000_0000_0000_009F;
    test_wbs[0].size = 2'b00;
    test_wbs[0].sign = 1'b1;
    send_cycle_stimulus(test_wbs, test_reqs);

    // 8-bit unsigned zero extension: 0x9F -> 0x0000_0000_0000_009F
    test_wbs[0].sign = 1'b0;
    send_cycle_stimulus(test_wbs, test_reqs);

    // 16-bit negative sign extension: 0xABCD -> 0xFFFF_FFFF_FFFF_ABCD
    test_wbs[0].data = 64'h0000_0000_0000_ABCD;
    test_wbs[0].size = 2'b01;
    test_wbs[0].sign = 1'b1;
    send_cycle_stimulus(test_wbs, test_reqs);

    // 16-bit unsigned zero extension: 0xABCD -> 0x0000_0000_0000_ABCD
    test_wbs[0].sign = 1'b0;
    send_cycle_stimulus(test_wbs, test_reqs);

    // 32-bit negative sign extension: 0x8123_4567 -> 0xFFFF_FFFF_8123_4567
    test_wbs[0].data = 64'h0000_0000_8123_4567;
    test_wbs[0].size = 2'b10;
    test_wbs[0].sign = 1'b1;
    send_cycle_stimulus(test_wbs, test_reqs);

    // 32-bit unsigned zero extension: 0x8123_4567 -> 0x0000_0000_8123_4567
    test_wbs[0].sign = 1'b0;
    send_cycle_stimulus(test_wbs, test_reqs);

    send_cycle_stimulus('0, '0);
    repeat (5) @(posedge clk);
  endtask

  task automatic run_tc_b2b_01();
    write_back_t [NUM_REQ-1:0] test_wbs;
    logic        [NUM_REQ-1:0] test_reqs;

    apply_reset();

    for (int cycle = 0; cycle < 10; cycle++) begin
      test_wbs  = '0;
      test_reqs = '0;

      for (int i = 0; i < NUM_REQ; i++) begin
        test_wbs[i].addr = 6'(cycle * 4 + i);
        test_wbs[i].data = 64'h4444_0000_0000_0000 | (64'(cycle) << 16) | 64'(i);
        test_wbs[i].size = 2'b11;
        test_wbs[i].sign = 1'b0;
      end

      test_reqs = logic'($urandom_range(1, 15));
      send_cycle_stimulus(test_wbs, test_reqs);
    end

    send_cycle_stimulus('0, '0);
    repeat (10) @(posedge clk);
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  initial begin
    clk   = '0;
    rst_n = '0;
    wb_i  = '0;
    req_i = '0;

    start_clock();
    start_checking();

    case (test_name)
      "TC_RST_01":  run_tc_rst_01();
      "TC_PRIO_01": run_tc_prio_01();
      "TC_PRIO_02": run_tc_prio_02();
      "TC_SIGN_01": run_tc_sign_01();
      "TC_B2B_01":  run_tc_b2b_01();
      "TC_ALL": begin
        run_tc_rst_01();
        run_tc_prio_01();
        run_tc_prio_02();
        run_tc_sign_01();
        run_tc_b2b_01();
      end

      default: begin
        $fatal(1, "Unrecognized test_name '%s'", test_name);
      end
    endcase

    #100ns;
    $finish;
  end

endmodule
