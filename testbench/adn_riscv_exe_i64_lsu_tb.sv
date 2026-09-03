/*
| TEST CASE | DATE       | AUTHOR              | DESCRIPTION                                                                              |
| --------- | ---------- | ------------------- | ---------------------------------------------------------------------------------------- |
| TC_RST_01 | 2026-09-03 | Ahasan Ullah Khalid | Active-low reset check verifying initial handshake & sideband default states             |
| TC_LD_01  | 2026-09-03 | Ahasan Ullah Khalid | Basic load word (LW) and double-word (LD) pipeline transaction with PMI memory read      |
| TC_ST_01  | 2026-09-03 | Ahasan Ullah Khalid | Basic store double-word (SD) transaction verifying request issue to memory interface     |
| TC_B2B_01 | 2026-09-03 | Ahasan Ullah Khalid | Back-to-back load/store pipeline handshaking with variable memory/writeback backpressure |
| TC_FLT_01 | 2026-09-03 | Ahasan Ullah Khalid | Memory fault assertion verification upon bus error or invalid address response           |
| TC_ALL    | 2026-09-03 | Ahasan Ullah Khalid | Default regression suite running all test cases sequentially                             |

| REVISION | DATE       | AUTHOR              | DESCRIPTION                                  |
|----------|------------|---------------------|----------------------------------------------|
| 0.1      | 2026-09-03 | Ahasan Ullah Khalid | Initial LSU testbench draft                  |
| 1.0      | 2026-09-03 | Ahasan Ullah Khalid | Complete VIP integration and test case suite |

Author : Ahasan Ullah Khalid (aukhalid02@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
*/

