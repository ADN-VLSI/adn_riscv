/*

| TEST CASE | DATE       | AUTHOR          | DESCRIPTION                                           |
|-----------|------------|-----------------|-------------------------------------------------------|
| TC_001    | 2026-09-07 | Adnan Sami Anirban | Reset state — in_ready high, out_valid low, buffer empty |
| TC_002    | 2026-09-07 | Adnan Sami Anirban | Single instruction pass-through — data integrity check |
| TC_003    | 2026-09-07 | Adnan Sami Anirban | Buffer depth: fill to capacity, backpressure on input, in-order drain |
| TC_004    | 2026-09-07 | Adnan Sami Anirban | instr_out_valid_o is gated by instr_out_ready_i — no data loss while stalled |
| TC_005    | 2026-09-07 | Adnan Sami Anirban | RAW hazard: younger instr needing an older instr's rd must not launch first |
| TC_006..  | TBD        | (team)          | blocking-stall / bypass / mem_op / clear-flush / randomized regression |

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-09-07 | Adnan Sami Anirban | Initial version                                        |

Author : Adnan Sami Anirban (adnananirban259@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_riscv_instr_launcher_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  // real architecture types: rv_op_t (opcode enum) and the ADN_RISCV_T struct macro
   import adn_riscv_pkg::*;
  `include "adn_riscv/typedef.svh"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int NR          = 8;   // number of tracked registers (kept small & directed-test friendly)
  localparam int CLOG2_NR    = 3;   // $clog2(NR): rd/rs index width. 2**CLOG2_NR must equal NR
  localparam int XLEN        = 32;  // register / pc width
  localparam int NOS         = 3;   // number of pipeline stages -> NOS+1 = 4 total buffer slots
  localparam int CLK_PERIOD  = 10;  // ns

  localparam int N_RAND = 40;  // number of transactions driven in the randomized regression (TC_010)
  localparam int HANDSHAKE_TIMEOUT = 200;  // cycles - defensive guard so one stuck DUT can't hang the whole run

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Use the REAL decoded-instruction type from the architecture header, not a hand-rolled stub.
  // ADN_RISCV_T(name, clog2_num_regs, xlen) expands to `adn_decoded_instr_t` with fields:
  //   op, rd, rs1, rs2, rs3, imm, pc, reg_reqs, mem_op, blocking
  // The launcher only reads .blocking/.rd/.reg_reqs/.mem_op; the rest ride along untouched.
  // There is no scoreboard `id` field in the real struct, so we tag each instruction by its
  // unique `pc` value instead (see make_instr / the monitor).
  `ADN_RISCV_T(adn, CLOG2_NR, XLEN)
  typedef adn_decoded_instr_t instr_t;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic arst_ni;
  logic clk_i;
  logic clear_i;

  instr_t instr_in_i;
  logic   instr_in_valid_i;
  logic   instr_in_ready_o;

  logic [NR-1:0] locks_i;

  instr_t instr_out_o;
  logic   instr_out_valid_o;
  logic   instr_out_ready_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // scoreboard bookkeeping shared by all test tasks
  byte    g_injected_id_q[$];
  byte    g_launched_id_q[$];

  bit     resident   [256];
  instr_t info       [256];
  bit     data_ok    [256];  // set by the monitor: did instr_out_o match what was injected for this id
  int     inject_idx [256];
  int     g_inject_counter;

  int     g_hazard_violations;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_riscv_instr_launcher #(
      .decoded_instr_t(instr_t),
      .NR             (NR),
      .NOS            (NOS)
  ) u_dut (
      .arst_ni          (arst_ni),
      .clk_i            (clk_i),
      .clear_i          (clear_i),
      .instr_in_i       (instr_in_i),
      .instr_in_valid_i (instr_in_valid_i),
      .instr_in_ready_o (instr_in_ready_o),
      .locks_i          (locks_i),
      .instr_out_o      (instr_out_o),
      .instr_out_valid_o(instr_out_valid_o),
      .instr_out_ready_i(instr_out_ready_i)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Build a real adn_decoded_instr_t. `id` is a unique scoreboard tag stored in the pc
  // field (the real struct has no id). op/rs*/imm are set to benign, non-x values so the
  // whole struct is fully defined and data-integrity compares are meaningful.
  function automatic instr_t make_instr(input byte id, input bit blocking,
                                         input logic [CLOG2_NR-1:0] rd,
                                         input logic [NR-1:0] reg_reqs, input bit mem_op);
    make_instr           = '0;
    make_instr.op        = ADD;              // arbitrary valid opcode
    make_instr.pc        = id;               // <-- scoreboard tag lives here
    make_instr.blocking  = blocking;
    make_instr.rd        = rd;
    make_instr.reg_reqs   = reg_reqs;
    make_instr.mem_op    = mem_op;
  endfunction

  // scoreboard tag = the pc field we stamped in make_instr
  function automatic int tag(input instr_t t);
    tag = int'(t.pc);
  endfunction

  // sample point for protocol decisions: a bare @(posedge clk_i) with no extra delay is
  // deliberate here, not an oversight. instr_in_ready_o/instr_out_valid_o are combinational
  // functions of the DUT's internal is_full registers; reading them the instant the edge
  // fires (before any always_ff NBA update commits) gives the value that was actually in
  // effect *going into* this edge - which is exactly what determines whether a transfer
  // happens at this edge. Adding a settle delay here would instead read the *post*-update
  // value and silently misjudge which cycle a handshake completed on.
  task automatic tick();
    @(posedge clk_i);
  endtask

  task automatic apply_reset();
    arst_ni            = 1'b0;
    clear_i             = 1'b0;
    instr_in_valid_i    = 1'b0;
    instr_in_i          = '0;
    instr_out_ready_i   = 1'b0;
    locks_i             = '0;
    g_injected_id_q.delete();
    g_launched_id_q.delete();
    g_inject_counter    = 0;
    g_hazard_violations = 0;
    for (int i = 0; i < 256; i++) begin
      resident[i] = 1'b0;
      data_ok[i]  = 1'b0;
    end
    repeat (3) tick();
    arst_ni = 1'b1;
    repeat (2) tick();
  endtask

  // single-shot handshake: raises valid, waits for ready, then drops valid again.
  // Scoreboard bookkeeping (info[]/resident[]) is recorded up front - we already know the
  // full instruction content before driving it, so there's no reason to defer that write
  // until after acceptance. That sidesteps a same-edge race entirely: for a fully-empty
  // buffer, acceptance and the resulting launch can legitimately land on the very same
  // clock edge (ready propagates combinationally through the whole chain), so any
  // "write bookkeeping only after the handshake completes" scheme risks the monitor
  // process reading it before the write lands, purely due to unspecified same-edge
  // process ordering between two independent testbench processes.
  task automatic drive_instr(input instr_t t);
    int c;
    resident[tag(t)]   = 1'b1;
    info[tag(t)]       = t;
    inject_idx[tag(t)] = g_inject_counter++;

    instr_in_i       <= t;
    instr_in_valid_i <= 1'b1;
    c = 0;
    tick();
    while (!instr_in_ready_o) begin
      c++;
      if (c > HANDSHAKE_TIMEOUT) begin
        $display("[%0t] ERROR: drive_instr id=%0d timed out waiting for instr_in_ready_o", $time, tag(t));
        check("drive_instr_handshake_timeout", 1'b0);
        instr_in_valid_i <= 1'b0;
        resident[tag(t)]   = 1'b0;  // never actually made it in - undo the bookkeeping
        return;
      end
      tick();
    end
    instr_in_valid_i <= 1'b0;
    g_injected_id_q.push_back(byte'(tag(t)));
  endtask

  // waits up to timeout_cycles for the launched count to reach n
  task automatic wait_launch_count(input int n, input int timeout_cycles, output bit ok);
    int c;
    c  = 0;
    ok = 1'b0;
    while (c < timeout_cycles) begin
      if (g_launched_id_q.size() >= n) begin
        ok = 1'b1;
        return;
      end
      tick();
      c++;
    end
  endtask

  // Result reporting: records via note_case() (so PASSED/FAILED counts stay correct) and
  // always prints a labeled line for every check, PASS or FAIL, with the test name and time.
  task automatic check(input string label, input bit cond);
    if (cond) begin
      note_case(1);
      $display("[%s] [PASS] %s [%0t]", test_name, label, $realtime);
    end else begin
      note_case(0);
      $display("[%s] [FAIL] %s [%0t]", test_name, label, $realtime);
    end
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial clk_i = 1'b0;
  always #(CLK_PERIOD / 2) clk_i = ~clk_i;

  // watchdog only for local sanity runs, well above what any test here should ever need
  initial begin
    #200000;
    $display("[%0t] WATCHDOG TIMEOUT - something is genuinely stuck, aborting run", $time);
    $finish;
  end

  // background monitor: records every accepted output transfer and clears residency.
  // safety-checks every launch against the RAW/blocking contract so any test running
  // concurrently benefits from it (used heavily by TC_010).
  initial begin : monitor_output
    instr_t y;
    forever begin
      tick();
      if (arst_ni && instr_out_valid_o && instr_out_ready_i) begin
        y             = instr_out_o;
        data_ok[tag(y)] = (instr_out_o === info[tag(y)]);
        g_launched_id_q.push_back(byte'(tag(y)));
        for (int x = 0; x < 256; x++) begin
          if (resident[x] && (inject_idx[x] < inject_idx[tag(y)])) begin
            if (info[x].blocking || y.reg_reqs[info[x].rd]) begin
              g_hazard_violations++;
              $display("[%0t] HAZARD VIOLATION: id=%0d launched while older resident id=%0d (blocking=%0b rd=%0d) still in-flight",
                        $time, tag(y), x, info[x].blocking, info[x].rd);
            end
          end
        end
        resident[tag(y)] = 1'b0;
      end
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST SCENARIOS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_001_reset_state();
    apply_reset();
    check("TC001_reset_in_ready_high", instr_in_ready_o == 1'b1);
    check("TC001_reset_out_valid_low", instr_out_valid_o == 1'b0);
  endtask

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

  task automatic tc_003_depth_and_backpressure();
    instr_t items[4];
    bit     ok;
    apply_reset();
    instr_out_ready_i = 1'b0;  // hold output back so the buffer actually fills up

    for (int i = 0; i < NOS + 1; i++)
      items[i] = make_instr(8'(10 + i), 1'b0, logic'(i), '0, 1'b0);

    foreach (items[i]) drive_instr(items[i]);

    // buffer should now be at capacity (NOS+1 slots occupied) -> input backpressure expected
    tick();
    check("TC003_full_backpressure", instr_in_ready_o == 1'b0);

    // now drain: release output ready and let all four come out in order
    instr_out_ready_i = 1'b1;
    wait_launch_count(NOS + 1, 30, ok);
    check("TC003_all_drained", ok);
    ok = 1'b1;
    for (int i = 0; i < NOS + 1; i++) begin
      instr_t exp_item;
      byte    got_id;
      byte    exp_id;
      exp_item = items[i];
      exp_id   = byte'(tag(exp_item));
      got_id   = g_launched_id_q[i];
      if (got_id != exp_id) ok = 1'b0;
    end
    check("TC003_drain_order_correct", ok);

    // buffer now empty -> in_ready should be back up
    check("TC003_ready_after_drain", instr_in_ready_o == 1'b1);
  endtask

  task automatic tc_004_valid_ready_gating();
    instr_t exp;
    bit     ok;
    apply_reset();
    instr_out_ready_i = 1'b0;
    exp = make_instr(8'd20, 1'b0, 3'd1, '0, 1'b0);
    drive_instr(exp);

    repeat (4) tick();
    check("TC004_valid_gated_off", instr_out_valid_o == 1'b0);  // valid is gated off while ready is low
    check("TC004_nothing_lost_while_stalled", g_launched_id_q.size() == 0);  // and nothing was lost/skipped

    instr_out_ready_i = 1'b1;
    wait_launch_count(1, 10, ok);
    check("TC004_launches_intact_after_stall", ok && data_ok[tag(exp)]);  // same instruction still shows up intact
  endtask

  task automatic tc_005_raw_hazard();
    instr_t a, b;
    bit     ok;
    apply_reset();
    instr_out_ready_i = 1'b1;
    locks_i           = 8'b0010_0000;  // externally lock reg5 (models an outstanding writeback)

    a = make_instr(8'd30, 1'b0, 3'd2, 8'b0010_0000, 1'b0);  // needs reg5 (locked) -> stalls itself
    b = make_instr(8'd31, 1'b0, 3'd6, 8'b0000_0100, 1'b0);  // needs reg2 == a.rd -> true RAW dep on a

    drive_instr(a);
    drive_instr(b);

    repeat (10) tick();
    check("TC005_no_launch_while_locked", g_launched_id_q.size() == 0);  // neither should have launched while reg5 is locked

    locks_i = '0;  // release the external lock
    wait_launch_count(2, 20, ok);
    check("TC005_both_launched_after_release", ok);
    check("TC005_order_a_then_b", ok && (g_launched_id_q[0] == byte'(tag(a))) && (g_launched_id_q[1] == byte'(tag(b))));
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin  // main initial

    // Wait for reset/setup done inside each task's apply_reset(); dispatch by test_name
    // (TN=... plusarg from adn_common_tb_headers.sv). TC_ALL runs the whole regression.
    case (test_name)
      "TC_001": tc_001_reset_state();
      "TC_002": tc_002_single_passthrough();
      "TC_003": tc_003_depth_and_backpressure();
      "TC_004": tc_004_valid_ready_gating();
      "TC_005": tc_005_raw_hazard();
      // TC_006 .. TC_010 to be added by other team members (see placeholder above),

      "TC_ALL", "default": begin
        tc_001_reset_state();
        tc_002_single_passthrough();
        tc_003_depth_and_backpressure();
        tc_004_valid_ready_gating();
        tc_005_raw_hazard();
        // TC_006 .. TC_010 calls go here once added.
      end

      default: begin
        $fatal(1, "\033[1;31m[TB FATAL] Unrecognized test_name '%s'\033[0m", test_name);
      end
    endcase

    if (debug)
      $display("hazard violations observed across whole run: %0d", g_hazard_violations);

    #100ns;
    $finish;
  end

endmodule
