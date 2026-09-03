/*

| TEST CASE | DATE       | AUTHOR            | DESCRIPTION                                       |
| --------- | ---------- | ----------------- | ------------------------------------------------- |
| TC_001    | 2026-09-01 | Shykul Islam Siam | Test BTB hit scenario                             |
| TC_002    | 2026-09-01 | Shykul Islam Siam | Test BTB miss scenario                            |
| TC_003    | 2026-09-01 | Shykul Islam Siam | Test BTB reset behavior                           |
| TC_004    | 2026-09-02 | Shykul Islam Siam | Test BTB saturation and STRONG state protection   |
| TC_005    | 2026-09-02 | Shykul Islam Siam | Test BTB full-buffer eviction behavior            |

| REVISION  | DATE       | AUTHOR            | DESCRIPTION                                       |
| --------- | ---------- | ----------------- | ------------------------------------------------- |
| 0.1       | 2026-09-01 | Shykul Islam Siam | Initial version                                   |
| 1.0       | 2026-09-02 | Shykul Islam Siam | Added TC_004 and TC_005                           |
| 1.1       | 2026-09-02 | Shykul Islam Siam | RTL Bug Fixed                                     |
| 1.2       | 2026-09-02 | Shykul Islam Siam | Updated TB for Fixed RTL                          |
| 1.3       | 2026-09-03 | Shykul Islam Siam | Stable release                                    |


Author : Shykul Islam Siam (shykulislam32@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_riscv_btb_tb;
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"
  `include "adn_riscv/typedef.svh"
  `include "adn_riscv_pkg.sv"
  import adn_riscv_pkg::*;
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  localparam time CLK_PERIOD       = 10ns;  // DUT clock period
  localparam int  XLEN             = 64;    // Data width of the processor
  localparam int  NUM_BTB          = 32;    // Number of entries in the BTB
 
  localparam logic [XLEN-1:0] BRANCH_PC_0     = 64'h0000_0000_0000_0100;  // PC used by TC_001/003/004
  localparam logic [XLEN-1:0] BRANCH_TARGET_0 = 64'h0000_0000_0000_0180;  // Target for BRANCH_PC_0
  localparam logic [XLEN-1:0] BRANCH_PC_1     = 64'h0000_0000_0000_0200;  // PC used by TC_002
  localparam logic [XLEN-1:0] BRANCH_TARGET_1 = 64'h0000_0000_0000_0280;  // Target for BRANCH_PC_1
 
  localparam logic [XLEN-1:0] FILL_BASE_PC    = 64'h0000_0000_0000_1000;  // First PC of the TC_005 fill loop
  localparam logic [XLEN-1:0] FILL_PC_STRIDE  = 64'h0000_0000_0000_0100;  // PC spacing between fill entries
  localparam logic [XLEN-1:0] FILL_TGT_OFFSET = 64'h0000_0000_0000_0080;  // Target offset from each fill PC
  localparam logic [XLEN-1:0] EVICT_PC        = 64'h0000_0000_0000_9000;  // Never-seen PC used to probe eviction
  localparam logic [XLEN-1:0] EVICT_TARGET    = 64'h0000_0000_0000_9080;  // Target for EVICT_PC
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  logic clk_i;    // Clock driven to the DUT
  logic arst_ni;  // Asynchronous reset driven to the DUT
 
  logic [XLEN-1:0] current_addr_i;  // Current address (EXEC) stimulus
  logic [XLEN-1:0] next_addr_i;     // Next address (EXEC) stimulus
  logic [XLEN-1:0] pc_i;            // Program counter (IF) stimulus
  logic            is_jump_i;       // Is jump/branch (IF) stimulus
 
  logic            match_found_o;  // DUT: found match in buffer
  logic            flush_o;        // DUT: pipeline flush request
  logic [XLEN-1:0] next_pc_o;      // DUT: next program counter
 
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  adn_riscv_btb #(
      .NUM_BTB(NUM_BTB),  // Fully-associative depth under test
      .XLEN(XLEN)         // Address width under test
  ) dut (
      .clk_i(clk_i),                    // Drive clock
      .arst_ni(arst_ni),                // Drive async reset
      .current_addr_i(current_addr_i),  // Drive EXEC current address
      .next_addr_i(next_addr_i),        // Drive EXEC next address
      .pc_i(pc_i),                      // Drive IF-stage PC
      .is_jump_i(is_jump_i),            // Drive IF-stage jump flag
      .match_found_o(match_found_o),    // Sample match found
      .flush_o(flush_o),                // Sample flush request
      .next_pc_o(next_pc_o)             // Sample next PC
  );
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  task automatic check_bit(input string label, input logic expected, input logic actual);
    if (actual === expected) begin
      note_case(1'b1);                                   // Record pass
      if (debug) $display("[PASS] %s: %0b", label, actual);  // Optional pass trace
    end else begin
      note_case(1'b0);                                   // Record fail
      $error("[FAIL] %s: got=%0b expected=%0b", label, actual, expected);  // Report mismatch
    end
  endtask
 
  task automatic check_addr(input string label,
                            input logic [XLEN-1:0] expected,
                            input logic [XLEN-1:0] actual);
    if (actual === expected) begin
      note_case(1'b1);                                     // Record pass
      if (debug) $display("[PASS] %s: 0x%016h", label, actual);  // Optional pass trace
    end else begin
      note_case(1'b0);                                     // Record fail
      $error("[FAIL] %s: got=0x%016h expected=0x%016h", label, actual, expected);  // Report mismatch
    end
  endtask
 
  task automatic drive(input logic [XLEN-1:0] current_addr,
                       input logic [XLEN-1:0] next_addr,
                       input logic [XLEN-1:0] pc,
                       input logic        is_jump);
    current_addr_i = current_addr;  // Apply EXEC-stage resolved address
    next_addr_i    = next_addr;     // Apply EXEC-stage resolved target
    pc_i           = pc;            // Apply IF-stage query PC
    is_jump_i      = is_jump;       // Apply IF-stage jump/branch flag
    #1ns;                           // Let combinational logic settle
  endtask
 
  task automatic apply_reset();
    drive('0, '0, '0, 1'b0);  // Park stimulus at idle before reset
    arst_ni = 1'b0;            // Assert reset
    #1ns;                      // Hold reset
    arst_ni = 1'b1;            // Release reset
    @(negedge clk_i);          // Land on a clean negedge before testing
  endtask
 
  /*
  Resolve a taken branch that is not yet present in the BTB, then commit
  it. strength_buffer resets to '0 (INVALID), so a single write on a
  fresh slot correctly promotes straight to VALID_STRONG.
  */

  task automatic train_entry(input logic [XLEN-1:0] branch_pc,
                             input logic [XLEN-1:0] branch_target);
    drive(branch_pc, branch_target, branch_pc, 1'b1);           // Query as a taken branch
    check_bit("training match_found_o", 1'b1, match_found_o);  // Miss still reports found (via flush)
    check_bit("training flush_o", 1'b1, flush_o);               // First sighting must request correction
    check_addr("training next_pc_o", branch_target, next_pc_o); // Corrected target passed through
    @(posedge clk_i);  // Commit the write
    #1ns;               // Let the write settle
  endtask
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST CASES
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  task automatic tc_001_btb_hit();
    $display("\n--- TC_001: BTB hit ---");
    apply_reset();                                  // Start from a clean buffer
    train_entry(BRANCH_PC_0, BRANCH_TARGET_0);       // Cache the branch
 
    drive(BRANCH_PC_0, BRANCH_TARGET_0, BRANCH_PC_0, 1'b1);  // Re-query the same branch
    check_bit("hit match_found_o", 1'b1, match_found_o);      // Should be found
    check_bit("hit flush_o", 1'b0, flush_o);                  // Cached target already correct
    check_addr("hit next_pc_o", BRANCH_TARGET_0, next_pc_o);  // Cached target returned
  endtask
 
  task automatic tc_002_btb_miss();
    $display("\n--- TC_002: BTB miss ---");
    apply_reset();  // Start from a clean buffer
 
    drive(BRANCH_PC_1, BRANCH_TARGET_1, BRANCH_PC_1, 1'b1);  // Query a never-seen branch
    check_bit("miss match_found_o", 1'b1, match_found_o);     // Found via flush, not cache
    check_bit("miss flush_o", 1'b1, flush_o);                 // Never cached -> must correct
    check_addr("miss next_pc_o", BRANCH_TARGET_1, next_pc_o); // Resolved target passed through
  endtask
 
  task automatic tc_003_btb_reset();
    $display("\n--- TC_003: BTB reset ---");
    apply_reset();                              // Start from a clean buffer
    train_entry(BRANCH_PC_0, BRANCH_TARGET_0);   // Cache the branch
 
    drive('0, '0, BRANCH_PC_0, 1'b0);                          // Plain IF-stage query, no jump
    check_bit("pre-reset match_found_o", 1'b1, match_found_o); // Entry cached before reset
 
    arst_ni = 1'b0;  // Assert async reset mid-simulation
    #1ns;             // Let reset propagate
    check_bit("reset match_found_o", 1'b0, match_found_o);  // Buffer cleared immediately
    check_bit("reset flush_o", 1'b0, flush_o);               // is_jump_i is low, so no flush either
    arst_ni = 1'b1;  // Release reset
  endtask
 
  /* 
  Once an entry is VALID_STRONG, update_table gates off further writes to
  it (update_table = flush_o & ~(&input_state)) so a stale re-visit can't
  demote or clobber it. Confirm a fallthrough resolution on a STRONG
  entry does not corrupt or clear it.
  */

  task automatic tc_004_btb_saturation();
    $display("\n--- TC_004: BTB saturation (VALID_STRONG entry holds) ---");
    apply_reset();                              // Start from a clean buffer
    train_entry(BRANCH_PC_0, BRANCH_TARGET_0);  // Entry now VALID_STRONG
 
    drive(BRANCH_PC_0, BRANCH_PC_0 + 4, BRANCH_PC_0, 1'b1);  // Resolve as a fallthrough this time
    check_bit("fallthrough still matches", 1'b1, match_found_o);  // Still cached
    @(posedge clk_i);  // Let the (blocked) write attempt settle
    #1ns;
 
    drive(BRANCH_PC_0, BRANCH_TARGET_0, BRANCH_PC_0, 1'b1);  // Re-query as a normal taken hit
    check_bit("still strong: match_found_o", 1'b1, match_found_o);  // Still found
    check_bit("still strong: flush_o", 1'b0, flush_o);               // No correction needed
    check_addr("still strong: original target retained", BRANCH_TARGET_0, next_pc_o);  // Unchanged
  endtask
 
  /* 
  Fill every slot to VALID_STRONG, then train one more never-seen branch.
  update_table's STRONG-protect guard (see TC_004) applies to ANY write
  target, including one chosen by buffer_counter for eviction - so while
  every slot holds a STRONG entry, an eviction write cannot land. By
  design (cheap FIFO pointer + STRONG protection, both intentional), the
  result while completely full of STRONG entries is: existing entries
  are retained, and the new branch keeps requesting a correction flush
  every time it is seen, since it never gets a chance to commit.
  */

  task automatic tc_005_btb_full_buffer();
    automatic logic [XLEN-1:0] pc, tgt;  // Scratch PC/target used per loop iteration
    $display("\n--- TC_005: BTB behavior when full of VALID_STRONG entries ---");
    apply_reset();  // Start from a clean buffer
 
    for (int i = 0; i < NUM_BTB; i++) begin  // Fill every slot with a distinct branch
      pc  = FILL_BASE_PC + i * FILL_PC_STRIDE;  // Compute this iteration's PC
      tgt = pc + FILL_TGT_OFFSET;               // Compute this iteration's target
      train_entry(pc, tgt);                     // Cache it
    end
 
    pc  = FILL_BASE_PC + 5 * FILL_PC_STRIDE;  // Select existing entry
    tgt = pc + FILL_TGT_OFFSET;               // Calculate target
    drive(pc, tgt, pc, 1'b1);                                       // Query existing entry
    check_bit("pre-evict sample entry hits", 1'b1, match_found_o);  // Check existing hit
    check_bit("pre-evict sample entry needs no flush", 1'b0, flush_o);  // Check no flush
 
    drive(EVICT_PC, EVICT_TARGET, EVICT_PC, 1'b1);                       // Query new branch
    check_bit("full-buffer miss: match_found_o", 1'b1, match_found_o);   // Check miss indication
    check_bit("full-buffer miss: flush_o", 1'b1, flush_o);               // Check flush
    check_addr("full-buffer miss: next_pc_o", EVICT_TARGET, next_pc_o);  // Check actual target
    @(posedge clk_i);  // Apply (blocked) update
    #1ns;               // Allow state to settle
 
    drive('0, '0, FILL_BASE_PC, 1'b0);  // Query original entry
    check_bit("original entry survives (no eviction while full-STRONG)", 1'b1, match_found_o);  // Still cached
 
    drive(EVICT_PC, EVICT_TARGET, EVICT_PC, 1'b1);  // Re-query the new branch
    check_bit("new branch still not cached: match_found_o", 1'b1, match_found_o);  // Still a miss
    check_bit("new branch still not cached: flush_o", 1'b1, flush_o);              // Still flushes
  endtask
 
  task automatic run_all();
    tc_001_btb_hit();          // Run hit scenario
    tc_002_btb_miss();         // Run miss scenario
    tc_003_btb_reset();        // Run reset scenario
    tc_004_btb_saturation();   // Run saturation scenario
    tc_005_btb_full_buffer();  // Run full-buffer scenario
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  initial begin
    clk_i = 1'b0;                          // Start clock low
    forever #(CLK_PERIOD / 2) clk_i = ~clk_i;  // Free-running toggle
  end
 
  initial begin : main
    arst_ni        = 1'b1;  // Idle reset high
    current_addr_i = '0;    // Idle EXEC current address
    next_addr_i    = '0;    // Idle EXEC next address
    pc_i           = '0;    // Idle IF-stage PC
    is_jump_i      = 1'b0;  // Idle jump flag
    #1ns;  // Let the common testbench header collect command-line plusargs first
 
    case (test_name)
      "TC_001": tc_001_btb_hit();          // Dispatch: hit
      "TC_002": tc_002_btb_miss();         // Dispatch: miss
      "TC_003": tc_003_btb_reset();        // Dispatch: reset
      "TC_004": tc_004_btb_saturation();   // Dispatch: saturation
      "TC_005": tc_005_btb_full_buffer();  // Dispatch: full buffer
      "TC_ALL": run_all();                 // Dispatch: everything
      default:  run_all();                 // Fallback: everything
    endcase
 
    $finish;  // End simulation
 
  end
 
endmodule                                   // make simulate TOP=adn_riscv_btb_tb TN=TC_All
