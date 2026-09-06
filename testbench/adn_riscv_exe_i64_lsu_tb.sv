/*
| TEST CASE | DATE       | AUTHOR              | DESCRIPTION                                                                  |
| --------- | ---------- | ------------------- | ---------------------------------------------------------------------------- |
| TC_RST_01 | 2026-09-03 | Ahasan Ullah Khalid | Active-low reset assertion and default handshake/fault verification          |
| TC_LD_01  | 2026-09-03 | Ahasan Ullah Khalid | Standard load double-word (LD) operation through PMI memory request/response |
| TC_ST_01  | 2026-09-03 | Ahasan Ullah Khalid | Standard store double-word (SD) operation verifying address and write data   |
| TC_B2B_01 | 2026-09-03 | Ahasan Ullah Khalid | Back-to-back load/store pipeline handshaking under writeback backpressure    |
| TC_FLT_01 | 2026-09-03 | Ahasan Ullah Khalid | Memory access fault detection and fault address propagation check            |
| TC_ALL    | 2026-09-03 | Ahasan Ullah Khalid | Default regression suite executing all test scenarios sequentially           |

| REVISION | DATE        | AUTHOR              | DESCRIPTION                                                               |
| -------- | ----------- | --------------------| ------------------------------------------------------------------------- |
| 0.1      | 2026-09-03  | Ahasan Ullah Khalid | Initial version                                                           |
| 1.0      | 2026-09-03  | Ahasan Ullah Khalid | Resolved handshake deadlock with legal RISC-V opcodes and continuous mgnt |

Author : Ahasan Ullah Khalid (aukhalid02@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information
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
  bit               pmi_backpressure;

  typedef struct {
    logic [63:0] exp_wr_data;
    logic [5:0]  exp_rd_addr;
    logic [1:0]  exp_wr_size;
    bit          exp_fault;
    logic [63:0] exp_fault_addr;
  } exp_txn_t;

  exp_txn_t exp_fifo[$];

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTL
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

  // Clock edge alignment
  always @(posedge clk) begin
    is_clk_edge_aligned <= arst_n;
    #1ns;
    is_clk_edge_aligned <= '0;
  end

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // Golden PMI Memory Responder
  /////////////////////////////////////////////////////////////////////////////////////////////////
  always @(posedge clk or negedge arst_n) begin
    if (~arst_n) begin
      dmem_pmi_rsp_i.mgnt   <= 1'b1;
      dmem_pmi_rsp_i.mack   <= 1'b0;
      dmem_pmi_rsp_i.mrdata <= '0;
      dmem_pmi_rsp_i.mresp  <= 1'b0;
    end else begin

      // PMI backpressure control
      dmem_pmi_rsp_i.mgnt <= ~pmi_backpressure;

      if (dmem_pmi_req_o.mreq && dmem_pmi_rsp_i.mgnt) begin
        dmem_pmi_rsp_i.mack   <= 1'b1;
        dmem_pmi_rsp_i.mrdata <= 64'hA5A5_5A5A_DEAD_BEEF;

        // Generate memory fault for invalid address
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

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // Start Clock
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic start_clock();
    fork
      forever #CLKHalfPeriod clk <= ~clk;
    join_none

    @(posedge clk);
  endtask

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // Reset
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic apply_reset();

    arst_n <= 1'b0;
    valid_i <= 1'b0;
    ready_i <= 1'b1;

    op <= LD;
    rs1 <= '0;
    rs2 <= '0;
    imm <= '0;
    rd <= '0;

    pmi_backpressure <= 1'b0;

    repeat (5) @(posedge clk);

    arst_n <= 1'b1;

    repeat (5) @(posedge clk);

  endtask

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // Send LSU Operation
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic send_lsu_op(input rv_op_t req_op, input logic [63:0] req_rs1,
                             input logic [63:0] req_rs2, input logic [11:0] req_imm,
                             input logic [5:0] req_rd, input logic [63:0] exp_data,
                             input logic [1:0] exp_sz, input bit exp_flt);

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

    fork

      begin
        do begin
          @(posedge clk);
        end while (!ready_o);
      end

      begin
        repeat (100) @(posedge clk);

        note_case(0);

        $display("[%s] [FAIL] LSU ready_o timed out (DUT stuck busy)! [%0t]", test_name, $realtime);
      end

    join_any

    disable fork;

    valid_i <= 1'b0;
    op      <= LD;

  endtask

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // Output Checker
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic start_checking();

    fork

      forever
      @(posedge clk) begin

        #1ps;

        if (valid_o && ready_i) begin

          if (exp_fifo.size() > 0) begin

            exp_txn_t exp = exp_fifo.pop_front();

            //------------------------------------------------------------------------------
            // Check 1: Register Address
            //------------------------------------------------------------------------------
            if (wr_addr_o === exp.exp_rd_addr) begin
              note_case(1);
            end else begin

              note_case(0);

              $display("[%s] [FAIL] rd mismatch! Got: %0d, Exp: %0d [%0t]", test_name, wr_addr_o,
                       exp.exp_rd_addr, $realtime);

            end

            //------------------------------------------------------------------------------
            // Check 2: Write Data
            //------------------------------------------------------------------------------
            if (wr_data_o === exp.exp_wr_data) begin

              note_case(1);

              if (debug)
                $display("[%s] [PASS] Data match: 0x%016x [%0t]", test_name, wr_data_o, $realtime);

            end else begin

              note_case(0);

              $display("[%s] [FAIL] Data mismatch! Got: 0x%016x, Exp: 0x%016x [%0t]", test_name,
                       wr_data_o, exp.exp_wr_data, $realtime);

            end

            //------------------------------------------------------------------------------
            // Check 3: Fault
            //------------------------------------------------------------------------------
            if ((mem_fault_o === exp.exp_fault) || (mem_fault_o === 1'bx && !exp.exp_fault)) begin

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

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST CASES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_RST_01
  /////////////////////////////////////////////////////////////////////////////////////////////////
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

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_LD_01
  // Basic Double Word Load
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic run_tc_ld_01();

    apply_reset();

    send_lsu_op(LD, 64'h1000, 64'h0, 12'h008, 6'd5, 64'hA5A5_5A5A_DEAD_BEEF, 2'b11, 1'b0);

    repeat (15) @(posedge clk);

  endtask

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_ST_01
  // Basic Double Word Store
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic run_tc_st_01();

    apply_reset();

    send_lsu_op(SD, 64'h2000, 64'h1234_5678, 12'h010, 6'd0, 64'hA5A5_5A5A_DEAD_BEEF, 2'b11, 1'b0);

    repeat (15) @(posedge clk);

  endtask

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_B2B_01
  // Back-to-Back Loads + Output Backpressure
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic run_tc_b2b_01();

    apply_reset();

    fork

      begin

        send_lsu_op(LD, 64'h3000, '0, 12'h000, 6'd10, 64'hA5A5_5A5A_DEAD_BEEF, 2'b11, 1'b0);

        send_lsu_op(LD, 64'h3000, '0, 12'h008, 6'd11, 64'hA5A5_5A5A_DEAD_BEEF, 2'b11, 1'b0);

        send_lsu_op(LD, 64'h3000, '0, 12'h010, 6'd12, 64'hA5A5_5A5A_DEAD_BEEF, 2'b11, 1'b0);

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

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_FLT_01
  // Memory Fault
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic run_tc_flt_01();

    apply_reset();

    send_lsu_op(LD, 64'hFFFF_0000_0000_0000, '0, 12'h000, 6'd15, 64'hA5A5_5A5A_DEAD_BEEF, 2'b11,
                1'b1);

    repeat (15) @(posedge clk);

  endtask

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_LOAD_SIZE_01
  // LB / LBU / LH / LHU / LW / LWU
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic run_tc_load_size_01();

    apply_reset();

    // LB
    send_lsu_op(LB, 64'h1000, '0, 12'h000, 6'd1, 64'hFFFF_FFFF_FFFF_FFEF, 2'b00, 1'b0);

    // LBU
    send_lsu_op(LBU, 64'h1000, '0, 12'h000, 6'd2, 64'h0000_0000_0000_00EF, 2'b00, 1'b0);

    // LH
    send_lsu_op(LH, 64'h1000, '0, 12'h000, 6'd3, 64'hFFFF_FFFF_FFFF_BEEF, 2'b01, 1'b0);

    // LHU
    send_lsu_op(LHU, 64'h1000, '0, 12'h000, 6'd4, 64'h0000_0000_0000_BEEF, 2'b01, 1'b0);

    // LW
    send_lsu_op(LW, 64'h1000, '0, 12'h000, 6'd5, 64'hFFFF_FFFF_DEAD_BEEF, 2'b10, 1'b0);

    // LWU
    send_lsu_op(LWU, 64'h1000, '0, 12'h000, 6'd6, 64'h0000_0000_DEAD_BEEF, 2'b10, 1'b0);

    repeat (20) @(posedge clk);

  endtask

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_STORE_SIZE_01
  // SB / SH / SW
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic run_tc_store_size_01();

    apply_reset();

    // Store Byte
    send_lsu_op(SB, 64'h4000, 64'h0000_0000_0000_00AA, 12'h000, 6'd0, 64'hA5A5_5A5A_DEAD_BEEF,
                2'b11, 1'b0);

    // Store Half Word
    send_lsu_op(SH, 64'h4000, 64'h0000_0000_0000_BEEF, 12'h002, 6'd0, 64'hA5A5_5A5A_DEAD_BEEF,
                2'b11, 1'b0);

    // Store Word
    send_lsu_op(SW, 64'h4000, 64'h0000_0000_DEAD_BEEF, 12'h004, 6'd0, 64'hA5A5_5A5A_DEAD_BEEF,
                2'b11, 1'b0);

    repeat (20) @(posedge clk);

  endtask

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_NEGATIVE_OFFSET_01
  // Signed Immediate / Effective Address
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic run_tc_negative_offset_01();

    apply_reset();

    // 0x2000 + (-8) = 0x1FF8
    send_lsu_op(LD, 64'h0000_0000_0000_2000, '0, 12'hFF8, 6'd20, 64'hA5A5_5A5A_DEAD_BEEF, 2'b11,
                1'b0);

    repeat (15) @(posedge clk);

  endtask

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // Check PMI Strobe
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic check_mstrb(input rv_op_t req_op, input logic [63:0] req_rs1,
                             input logic [11:0] req_imm, input logic [7:0] exp_strb);

    wait (is_clk_edge_aligned);

    valid_i <= 1'b1;
    op      <= req_op;
    rs1     <= req_rs1;
    rs2     <= '0;
    imm     <= req_imm;
    rd      <= '0;

    do begin
      @(posedge clk);
    end while (!ready_o);

    #1ps;

    if (dmem_pmi_req_o.mstrb === exp_strb) begin

      note_case(1);

      if (debug)
        $display(
            "[%s] [PASS] mstrb match: Got=%b Exp=%b [%0t]",
            test_name,
            dmem_pmi_req_o.mstrb,
            exp_strb,
            $realtime
        );

    end else begin

      note_case(0);

      $display("[%s] [FAIL] mstrb mismatch! Got=%b Exp=%b [%0t]", test_name, dmem_pmi_req_o.mstrb,
               exp_strb, $realtime);

    end

    valid_i <= 1'b0;
    op      <= LD;

  endtask

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_BYTE_LANE_01
  // Address Offset + Byte Lane Strobe
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic run_tc_byte_lane_01();

    apply_reset();

    // SB offset 0
    check_mstrb(SB, 64'h1000, 12'h000, 8'b0000_0001);

    // SB offset 1
    check_mstrb(SB, 64'h1000, 12'h001, 8'b0000_0010);

    // SB offset 3
    check_mstrb(SB, 64'h1000, 12'h003, 8'b0000_1000);

    // SH offset 2
    check_mstrb(SH, 64'h1000, 12'h002, 8'b0000_1100);

    // SW offset 0
    check_mstrb(SW, 64'h1000, 12'h000, 8'b0000_1111);

    // SD offset 0
    check_mstrb(SD, 64'h1000, 12'h000, 8'b1111_1111);

    repeat (10) @(posedge clk);

  endtask

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_AQ_RL_01
  // Atomic AQ / RL Sideband
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic run_tc_aq_rl_01();

    apply_reset();

    // AQ=0, RL=0
    valid_i <= 1'b1;
    op      <= LR_D;
    rs1     <= 64'h5000;
    rs2     <= '0;
    imm     <= 12'b0000_0000_0000;
    rd      <= 6'd21;

    wait (dmem_pmi_req_o.mreq);

    #1ps;

    if ((dmem_sideband_o.aq === 1'b0) && (dmem_sideband_o.rl === 1'b0)) begin
      note_case(1);
    end else begin
      note_case(0);
      $display("[%s] [FAIL] AQ/RL mismatch for 00 [%0t]", test_name, $realtime);
    end

    @(posedge clk);
    valid_i <= 1'b0;

    repeat (5) @(posedge clk);

    // AQ=1, RL=0
    valid_i <= 1'b1;
    op      <= LR_D;
    rs1     <= 64'h5000;
    rs2     <= '0;
    imm     <= 12'b0000_0000_0010;
    rd      <= 6'd22;

    wait (dmem_pmi_req_o.mreq);

    #1ps;

    if ((dmem_sideband_o.aq === 1'b1) && (dmem_sideband_o.rl === 1'b0)) begin
      note_case(1);
    end else begin
      note_case(0);
      $display("[%s] [FAIL] AQ/RL mismatch for 10 [%0t]", test_name, $realtime);
    end

    @(posedge clk);
    valid_i <= 1'b0;

    repeat (5) @(posedge clk);

    // AQ=0, RL=1
    valid_i <= 1'b1;
    op      <= LR_D;
    rs1     <= 64'h5000;
    rs2     <= '0;
    imm     <= 12'b0000_0000_0001;
    rd      <= 6'd23;

    wait (dmem_pmi_req_o.mreq);

    #1ps;

    if ((dmem_sideband_o.aq === 1'b0) && (dmem_sideband_o.rl === 1'b1)) begin
      note_case(1);
    end else begin
      note_case(0);
      $display("[%s] [FAIL] AQ/RL mismatch for 01 [%0t]", test_name, $realtime);
    end

    @(posedge clk);
    valid_i <= 1'b0;

    repeat (5) @(posedge clk);

    // AQ=1, RL=1
    valid_i <= 1'b1;
    op      <= LR_D;
    rs1     <= 64'h5000;
    rs2     <= '0;
    imm     <= 12'b0000_0000_0011;
    rd      <= 6'd24;

    wait (dmem_pmi_req_o.mreq);

    #1ps;

    if ((dmem_sideband_o.aq === 1'b1) && (dmem_sideband_o.rl === 1'b1)) begin
      note_case(1);
    end else begin
      note_case(0);
      $display("[%s] [FAIL] AQ/RL mismatch for 11 [%0t]", test_name, $realtime);
    end

    @(posedge clk);
    valid_i <= 1'b0;

    repeat (10) @(posedge clk);

  endtask

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_OUTPUT_BP_01
  // Output Backpressure
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic run_tc_output_bp_01();

    apply_reset();

    ready_i <= 1'b0;

    fork

      begin

        send_lsu_op(LD, 64'h6000, '0, 12'h000, 6'd25, 64'hA5A5_5A5A_DEAD_BEEF, 2'b11, 1'b0);

      end

      begin

        repeat (10) @(posedge clk);

        #1ps;

        if (valid_o === 1'b1) begin

          note_case(1);

          if (debug)
            $display("[%s] [PASS] valid_o held during backpressure [%0t]", test_name, $realtime);

        end else begin

          note_case(0);

          $display("[%s] [FAIL] valid_o dropped during output backpressure [%0t]", test_name,
                   $realtime);

        end

        ready_i <= 1'b1;

      end

    join

    repeat (10) @(posedge clk);

  endtask

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_INPUT_BP_01
  // PMI Grant Backpressure
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic run_tc_input_bp_01();

    apply_reset();

    pmi_backpressure <= 1'b1;

    fork

      begin

        send_lsu_op(LD, 64'h7000, '0, 12'h000, 6'd26, 64'hA5A5_5A5A_DEAD_BEEF, 2'b11, 1'b0);

      end

      begin

        repeat (5) @(posedge clk);

        if (dmem_pmi_req_o.mreq) begin
          note_case(1);
        end else begin
          note_case(0);

          $display("[%s] [FAIL] PMI request not generated during grant backpressure [%0t]",
                   test_name, $realtime);
        end

        repeat (10) @(posedge clk);

        pmi_backpressure <= 1'b0;

      end

    join

    repeat (15) @(posedge clk);

  endtask

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_RESET_TRANS_01
  // Reset During Active Transaction
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic run_tc_reset_trans_01();

    apply_reset();

    pmi_backpressure <= 1'b1;

    valid_i          <= 1'b1;
    op               <= LD;
    rs1              <= 64'h8000;
    rs2              <= '0;
    imm              <= 12'h000;
    rd               <= 6'd27;

    repeat (3) @(posedge clk);

    // Assert reset during transaction
    arst_n <= 1'b0;

    repeat (3) @(posedge clk);

    #1ps;

    if (!valid_o && !dmem_pmi_req_o.mreq) begin

      note_case(1);

      if (debug) $display("[%s] [PASS] LSU cleared during reset [%0t]", test_name, $realtime);

    end else begin

      note_case(0);

      $display("[%s] [FAIL] LSU did not clear during reset! valid_o=%b mreq=%b [%0t]", test_name,
               valid_o, dmem_pmi_req_o.mreq, $realtime);

    end

    valid_i <= 1'b0;

    pmi_backpressure <= 1'b0;

    arst_n <= 1'b1;

    repeat (5) @(posedge clk);

    // Verify new transaction works after reset
    send_lsu_op(LD, 64'h8100, '0, 12'h000, 6'd28, 64'hA5A5_5A5A_DEAD_BEEF, 2'b11, 1'b0);

    repeat (15) @(posedge clk);

  endtask

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_ATOMIC_01
  // LR / SC / AMO
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic run_tc_atomic_01();

    apply_reset();

    // LR.W
    send_lsu_op(LR_W, 64'h9000, '0, 12'h000, 6'd29, 64'h0000_0000_DEAD_BEEF, 2'b11, 1'b0);

    // SC.W
    send_lsu_op(SC_W, 64'h9000, 64'h1234_5678, 12'h000, 6'd30, 64'h0000_0000_DEAD_BEEF, 2'b11,
                1'b0);

    // AMOADD.W
    send_lsu_op(AMOADD_W, 64'h9000, 64'h0000_0000_0000_0005, 12'h000, 6'd31,
                64'h0000_0000_DEAD_BEEF, 2'b11, 1'b0);

    // AMOSWAP.D
    send_lsu_op(AMOSWAP_D, 64'h9008, 64'h1111_2222_3333_4444, 12'h000, 6'd32,
                64'hA5A5_5A5A_DEAD_BEEF, 2'b11, 1'b0);

    repeat (20) @(posedge clk);

  endtask

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_INVALID_OP_01
  // Invalid Opcode
  /////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic run_tc_invalid_op_01();

    apply_reset();

    valid_i <= 1'b1;
    op      <= rv_op_t'(0);
    rs1     <= 64'hA000;
    rs2     <= '0;
    imm     <= '0;
    rd      <= 6'd10;

    repeat (3) @(posedge clk);

    #1ps;

    if (!dmem_pmi_req_o.mreq && !valid_o) begin

      note_case(1);

      if (debug)
        $display("[%s] [PASS] Invalid opcode correctly blocked [%0t]", test_name, $realtime);

    end else begin

      note_case(0);

      $display("[%s] [FAIL] Invalid opcode generated transaction! mreq=%b valid_o=%b [%0t]",
               test_name, dmem_pmi_req_o.mreq, valid_o, $realtime);

    end

    valid_i <= 1'b0;
    op      <= LD;

    repeat (5) @(posedge clk);

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  initial begin

    clk              = 1'b0;
    arst_n           = 1'b0;

    op               = LD;
    rs1              = '0;
    rs2              = '0;
    imm              = '0;
    rd               = '0;

    valid_i          = 1'b0;
    ready_i          = 1'b1;

    pmi_backpressure = 1'b0;

    dmem_pmi_rsp_i   = '0;

    start_clock();
    start_checking();

    //////////////////////////////////////////////////////////////////////////////////////////////////
    // TEST SELECTION
    //////////////////////////////////////////////////////////////////////////////////////////////////
    case (test_name)

      //////////////////////////////////////////////////////////////////////////////////////////////
      // Existing Tests
      //////////////////////////////////////////////////////////////////////////////////////////////

      "TC_RST_01": run_tc_rst_01();

      "TC_LD_01": run_tc_ld_01();

      "TC_ST_01": run_tc_st_01();

      "TC_B2B_01": run_tc_b2b_01();

      "TC_FLT_01": run_tc_flt_01();

      //////////////////////////////////////////////////////////////////////////////////////////////
      // New Tests
      //////////////////////////////////////////////////////////////////////////////////////////////

      "TC_LOAD_SIZE_01": run_tc_load_size_01();

      "TC_STORE_SIZE_01": run_tc_store_size_01();

      "TC_NEGATIVE_OFFSET_01": run_tc_negative_offset_01();

      "TC_BYTE_LANE_01": run_tc_byte_lane_01();

      "TC_AQ_RL_01": run_tc_aq_rl_01();

      "TC_OUTPUT_BP_01": run_tc_output_bp_01();

      "TC_INPUT_BP_01": run_tc_input_bp_01();

      "TC_RESET_TRANS_01": run_tc_reset_trans_01();

      "TC_ATOMIC_01": run_tc_atomic_01();

      "TC_INVALID_OP_01": run_tc_invalid_op_01();

      //////////////////////////////////////////////////////////////////////////////////////////////
      // Full Regression
      //////////////////////////////////////////////////////////////////////////////////////////////

      "TC_ALL": begin

        run_tc_rst_01();

        run_tc_ld_01();

        run_tc_st_01();

        run_tc_b2b_01();

        run_tc_flt_01();

        run_tc_load_size_01();

        run_tc_store_size_01();

        run_tc_negative_offset_01();

        run_tc_byte_lane_01();

        run_tc_aq_rl_01();

        run_tc_output_bp_01();

        run_tc_input_bp_01();

        run_tc_reset_trans_01();

        run_tc_atomic_01();

        run_tc_invalid_op_01();

      end

      default: begin

        $fatal(1, "Unrecognized test_name '%s'", test_name);

      end

    endcase

    #100ns;

    $finish;

  end

endmodule
