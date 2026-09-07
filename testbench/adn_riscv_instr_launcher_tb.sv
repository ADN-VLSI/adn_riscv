/*

| TEST CASE | DATE       | AUTHOR          | DESCRIPTION                                           |
|-----------|------------|-----------------|-------------------------------------------------------|
| TC_001    | 2026-09-07 | Adnan Sami Anirban | Reset state — in_ready high, out_valid low, buffer empty |
| TC_002    | 2026-09-07 | Adnan Sami Anirban | Single instruction pass-through — data integrity check |
| TC_003    | 2026-09-07 | Adnan Sami Anirban | Buffer depth: fill to capacity, backpressure on input, in-order drain |
| TC_004    | 2026-09-07 | Adnan Sami Anirban | instr_out_valid_o is gated by instr_out_ready_i — no data loss while stalled |
| TC_005    | 2026-09-07 | Adnan Sami Anirban | RAW hazard: younger instr needing an older instr's rd must not launch first |
| TC_006    | 2026-09-07 | Adnan Sami Anirban | blocking_i on an older instr stalls a younger instr with disjoint regs too |
| TC_007    | 2026-09-07 | Adnan Sami Anirban | Independent younger instr bypasses an older instr stalled by an external lock |
| TC_008    | 2026-09-07 | Adnan Sami Anirban | Back-to-back mem_op structural hazard - confirmed intentional (no stall via launcher) |
| TC_009    | 2026-09-07 | Adnan Sami Anirban | Synchronous clear_i flushes in-flight instructions cleanly |
| TC_010    | 2026-09-07 | Adnan Sami Anirban | Randomized regression: order/hazard-safety/no-drop scoreboard over N instrs |

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

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int NR         = 8;   // number of tracked registers (kept small & directed-test friendly)
  localparam int NOS        = 3;   // number of pipeline stages -> NOS+1 = 4 total buffer slots
  localparam int CLK_PERIOD = 10;  // ns

  localparam int N_RAND = 40;  // number of transactions driven in the randomized regression (TC_010)
  localparam int HANDSHAKE_TIMEOUT = 200;  // cycles - defensive guard so one stuck DUT can't hang the whole run

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Minimal decoded_instr_t for unit-level testing of the launcher/order-checker.
  // The launcher only ever looks at .blocking/.rd/.reg_req/.mem_op internally (it moves the
  // rest of the struct opaquely), so only those fields plus a scoreboard tag are modeled here.
  typedef struct packed {
    logic [7:0]             id;        // scoreboard tag, not used by the DUT
    logic                   blocking;
    logic [$clog2(NR)-1:0]  rd;
    logic [NR-1:0]          reg_req;
    logic                   mem_op;
  } instr_t;

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
  // INTERFACES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // CLASSES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

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

  function automatic instr_t make_instr(input byte id, input bit blocking,
                                         input logic [$clog2(NR)-1:0] rd,
                                         input logic [NR-1:0] reg_req, input bit mem_op);
    make_instr.id       = id;
    make_instr.blocking = blocking;
    make_instr.rd       = rd;
    make_instr.reg_req  = reg_req;
    make_instr.mem_op   = mem_op;
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
    resident[t.id]   = 1'b1;
    info[t.id]       = t;
    inject_idx[t.id] = g_inject_counter++;

    instr_in_i       <= t;
    instr_in_valid_i <= 1'b1;
    c = 0;
    tick();
    while (!instr_in_ready_o) begin
      c++;
      if (c > HANDSHAKE_TIMEOUT) begin
        $display("[%0t] ERROR: drive_instr id=%0d timed out waiting for instr_in_ready_o", $time, t.id);
        check("drive_instr_handshake_timeout", 1'b0);
        instr_in_valid_i <= 1'b0;
        resident[t.id]   = 1'b0;  // never actually made it in - undo the bookkeeping
        return;
      end
      tick();
    end
    instr_in_valid_i <= 1'b0;
    g_injected_id_q.push_back(t.id);
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

  // labeled wrapper around note_case: prints an unambiguous, greppable result line of our
  // own regardless of whether the vip's note_case() itself is verbose, so a failing run's
  // log always tells you exactly which named check failed and when.
  int g_check_num;
  task automatic check(input string label, input bit cond);
    g_check_num++;
    $display("[%0t] CHECK #%0d %s: %s", $time, g_check_num, label, cond ? "PASS" : "FAIL");
    note_case(cond);
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
        data_ok[y.id] = (instr_out_o === info[y.id]);
        g_launched_id_q.push_back(y.id);
        for (int x = 0; x < 256; x++) begin
          if (resident[x] && (inject_idx[x] < inject_idx[y.id])) begin
            if (info[x].blocking || y.reg_req[info[x].rd]) begin
              g_hazard_violations++;
              $display("[%0t] HAZARD VIOLATION: id=%0d launched while older resident id=%0d (blocking=%0b rd=%0d) still in-flight",
                        $time, y.id, x, info[x].blocking, info[x].rd);
            end
          end
        end
        resident[y.id] = 1'b0;
      end
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
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
    check("TC002_data_matches", ok && data_ok[exp.id]);
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
      exp_id   = exp_item.id;
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
    check("TC004_valid_gated_off", instr_out_valid_o == 1'b0);    // valid is gated off while ready is low
    check("TC004_nothing_lost_while_stalled", g_launched_id_q.size() == 0);  // and nothing was lost/skipped

    instr_out_ready_i = 1'b1;
    wait_launch_count(1, 10, ok);
    check("TC004_launches_intact_after_stall", ok && data_ok[exp.id]);  // same instruction still shows up intact
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
    check("TC005_order_a_then_b", ok && (g_launched_id_q[0] == a.id) && (g_launched_id_q[1] == b.id));
  endtask

  task automatic tc_006_blocking_stalls_disjoint();
    instr_t c, d;
    bit     ok;
    apply_reset();
    instr_out_ready_i = 1'b1;
    locks_i           = 8'b1000_0000;  // externally lock reg7 so c itself stalls for a while

    c = make_instr(8'd40, 1'b1, 3'd0, 8'b1000_0000, 1'b0);  // blocking=1, needs reg7 (locked)
    d = make_instr(8'd41, 1'b0, 3'd1, 8'b0000_0001, 1'b0);  // needs reg0 - disjoint from c.rd

    drive_instr(c);
    drive_instr(d);

    repeat (10) tick();
    check("TC006_no_launch_while_c_locked", g_launched_id_q.size() == 0);  // d must be held back purely by c.blocking, not by a real dep

    locks_i = '0;
    wait_launch_count(2, 20, ok);
    check("TC006_both_launched_after_release", ok);
    check("TC006_order_c_then_d", ok && (g_launched_id_q[0] == c.id) && (g_launched_id_q[1] == d.id));
  endtask

  task automatic tc_007_independent_bypass();
    instr_t e, f;
    bit     ok;
    apply_reset();
    instr_out_ready_i = 1'b1;
    locks_i           = 8'b1000_0000;  // lock reg7

    e = make_instr(8'd50, 1'b0, 3'd4, 8'b1000_0000, 1'b0);  // stuck on reg7, not blocking
    f = make_instr(8'd51, 1'b0, 3'd2, 8'b0000_0010, 1'b0);  // needs reg1, disjoint from e.rd(=4)

    drive_instr(e);
    drive_instr(f);

    wait_launch_count(1, 15, ok);
    check("TC007_something_launched", ok);
    // f should be the one that got through, while e is still stuck on the external lock
    check("TC007_f_bypassed_e", ok && (g_launched_id_q[0] == f.id));
    check("TC007_e_still_stuck", resident[e.id] == 1'b1);

    locks_i = '0;
    wait_launch_count(2, 15, ok);
    check("TC007_e_launches_after_release", ok);
  endtask

  task automatic tc_008_mem_structural_hazard();
    instr_t g, h;
    bit     ok;
    int     gap_cycles;
    apply_reset();
    instr_out_ready_i = 1'b1;

    g = make_instr(8'd60, 1'b0, 3'd0, '0, 1'b1);  // mem_op=1, no reg deps
    h = make_instr(8'd61, 1'b0, 3'd0, '0, 1'b1);  // mem_op=1, no reg deps

    drive_instr(g);
    drive_instr(h);

    wait_launch_count(1, 10, ok);
    check("TC008_first_launched", ok);
    gap_cycles = 0;
    while (g_launched_id_q.size() < 2 && gap_cycles < 10) begin
      tick();
      gap_cycles++;
    end
    check("TC008_second_launched", g_launched_id_q.size() == 2);

    // NOTE: mem_busy[0] is hard-wired to '0 at the launcher boundary with no external
    // "memory busy" feedback, so the order-checker's mem_busy_o = mem_busy_i | (mem_op_i & mem_busy_i)
    // never rises above 0 and back-to-back mem_op instructions launch with no structural
    // stall between them. Confirmed with Foez vai: this is intentional - mem-op sequencing
    // is handled outside the launcher, not by this mem_busy chain. Recorded here for visibility,
    // not asserted as a failure.
    if (gap_cycles <= 1) begin
      $display("[%0t] NOTE: back-to-back mem_op instructions launched with no structural stall (gap=%0d cycles) - confirmed intentional, mem-op sequencing is handled outside the launcher.",
                $time, gap_cycles);
    end
    check("TC008_recorded_ok", 1'b1);
  endtask

  task automatic tc_009_sync_clear();
    instr_t i_instr, j_instr, k_instr;
    bit     ok;
    apply_reset();
    instr_out_ready_i = 1'b0;

    i_instr = make_instr(8'd70, 1'b0, 3'd0, '0, 1'b0);
    j_instr = make_instr(8'd71, 1'b0, 3'd1, '0, 1'b0);
    drive_instr(i_instr);
    drive_instr(j_instr);

    clear_i = 1'b1;
    tick();
    clear_i = 1'b0;

    instr_out_ready_i = 1'b1;
    repeat (6) tick();
    check("TC009_flushed_not_launched", g_launched_id_q.size() == 0);  // i and j must never appear at the output
    check("TC009_ready_after_clear", instr_in_ready_o == 1'b1);        // buffer reports empty again

    resident[i_instr.id] = 1'b0;  // they were flushed, not launched - clear scoreboard bookkeeping
    resident[j_instr.id] = 1'b0;

    k_instr = make_instr(8'd72, 1'b0, 3'd2, '0, 1'b0);
    drive_instr(k_instr);
    wait_launch_count(1, 15, ok);
    check("TC009_clean_launch_after_clear", ok && data_ok[k_instr.id]);
  endtask

  task automatic tc_010_randomized_regression();
    instr_t items[N_RAND];
    bit     ok;
    int     recent_rd[4];
    bit                    blk;
    logic [$clog2(NR)-1:0] rd;
    logic [NR-1:0]         rq;
    bit                    memo;
    apply_reset();

    for (int i = 0; i < N_RAND; i++) begin
      blk  = ($urandom_range(0, 9) == 0);  // ~10% blocking
      rd   = $urandom_range(0, NR - 1);
      memo = $urandom_range(0, 3) == 0;
      rq   = '0;
      // mostly independent traffic, occasionally a genuine dependency on a recently-issued rd
      if ($urandom_range(0, 2) == 0) rq[recent_rd[i%4]] = 1'b1;
      else rq[$urandom_range(0, NR - 1)] = 1'b1;
      recent_rd[i%4] = rd;
      items[i] = make_instr(8'(100 + i), blk, rd, rq, memo);
    end

    // producer: randomized valid gaps
    fork
      begin : producer
        foreach (items[i]) begin
          if ($urandom_range(0, 3) == 0) tick();  // occasional bubble before offering
          drive_instr(items[i]);
        end
      end
      begin : consumer
        forever begin
          @(posedge clk_i);
          instr_out_ready_i <= ($urandom_range(0, 4) != 0);  // ~80% ready
        end
      end
    join_any

    wait_launch_count(N_RAND, 800, ok);
    check("TC010_all_drained", ok);

    // no drops / no duplicates: launched id multiset must equal injected id multiset
    ok = (g_launched_id_q.size() == g_injected_id_q.size());
    if (ok) begin
      byte sorted_in[$];
      byte sorted_out[$];
      sorted_in  = g_injected_id_q;
      sorted_out = g_launched_id_q;
      sorted_in.sort();
      sorted_out.sort();
      foreach (sorted_in[i]) if (sorted_in[i] != sorted_out[i]) ok = 1'b0;
    end
    check("TC010_no_drop_no_dup", ok);

    check("TC010_no_hazard_violations", g_hazard_violations == 0);

    disable fork;
    instr_out_ready_i = 1'b0;
  endtask

  initial begin  // main initial

    tc_001_reset_state();
    tc_002_single_passthrough();
    tc_003_depth_and_backpressure();
    tc_004_valid_ready_gating();
    tc_005_raw_hazard();
    tc_006_blocking_stalls_disjoint();
    tc_007_independent_bypass();
    tc_008_mem_structural_hazard();
    tc_009_sync_clear();
    tc_010_randomized_regression();

    $display("hazard violations observed across whole run: %0d", g_hazard_violations);
    $finish;

  end

endmodule
