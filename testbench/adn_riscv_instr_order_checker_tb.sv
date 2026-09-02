/*

| TEST CASE  | DATE       | AUTHOR                     | DESCRIPTION                                                                                          |
|------------|------------|----------------------------|------------------------------------------------------------------------------------------------------|
| TC_DIR_01  | 2026-09-02 | Ahasan Ullah Khalid        | Clean dispatch check across all destination registers with no hazards                                |
| TC_RAW_01  | 2026-09-02 | Ahasan Ullah Khalid        | Exhaustive single-bit, multi-bit, and walking bit RAW hazard stalls across all register positions    |
| TC_MEM_01  | 2026-09-02 | Ahasan Ullah Khalid        | Comprehensive memory hazard verification (busy stall, free dispatch, ALU bypass, passthroughs)       |
| TC_BLK_01  | 2026-09-02 | Ahasan Ullah Khalid        | Global blocking barrier verification (all registers locked when valid, ignored when pl_valid low)    |
| TC_ACC_01  | 2026-09-02 | Ahasan Ullah Khalid        | Sequential multi-instruction scoreboard lock accumulation chain verification                         |
| TC_MSK_01  | 2026-09-02 | Ahasan Ullah Khalid        | Request and lock mask isolation, zero request mask bypass, and all-register lock saturation check    |
| TC_RND_01  | 2026-09-02 | Ahasan Ullah Khalid        | Randomized stress stimulus covering arbitrary states of locks, requests, opcodes, and memory status  |
| TC_001     | 2026-09-02 | Md Sakhawat Hossain Sabbir | Basic dispatch with no hazards                                                                       |
| TC_002     | 2026-09-02 | Md Sakhawat Hossain Sabbir | Pipeline invalid holds outputs idle and retains locks                                                |
| TC_003     | 2026-09-02 | Md Sakhawat Hossain Sabbir | Blocking signal locks all registers                                                                  |
| TC_004     | 2026-09-02 | Md Sakhawat Hossain Sabbir | RAW hazard stalls dispatch                                                                           |
| TC_005     | 2026-09-02 | Md Sakhawat Hossain Sabbir | Memory operation stalled while memory busy                                                           |
| TC_006     | 2026-09-02 | Md Sakhawat Hossain Sabbir | Memory operation proceeds when memory free                                                           |
| TC_007     | 2026-09-02 | Md Sakhawat Hossain Sabbir | mem_busy_o passthrough with mem_op_i deasserted                                                      |
| TC_008     | 2026-09-02 | Md Sakhawat Hossain Sabbir | mem_busy_o passthrough with mem_op_i asserted                                                        |
| TC_009     | 2026-09-02 | Md Sakhawat Hossain Sabbir | Partial register request overlap triggers stall                                                      |
| TC_010     | 2026-09-02 | Md Sakhawat Hossain Sabbir | Destination register boundary (MSB) lock set                                                         |
| TC_011     | 2026-09-02 | Md Sakhawat Hossain Sabbir | Destination register boundary (LSB) lock set                                                         |
| TC_012     | 2026-09-02 | Md Sakhawat Hossain Sabbir | Blocking signal ignored when pipeline invalid                                                        |
| TC_013     | 2026-09-02 | Md Sakhawat Hossain Sabbir | Combined memory and register hazard                                                                  |
| TC_014     | 2026-09-02 | Md Sakhawat Hossain Sabbir | Sequential lock accumulation across instructions                                                     |
| TC_015     | 2026-09-02 | Md Sakhawat Hossain Sabbir | Zero register request mask bypasses hazard check                                                     |
| TC_016     | 2026-09-02 | Ahasan Ullah Khalid        | All-requested dest with clear locks proceeds                                                         |
| TC_017     | 2026-09-02 | Ahasan Ullah Khalid        | All registers locked forces stall                                                                    |
| TC_018     | 2026-09-02 | Ahasan Ullah Khalid        | Lock mask isolation from request mask                                                                |
| TC_019     | 2026-09-02 | Ahasan Ullah Khalid        | Randomized stress testing across 50 iterations                                                       |
| TC_ALL     | 2026-09-02 | Ahasan Ullah Khalid        | Full regression suite executing all unit and group test scenarios sequentially                       |

| REVISION | DATE       | AUTHOR                       | DESCRIPTION                                            |
|----------|------------|------------------------------|--------------------------------------------------------|
| 0.1      | 2026-09-02 | Md Sakhawat Hossain Sabbir   | Initial testbench version                              |
| 0.2      | 2026-09-02 | Ahasan Ullah Khalid          | Added structural edge sync, sweep tasks & random suite |
| 1.0      | 2026-09-02 | Ahasan Ullah Khalid          | Unified consolidated regression testbench              |

Author : Ahasan Ullah Khalid (aukhalid02@gmail.com), Md Sakhawat Hossain Sabbir (foez.official@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_riscv_instr_order_checker_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int NR = 32;
  localparam int RegIdxWidth = $clog2(NR);
  localparam time CLKPeriod = 10ns;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic                   clk;
  logic                   pl_valid;
  logic                   blocking;
  logic [RegIdxWidth-1:0] rd;
  logic [         NR-1:0] reg_req;
  logic [         NR-1:0] locks_in;
  logic                   mem_op;
  logic                   mem_busy_in;

  logic [         NR-1:0] locks_out;
  logic                   mem_busy_out;
  logic                   arb_req_out;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  bit                     is_clk_edge_aligned;
  logic [         NR-1:0] exp_locks;
  logic                   exp_mem_busy;
  logic                   exp_arb_req;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Clock edge alignment helper flag
  always @(posedge clk) begin
    is_clk_edge_aligned <= 1'b1;
    #1ns;
    is_clk_edge_aligned <= 1'b0;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_riscv_instr_order_checker #(
      .NR(NR)
  ) u_dut (
      .pl_valid_i(pl_valid),
      .blocking_i(blocking),
      .rd_i      (rd),
      .reg_req_i (reg_req),
      .locks_i   (locks_in),
      .locks_o   (locks_out),
      .mem_op_i  (mem_op),
      .mem_busy_i(mem_busy_in),
      .mem_busy_o(mem_busy_out),
      .arb_req_o (arb_req_out)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Golden Reference Model - mirrors the DUT's combinational equations exactly
  function automatic void compute_expected(
      input logic valid, input logic blk, input logic m_op, input logic m_busy,
      input logic [RegIdxWidth-1:0] dest, input logic [NR-1:0] req, input logic [NR-1:0] lck,
      output logic [NR-1:0] o_locks, output logic o_mem_busy, output logic o_arb_req);
    logic [NR-1:0] locks_mask;

    o_mem_busy = m_busy | (m_op && m_busy);

    o_arb_req = valid ? ((m_op & m_busy) ? 1'b0 : (valid & ~(|(lck & req)))) : 1'b0;

    o_locks = lck;
    if (valid) begin
      if (blk) begin
        o_locks = '1;
      end else begin
        locks_mask = '0;
        locks_mask[dest] = 1'b1;
        o_locks = lck | locks_mask;
      end
    end
  endfunction

  task automatic start_clock();
    fork
      forever #(CLKPeriod / 2) clk <= ~clk;
    join_none
    @(posedge clk);
  endtask

  // Synchronized stimulus driving and functional checking
  task automatic drive_and_check(input logic valid, input logic blk,
                                 input logic [RegIdxWidth-1:0] dest, input logic [NR-1:0] req,
                                 input logic [NR-1:0] lck, input logic m_op, input logic m_busy,
                                 input string case_desc = "");
    wait (is_clk_edge_aligned);
    pl_valid    <= valid;
    blocking    <= blk;
    rd          <= dest;
    reg_req     <= req;
    locks_in    <= lck;
    mem_op      <= m_op;
    mem_busy_in <= m_busy;

    compute_expected(valid, blk, m_op, m_busy, dest, req, lck, exp_locks, exp_mem_busy,
                     exp_arb_req);

    @(posedge clk);
    #1ps;  // Sample post-update after combinational propagation

    if ((arb_req_out === exp_arb_req) &&
        (locks_out   === exp_locks)   &&
        (mem_busy_out === exp_mem_busy)) begin
      note_case(1);
      if (debug) begin
        $display("[%s] [PASS] %s | arb_req=%0b, locks=0x%08h, mem_busy=%0b [%0t]", test_name,
                 case_desc, arb_req_out, locks_out, mem_busy_out, $realtime);
      end
    end else begin
      note_case(0);
      $display("[%s] [FAIL] %s Mismatch detected! [%0t]", test_name, case_desc, $realtime);
      if (arb_req_out !== exp_arb_req) begin
        $display("       arb_req: Got %0b, Expected %0b", arb_req_out, exp_arb_req);
      end
      if (locks_out !== exp_locks) begin
        $display("       locks: Got 0x%08h, Expected 0x%08h", locks_out, exp_locks);
      end
      if (mem_busy_out !== exp_mem_busy) begin
        $display("       mem_busy: Got %0b, Expected %0b", mem_busy_out, exp_mem_busy);
      end
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ATOMIC TEST SCENARIOS (Md Sakhawat Hossain Sabbir & Ahasan Ullah Khalid Suite)
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // TC_001 : basic dispatch, no register or memory hazard
  task automatic run_tc_001();
    drive_and_check(1'b1, 1'b0, 5'd5, 32'h0000_0000, 32'h0000_0000, 1'b0, 1'b0, "basic dispatch");
  endtask

  // TC_002 : pipeline invalid must leave locks/arb output unaffected
  task automatic run_tc_002();
    drive_and_check(1'b0, 1'b0, 5'd5, 32'hFFFF_FFFF, 32'hAAAA_AAAA, 1'b0, 1'b0, "pipeline invalid");
  endtask

  // TC_003 : blocking signal forces every register locked
  task automatic run_tc_003();
    drive_and_check(1'b1, 1'b1, 5'd3, 32'h0000_0000, 32'h0000_0001, 1'b0, 1'b0,
                    "blocking asserted");
  endtask

  // TC_004 : requested register already locked must stall arbitration
  task automatic run_tc_004();
    drive_and_check(1'b1, 1'b0, 5'd5, 32'h0000_0010, 32'h0000_0010, 1'b0, 1'b0, "RAW hazard");
  endtask

  // TC_005 : memory op with memory busy must stall arbitration
  task automatic run_tc_005();
    drive_and_check(1'b1, 1'b0, 5'd7, 32'h0000_0000, 32'h0000_0000, 1'b1, 1'b1, "mem op, mem busy");
  endtask

  // TC_006 : memory op with memory free must proceed
  task automatic run_tc_006();
    drive_and_check(1'b1, 1'b0, 5'd7, 32'h0000_0000, 32'h0000_0000, 1'b1, 1'b0, "mem op, mem free");
  endtask

  // TC_007 : mem_busy_o passthrough with mem_op_i deasserted
  task automatic run_tc_007();
    drive_and_check(1'b0, 1'b0, 5'd0, 32'h0000_0000, 32'h0000_0000, 1'b0, 1'b1,
                    "mem_busy passthrough op=0");
  endtask

  // TC_008 : mem_busy_o passthrough with mem_op_i asserted
  task automatic run_tc_008();
    drive_and_check(1'b0, 1'b0, 5'd0, 32'h0000_0000, 32'h0000_0000, 1'b1, 1'b0,
                    "mem_busy passthrough op=1");
  endtask

  // TC_009 : partial overlap between reg_req and locks must still stall
  task automatic run_tc_009();
    drive_and_check(1'b1, 1'b0, 5'd10, 32'h0000_0F0F, 32'h0000_0001, 1'b0, 1'b0,
                    "partial overlap stall");
  endtask

  // TC_010 : destination register boundary - MSB (NR-1)
  task automatic run_tc_010();
    drive_and_check(1'b1, 1'b0, (NR - 1), 32'h0000_0000, 32'h0000_0000, 1'b0, 1'b0,
                    "rd boundary MSB");
  endtask

  // TC_011 : destination register boundary - LSB (0)
  task automatic run_tc_011();
    drive_and_check(1'b1, 1'b0, 5'd0, 32'h0000_0000, 32'h0000_0000, 1'b0, 1'b0, "rd boundary LSB");
  endtask

  // TC_012 : blocking asserted but pipeline invalid must have no effect
  task automatic run_tc_012();
    drive_and_check(1'b0, 1'b1, 5'd5, 32'h0000_0000, 32'h1234_5678, 1'b0, 1'b0,
                    "blocking, pl invalid");
  endtask

  // TC_013 : simultaneous memory-busy and register-lock hazard
  task automatic run_tc_013();
    drive_and_check(1'b1, 1'b0, 5'd2, 32'h0000_0004, 32'h0000_0004, 1'b1, 1'b1,
                    "combined mem+reg hazard");
  endtask

  // TC_014 : sequential lock accumulation - feed locks_o back as locks_i across instructions
  task automatic run_tc_014();
    logic [NR-1:0] locks_chain;
    locks_chain = '0;
    for (int i = 0; i < 5; i++) begin
      drive_and_check(1'b1, 1'b0, i[RegIdxWidth-1:0], 32'h0000_0000, locks_chain, 1'b0, 1'b0,
                      $sformatf("accum step %0d", i));
      locks_chain = locks_out;
    end
  endtask

  // TC_015 : an all-zero request mask must never trigger a hazard, regardless of locks_i
  task automatic run_tc_015();
    drive_and_check(1'b1, 1'b0, 5'd15, 32'h0000_0000, 32'hFFFF_FFFF, 1'b0, 1'b0, "zero req mask");
  endtask

  // TC_016 : all-requested mask with no actual locks set must still dispatch
  task automatic run_tc_016();
    drive_and_check(1'b1, 1'b0, 5'd20, 32'hFFFF_FFFF, 32'h0000_0000, 1'b0, 1'b0,
                    "all req, no locks");
  endtask

  // TC_017 : every register locked forces a stall for any non-zero request
  task automatic run_tc_017();
    drive_and_check(1'b1, 1'b0, 5'd8, 32'h0000_0100, 32'hFFFF_FFFF, 1'b0, 1'b0, "all locks set");
  endtask

  // TC_018 : the lock mask must only ever set the rd_i bit, never the reg_req_i bits
  task automatic run_tc_018();
    drive_and_check(1'b1, 1'b0, 5'd12, 32'hFFFF_0000, 32'h0000_0000, 1'b0, 1'b0,
                    "lock mask isolation");
  endtask

  // TC_019 : randomized stress testing across 50 iterations
  task automatic run_tc_019();
    for (int i = 0; i < 50; i++) begin
      drive_and_check($urandom_range(0, 1), $urandom_range(0, 1), $urandom_range(0, NR - 1),
                      $urandom(), $urandom(), $urandom_range(0, 1), $urandom_range(0, 1), $sformatf(
                      "random iter %0d", i));
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // COMPREHENSIVE SUITE SCENARIOS (Merged Regression Tasks)
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // TC_DIR_01 : Direct clean issue sweep across all registers
  task automatic run_tc_dir_01();
    drive_and_check(1'b0, 1'b0, 5'd0, '0, '0, 1'b0, 1'b0, "idle pl_valid=0");

    for (int r = 0; r < NR; r++) begin
      drive_and_check(.valid(1'b1), .blk(1'b0), .dest(r[RegIdxWidth-1:0]),
                      .req((1 << ((r + 1) % NR)) | (1 << ((r + 2) % NR))), .lck('0), .m_op(1'b0),
                      .m_busy(1'b0), .case_desc($sformatf("clean dispatch rd=%0d", r)));
    end
  endtask

  // TC_RAW_01 : Exhaustive RAW dependency checks
  task automatic run_tc_raw_01();
    // Single-bit dependency stalls
    drive_and_check(1'b1, 1'b0, 5'd3, (1 << 1), (1 << 1), 1'b0, 1'b0, "rs1 locked");
    drive_and_check(1'b1, 1'b0, 5'd4, (1 << 2), (1 << 2), 1'b0, 1'b0, "rs2 locked");

    // Dual-source dependency stall
    drive_and_check(1'b1, 1'b0, 5'd5, (1 << 1) | (1 << 2), (1 << 1) | (1 << 2), 1'b0, 1'b0,
                    "dual lock");

    // Disjoint locks (should grant)
    drive_and_check(1'b1, 1'b0, 5'd6, (1 << 3) | (1 << 4), (1 << 1) | (1 << 2), 1'b0, 1'b0,
                    "disjoint locks");

    // Full walking-ones sweep across all NR bit positions
    for (int i = 0; i < NR; i++) begin
      drive_and_check(1'b1, 1'b0, ((i + 1) % NR), (1 << i), (1 << i), 1'b0, 1'b0, $sformatf(
                      "walking RAW stall bit %0d", i));
    end
  endtask

  // TC_MEM_01 : Memory operation, busy collisions, and ALU bypass
  task automatic run_tc_mem_01();
    drive_and_check(1'b1, 1'b0, 5'd1, '0, '0, 1'b1, 1'b0, "mem op free dispatch");
    drive_and_check(1'b1, 1'b0, 5'd2, '0, '0, 1'b1, 1'b1, "mem op busy stall");
    drive_and_check(1'b1, 1'b0, 5'd3, '0, '0, 1'b0, 1'b1, "ALU bypass during mem busy");
    drive_and_check(1'b1, 1'b0, 5'd4, (1 << 5), (1 << 5), 1'b0, 1'b1,
                    "ALU stall on reg hazard during mem busy");
    drive_and_check(1'b1, 1'b0, 5'd5, (1 << 6), (1 << 6), 1'b1, 1'b1, "mem op dual hazard stall");
    drive_and_check(1'b0, 1'b0, 5'd0, '0, '0, 1'b0, 1'b1, "mem busy passthrough idle");
    drive_and_check(1'b0, 1'b0, 5'd0, '0, '0, 1'b1, 1'b1, "mem busy passthrough busy");
  endtask

  // TC_BLK_01 : Blocking barrier state checks
  task automatic run_tc_blk_01();
    drive_and_check(1'b1, 1'b1, 5'd0, '0, 32'h0000_0000, 1'b0, 1'b0,
                    "blocking sets all 1s (clear locks)");
    drive_and_check(1'b1, 1'b1, 5'd10, '0, 32'hAAAA_AAAA, 1'b0, 1'b0,
                    "blocking sets all 1s (partial locks)");
    drive_and_check(1'b0, 1'b1, 5'd5, '0, 32'h1234_5678, 1'b0, 1'b0,
                    "blocking ignored when pl_valid=0");
  endtask

  // TC_ACC_01 : Multi-cycle lock accumulation chain
  task automatic run_tc_acc_01();
    logic [NR-1:0] accumulated_locks;
    accumulated_locks = '0;
    for (int i = 0; i < NR; i++) begin
      drive_and_check(1'b1, 1'b0, i[RegIdxWidth-1:0], '0, accumulated_locks, 1'b0, 1'b0, $sformatf(
                      "accumulating lock for rd=%0d", i));
      accumulated_locks = locks_out;
    end
  endtask

  // TC_MSK_01 : Mask edge cases and isolation tests
  task automatic run_tc_msk_01();
    drive_and_check(1'b1, 1'b0, 5'd15, 32'h0000_0000, 32'hFFFF_FFFF, 1'b0, 1'b0,
                    "all locks, zero req mask");
    drive_and_check(1'b1, 1'b0, 5'd20, 32'hFFFF_FFFF, 32'h0000_0000, 1'b0, 1'b0,
                    "all req, zero locks");
    drive_and_check(1'b1, 1'b0, 5'd8, 32'h0000_0100, 32'hFFFF_FFFF, 1'b0, 1'b0,
                    "all locks, single req");
    drive_and_check(1'b1, 1'b0, 5'd12, 32'hFFFF_0000, 32'h0000_0000, 1'b0, 1'b0,
                    "rd mask isolated from req");
    drive_and_check(1'b1, 1'b0, (NR - 1), 32'h0000_0000, 32'h0000_0000, 1'b0, 1'b0,
                    "boundary MSB check");
    drive_and_check(1'b1, 1'b0, 5'd0, 32'h0000_0000, 32'h0000_0000, 1'b0, 1'b0,
                    "boundary LSB check");
  endtask

  // TC_RND_01 : Extended random test suite
  task automatic run_tc_rnd_01();
    repeat (100) begin
      drive_and_check(.valid($urandom_range(0, 1)),
                      .blk($urandom_range(0, 9) == 0),  // 10% barrier density
                      .dest($urandom_range(0, NR - 1)), .req($urandom()), .lck($urandom()),
                      .m_op($urandom_range(0, 1)), .m_busy($urandom_range(0, 1)),
                      .case_desc("random stress vector"));
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin
    // Signal initialization
    clk         = '0;
    pl_valid    = '0;
    blocking    = '0;
    rd          = '0;
    reg_req     = '0;
    locks_in    = '0;
    mem_op      = '0;
    mem_busy_in = '0;

    start_clock();

    // Execute requested test scenario
    case (test_name)
      // Group suites
      "TC_DIR_01": run_tc_dir_01();
      "TC_RAW_01": run_tc_raw_01();
      "TC_MEM_01": run_tc_mem_01();
      "TC_BLK_01": run_tc_blk_01();
      "TC_ACC_01": run_tc_acc_01();
      "TC_MSK_01": run_tc_msk_01();
      "TC_RND_01": run_tc_rnd_01();

      // Atomic tests from coworker suite
      "TC_001": run_tc_001();
      "TC_002": run_tc_002();
      "TC_003": run_tc_003();
      "TC_004": run_tc_004();
      "TC_005": run_tc_005();
      "TC_006": run_tc_006();
      "TC_007": run_tc_007();
      "TC_008": run_tc_008();
      "TC_009": run_tc_009();
      "TC_010": run_tc_010();
      "TC_011": run_tc_011();
      "TC_012": run_tc_012();
      "TC_013": run_tc_013();
      "TC_014": run_tc_014();
      "TC_015": run_tc_015();
      "TC_016": run_tc_016();
      "TC_017": run_tc_017();
      "TC_018": run_tc_018();
      "TC_019": run_tc_019();

      // Full unified regression
      "TC_ALL": begin
        run_tc_001();
        run_tc_002();
        run_tc_003();
        run_tc_004();
        run_tc_005();
        run_tc_006();
        run_tc_007();
        run_tc_008();
        run_tc_009();
        run_tc_010();
        run_tc_011();
        run_tc_012();
        run_tc_013();
        run_tc_014();
        run_tc_015();
        run_tc_016();
        run_tc_017();
        run_tc_018();
        run_tc_019();
        run_tc_dir_01();
        run_tc_raw_01();
        run_tc_mem_01();
        run_tc_blk_01();
        run_tc_acc_01();
        run_tc_msk_01();
        run_tc_rnd_01();
      end

      default: begin
        $fatal(1, "\033[1;31m[TB FATAL] Unrecognized test_name '%s'\033[0m", test_name);
      end
    endcase

    #100ns;
    $finish;
  end

endmodule
