/*

| TEST CASE  | DATE       | AUTHOR              | DESCRIPTION                                                                                          |
|------------|------------|---------------------|------------------------------------------------------------------------------------------------------|
| TC_DIR_01  | 2026-09-02 | Ahasan Ullah Khalid | Clean dispatch check with no hazards (ALU operations, no register conflicts, mem idle)              |
| TC_RAW_01  | 2026-09-02 | Ahasan Ullah Khalid | RAW dependency stall verification across single-bit and multi-bit register hazard masks              |
| TC_MEM_01  | 2026-09-02 | Ahasan Ullah Khalid | Memory collision and bypass verification (mem_op vs mem_busy interaction, ALU bypass during mem_busy)|
| TC_BLK_01  | 2026-09-02 | Ahasan Ullah Khalid | Global blocking barrier verification asserting blocking_i to confirm full register lock-out         |
| TC_RND_01  | 2026-09-02 | Ahasan Ullah Khalid | Randomized stimulus verification covering combinations of locks, register requests, and memory states |
| TC_ALL     | 2026-09-02 | Ahasan Ullah Khalid | Default regression suite executing all test scenarios sequentially (`TC_DIR_01` through `TC_RND_01`) |

| REVISION | DATE       | AUTHOR              | DESCRIPTION                                            |
|----------|------------|---------------------|--------------------------------------------------------|
| 0.1      | 2026-09-02 | Ahasan Ullah Khalid | Initial version                                        |
| 1.0      | 2026-09-02 | Ahasan Ullah Khalid | Stable release                                         |

Author : Ahasan Ullah Khalid (aukhalid02@gmail.com)
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

  // Golden Reference Model
  always_comb begin
    // Reference: mem_busy_o logic
    exp_mem_busy = mem_busy_in | (mem_op && mem_busy_in);

    // Reference: arb_req_o logic
    if (pl_valid) begin
      if (mem_op & mem_busy_in) begin
        exp_arb_req = 1'b0;
      end else begin
        exp_arb_req = pl_valid & ~(|(locks_in & reg_req));
      end
    end else begin
      exp_arb_req = 1'b0;
    end

    // Reference: locks_o scoreboard update logic
    exp_locks = locks_in;
    if (pl_valid) begin
      if (blocking) begin
        exp_locks = '1;
      end else begin
        exp_locks[rd] = 1'b1;
      end
    end
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

  task automatic start_clock();
    fork
      forever #(CLKPeriod / 2) clk <= ~clk;
    join_none
    @(posedge clk);
  endtask

  task automatic drive_stimulus(input logic valid, input logic blk,
                                input logic [RegIdxWidth-1:0] dest, input logic [NR-1:0] req,
                                input logic [NR-1:0] lck, input logic m_op, input logic m_busy);
    wait (is_clk_edge_aligned);
    pl_valid    <= valid;
    blocking    <= blk;
    rd          <= dest;
    reg_req     <= req;
    locks_in    <= lck;
    mem_op      <= m_op;
    mem_busy_in <= m_busy;
    @(posedge clk);
  endtask

  task automatic start_checking();
    fork
      forever
      @(posedge clk) begin
        #1ps;  // Sample post-update after combinational propagation

        // Check: Compare DUT outputs against Golden Reference
        if ((arb_req_out === exp_arb_req) &&
            (locks_out   === exp_locks)   &&
            (mem_busy_out === exp_mem_busy)) begin
          note_case(1);
          if (debug) begin
            $display("[%s] [PASS] Match: arb_req=%0b, locks=0x%08h, mem_busy=%0b [%0t]", test_name,
                     arb_req_out, locks_out, mem_busy_out, $realtime);
          end
        end else begin
          note_case(0);
          $display("[%s] [FAIL] Mismatch detected! [%0t]", test_name, $realtime);
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
      end
    join_none
  endtask

  // Test Case: Direct non-blocking issue without hazard
  task automatic run_tc_dir_01();
    // Inactive pipeline stage
    drive_stimulus(1'b0, 1'b0, 5'd0, '0, '0, 1'b0, 1'b0);

    // Single active ALU instruction with no dependencies
    for (int r = 1; r < NR; r++) begin
      drive_stimulus(.valid(1'b1), .blk(1'b0), .dest(r[RegIdxWidth-1:0]),
                     .req((1 << ((r + 1) % NR)) | (1 << ((r + 2) % NR))), .lck('0), .m_op(1'b0),
                     .m_busy(1'b0));
    end
  endtask

  // Test Case: RAW dependency stall checks
  task automatic run_tc_raw_01();
    // Single register match (rs1 locked)
    drive_stimulus(1'b1, 1'b0, 5'd3, (1 << 1), (1 << 1), 1'b0, 1'b0);

    // Single register match (rs2 locked)
    drive_stimulus(1'b1, 1'b0, 5'd4, (1 << 2), (1 << 2), 1'b0, 1'b0);

    // Both source registers locked
    drive_stimulus(1'b1, 1'b0, 5'd5, (1 << 1) | (1 << 2), (1 << 1) | (1 << 2), 1'b0, 1'b0);

    // Disjoint locks (locks exist, but instruction uses different registers)
    drive_stimulus(1'b1, 1'b0, 5'd6, (1 << 3) | (1 << 4), (1 << 1) | (1 << 2), 1'b0, 1'b0);

    // Walking bit check for all register positions
    for (int i = 0; i < NR; i++) begin
      drive_stimulus(1'b1, 1'b0, ((i + 1) % NR), (1 << i), (1 << i), 1'b0, 1'b0);
    end
  endtask

  // Test Case: Memory busy arbitration & ALU bypass checks
  task automatic run_tc_mem_01();
    // Mem op with idle memory -> should grant
    drive_stimulus(1'b1, 1'b0, 5'd1, '0, '0, 1'b1, 1'b0);

    // Mem op with busy memory -> must stall
    drive_stimulus(1'b1, 1'b0, 5'd2, '0, '0, 1'b1, 1'b1);

    // Non-mem op with busy memory -> must grant (ALU bypass)
    drive_stimulus(1'b1, 1'b0, 5'd3, '0, '0, 1'b0, 1'b1);

    // Non-mem op with busy memory and register hazard -> must stall on reg hazard
    drive_stimulus(1'b1, 1'b0, 5'd4, (1 << 5), (1 << 5), 1'b0, 1'b1);

    // Mem op with busy memory and register hazard -> must stall
    drive_stimulus(1'b1, 1'b0, 5'd5, (1 << 6), (1 << 6), 1'b1, 1'b1);
  endtask

  // Test Case: Global barrier lock check
  task automatic run_tc_blk_01();
    // Blocking asserted with valid pipeline -> locks_o must be all 1s
    drive_stimulus(1'b1, 1'b1, 5'd0, '0, 32'h0000_0000, 1'b0, 1'b0);
    drive_stimulus(1'b1, 1'b1, 5'd10, '0, 32'hAAAA_AAAA, 1'b0, 1'b0);

    // Blocking asserted without valid pipeline -> locks_o retains locks_i
    drive_stimulus(1'b0, 1'b1, 5'd5, '0, 32'h1234_5678, 1'b0, 1'b0);
  endtask

  // Test Case: Randomized payload and flag sweep
  task automatic run_tc_rnd_01();
    repeat (100) begin
      drive_stimulus(.valid($urandom_range(0, 1)),
                     .blk($urandom_range(0, 9) == 0),  // 10% probability of barrier
                     .dest($urandom_range(0, NR - 1)), .req($urandom()), .lck($urandom()),
                     .m_op($urandom_range(0, 1)), .m_busy($urandom_range(0, 1)));
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
    start_checking();

    // Execute requested test scenario
    case (test_name)
      "TC_DIR_01": run_tc_dir_01();
      "TC_RAW_01": run_tc_raw_01();
      "TC_MEM_01": run_tc_mem_01();
      "TC_BLK_01": run_tc_blk_01();
      "TC_RND_01": run_tc_rnd_01();
      "TC_ALL": begin
        run_tc_dir_01();
        run_tc_raw_01();
        run_tc_mem_01();
        run_tc_blk_01();
        run_tc_rnd_01();
      end

      default: begin
        $fatal(1, "Unrecognized test_name '%s'", test_name);
      end
    endcase

    #100ns;
    $finish;
  end

endmodule