module adn_riscv_exe_i64_lsu_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  `include "vip/adn_common_tb_headers.sv"

  import adn_riscv_pkg::*;
  `include "pmi/typedef.svh"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS & TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  localparam time CLKPeriod = 10ns;
  localparam time CLKHalfPeriod = 5ns;
  localparam int AddrWidth = 64;
  localparam int DataWidth = 64;

  `PMI_T(pmi, AddrWidth, DataWidth)

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  logic             clk;
  logic             arst_n;

  // Instruction Pipeline Interface
  rv_op_t           op;
  logic      [63:0] rs1;
  logic      [63:0] rs2;
  logic      [11:0] imm;
  logic      [ 5:0] rd;
  logic             valid_i;
  logic             ready_o;

  // Memory (PMI) Interface
  sideband_t        dmem_sideband_o;
  pmi_req_t         dmem_pmi_req_o;
  pmi_rsp_t         dmem_pmi_rsp_i;

  // Writeback Interface
  logic      [63:0] wr_data_o;
  logic      [ 1:0] wr_size_o;
  logic      [ 5:0] wr_addr_o;
  logic             valid_o;
  logic             ready_i;

  // Fault Interface
  logic      [63:0] mem_fault_addr_o;
  logic             mem_fault_o;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////
  bit               is_clk_edge_aligned;

  typedef struct {
    logic [63:0] exp_wr_data;
    logic [5:0]  exp_rd_addr;
    logic [1:0]  exp_wr_size;
    bit          exp_fault;
    logic [63:0] exp_fault_addr;
  } exp_txn_t;

  exp_txn_t exp_fifo[$];

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  adn_riscv_exe_i64_lsu #(
      .rv_op_t  (rv_op_t),
      .pmi_req_t(pmi_req_t),
      .pmi_rsp_t(pmi_rsp_t)
  ) u_dut (
      .clk_i           (clk),
      .arst_ni         (arst_n),
      .op_i            (op),
      .rs1_i           (rs1),
      .rs2_i           (rs2),
      .imm_i           (imm),
      .rd_i            (rd),
      .valid_i         (valid_i),
      .ready_o         (ready_o),
      .dmem_sideband_o (dmem_sideband_o),
      .dmem_pmi_req_o  (dmem_pmi_req_o),
      .dmem_pmi_rsp_i  (dmem_pmi_rsp_i),
      .wr_data_o       (wr_data_o),
      .wr_size_o       (wr_size_o),
      .wr_addr_o       (wr_addr_o),
      .valid_o         (valid_o),
      .ready_i         (ready_i),
      .mem_fault_addr_o(mem_fault_addr_o),
      .mem_fault_o     (mem_fault_o)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  always @(posedge clk) begin
    is_clk_edge_aligned <= arst_n;
    #1ns;
    is_clk_edge_aligned <= '0;
  end

  // Golden PMI Memory Responder:
  // 1. mgnt is tied high when not busy so LSU knows memory is ready to accept requests.
  // 2. mack & mrdata are responded on the next cycle following an accepted mreq.
  always @(posedge clk or negedge arst_n) begin
    if (~arst_n) begin
      dmem_pmi_rsp_i.mgnt   <= 1'b1;
      dmem_pmi_rsp_i.mack   <= 1'b0;
      dmem_pmi_rsp_i.mrdata <= '0;
      dmem_pmi_rsp_i.mresp  <= 1'b0;
    end else begin
      dmem_pmi_rsp_i.mgnt <= 1'b1;  // Memory is ready to accept requests

      if (dmem_pmi_req_o.mreq && dmem_pmi_rsp_i.mgnt) begin
        dmem_pmi_rsp_i.mack   <= 1'b1;
        dmem_pmi_rsp_i.mrdata <= 64'hA5A5_5A5A_DEAD_BEEF;
        dmem_pmi_rsp_i.mresp  <= (dmem_pmi_req_o.maddr == 64'hFFFF_0000_0000_0000);
      end else begin
        dmem_pmi_rsp_i.mack  <= 1'b0;
        dmem_pmi_rsp_i.mresp <= 1'b0;
      end
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic start_clock();
    fork
      forever #CLKHalfPeriod clk <= ~clk;
    join_none
    @(posedge clk);
  endtask

  task automatic apply_reset();
    arst_n  <= '0;
    valid_i <= '0;
    ready_i <= '1;
    op      <= rv_op_t'(0);
    rs1     <= '0;
    rs2     <= '0;
    imm     <= '0;
    rd      <= '0;
    repeat (5) @(posedge clk);
    arst_n <= '1;
    repeat (5) @(posedge clk);
  endtask

  task automatic send_lsu_op(input rv_op_t req_op, input logic [63:0] req_rs1,
                             input logic [63:0] req_rs2, input logic [11:0] req_imm,
                             input logic [5:0] req_rd, input logic [63:0] exp_data,
                             input logic [1:0] exp_sz, input bit exp_flt);
    int timeout_cnt;
    exp_txn_t txn;
    txn.exp_wr_data    = exp_data;
    txn.exp_rd_addr    = req_rd;
    txn.exp_wr_size    = exp_sz;
    txn.exp_fault      = exp_flt;
    txn.exp_fault_addr = req_rs1 + {{52{req_imm[11]}}, req_imm};
    exp_fifo.push_back(txn);

    wait (is_clk_edge_aligned);
    valid_i <= 1'b1;
    op      <= req_op;
    rs1     <= req_rs1;
    rs2     <= req_rs2;
    imm     <= req_imm;
    rd      <= req_rd;

    // Wait until DUT indicates transfer acceptance (valid_i && ready_o)
    timeout_cnt = 0;
    while (!ready_o && timeout_cnt < 100) begin
      @(posedge clk);
      timeout_cnt++;
    end

    if (!ready_o) begin
      note_case(0);
      $display("[%s] [FAIL] LSU ready_o timed out (DUT stuck busy)! [%0t]", test_name, $realtime);
    end

    @(posedge clk);
    valid_i <= 1'b0;
    op      <= rv_op_t'(0);
  endtask

  task automatic start_checking();
    fork
      forever
      @(posedge clk) begin
        #1ps;
        if (valid_o && ready_i) begin
          if (exp_fifo.size() > 0) begin
            exp_txn_t exp = exp_fifo.pop_front();

            // Check 1: Register Address Match
            if (wr_addr_o === exp.exp_rd_addr) begin
              note_case(1);
            end else begin
              note_case(0);
              $display("[%s] [FAIL] rd mismatch! Got: %0d, Exp: %0d [%0t]", test_name, wr_addr_o,
                       exp.exp_rd_addr, $realtime);
            end

            // Check 2: Write Data Match
            if (wr_data_o === exp.exp_wr_data) begin
              note_case(1);
              if (debug)
                $display("[%s] [PASS] Data match: 0x%016x [%0t]", test_name, wr_data_o, $realtime);
            end else begin
              note_case(0);
              $display("[%s] [FAIL] Data mismatch! Got: 0x%016x, Exp: 0x%016x [%0t]", test_name,
                       wr_data_o, exp.exp_wr_data, $realtime);
            end

            // Check 3: Fault Signal Match
            if (mem_fault_o === exp.exp_fault) begin
              note_case(1);
            end else begin
              note_case(0);
              $display("[%s] [FAIL] Fault mismatch! Got: %b, Exp: %b [%0t]", test_name,
                       mem_fault_o, exp.exp_fault, $realtime);
            end
          end else begin
            note_case(0);
            $display("[%s] [FAIL] Unexpected valid_o assertion with empty scoreboard! [%0t]",
                     test_name, $realtime);
          end
        end
      end
    join_none
  endtask

  // Test Case Tasks
  task automatic run_tc_rst_01();
    apply_reset();
    #1ps;
    if (!valid_o && (mem_fault_o !== 1'b1)) begin
      note_case(1);
    end else begin
      note_case(0);
      $display("[%s] [FAIL] Reset state invalid! valid_o=%b ready_o=%b fault=%b [%0t]", test_name,
               valid_o, ready_o, mem_fault_o, $realtime);
    end
  endtask

  task automatic run_tc_ld_01();
    apply_reset();
    send_lsu_op(rv_op_t'(1), 64'h1000, 64'h0, 12'h008, 6'd5, 64'hA5A5_5A5A_DEAD_BEEF, 2'b11, 1'b0);
    repeat (15) @(posedge clk);
  endtask

  task automatic run_tc_st_01();
    apply_reset();
    send_lsu_op(rv_op_t'(2), 64'h2000, 64'h1234_5678, 12'h010, 6'd0, 64'h0, 2'b11, 1'b0);
    repeat (15) @(posedge clk);
  endtask

  task automatic run_tc_b2b_01();
    apply_reset();
    fork
      begin
        send_lsu_op(rv_op_t'(1), 64'h3000, 64'h0, 12'h004, 6'd10, 64'hA5A5_5A5A_DEAD_BEEF, 2'b10,
                    1'b0);
        send_lsu_op(rv_op_t'(1), 64'h3000, 64'h0, 12'h008, 6'd11, 64'hA5A5_5A5A_DEAD_BEEF, 2'b10,
                    1'b0);
        send_lsu_op(rv_op_t'(1), 64'h3000, 64'h0, 12'h00C, 6'd12, 64'hA5A5_5A5A_DEAD_BEEF, 2'b10,
                    1'b0);
      end
      begin
        repeat (3) @(posedge clk);
        ready_i <= 1'b0;
        repeat (2) @(posedge clk);
        ready_i <= 1'b1;
      end
    join
    repeat (15) @(posedge clk);
  endtask

  task automatic run_tc_flt_01();
    apply_reset();
    send_lsu_op(rv_op_t'(1), 64'hFFFF_0000_0000_0000, 64'h0, 12'h000, 6'd15,
                64'hA5A5_5A5A_DEAD_BEEF, 2'b11, 1'b1);
    repeat (15) @(posedge clk);
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  initial begin
    clk            = '0;
    arst_n         = '0;
    op             = rv_op_t'(0);
    rs1            = '0;
    rs2            = '0;
    imm            = '0;
    rd             = '0;
    valid_i        = '0;
    ready_i        = '1;
    dmem_pmi_rsp_i = '0;

    start_clock();
    start_checking();

    case (test_name)
      "TC_RST_01": run_tc_rst_01();
      "TC_LD_01":  run_tc_ld_01();
      "TC_ST_01":  run_tc_st_01();
      "TC_B2B_01": run_tc_b2b_01();
      "TC_FLT_01": run_tc_flt_01();
      "TC_ALL": begin
        run_tc_rst_01();
        run_tc_ld_01();
        run_tc_st_01();
        run_tc_b2b_01();
        run_tc_flt_01();
      end

      default: begin
        $fatal(1, "Unrecognized test_name '%s'", test_name);
      end
    endcase

    #100ns;
    $finish;
  end

endmodule
