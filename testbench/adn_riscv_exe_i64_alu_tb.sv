/*

| TEST CASE | DATE       | AUTHOR                                 | DESCRIPTION                                                    |
|-----------|------------|----------------------------------------|----------------------------------------------------------------|
| TC_ADD    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | ADD: simple positive addition                                  |
| TC_SUB    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SUB: simple subtraction                                        |
| TC_ADDI   | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | ADDI: register + immediate addition                            |
| TC_SLL    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SLL: logical shift left, shift amount from operand_b_i[5:0]    |
| TC_SLLI   | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SLLI: logical shift left with immediate                        |
| TC_SLT    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SLT: signed less-than, negative operand_a_i                    |
| TC_SLTI   | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SLTI: signed less-than immediate                               |
| TC_SLTU   | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SLTU: unsigned less-than, large unsigned operand_a_i           |
| TC_SLTIU  | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SLTIU: unsigned less-than immediate                            |
| TC_XOR    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | XOR: alternating bit pattern                                   |
| TC_XORI   | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | XORI: XOR with immediate                                       |
| TC_SRL    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SRL: logical shift right of MSB-set value                      |
| TC_SRLI   | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SRLI: logical shift right with immediate                       |
| TC_SRA    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SRA: arithmetic shift right, negative operand_a_i              |
| TC_SRAI   | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SRAI: arithmetic shift right immediate, negative operand_a_i   |
| TC_OR     | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | OR: bitwise OR                                                 |
| TC_ORI    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | ORI: bitwise OR with immediate                                 |
| TC_AND    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | AND: bitwise AND                                               |
| TC_ANDI   | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | ANDI: bitwise AND with immediate                               |
| TC_ADDW   | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | ADDW: 32-bit add that overflows into sign bit, sign extension  |
| TC_SUBW   | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SUBW: 32-bit subtract producing a negative word result         |
| TC_SLLW   | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SLLW: 32-bit shift left producing a negative word result       |
| TC_SRLW   | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SRLW: 32-bit logical shift right, zero extension               |
| TC_SRAW   | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SRAW: 32-bit arithmetic shift right, sign extension            |
| TC_ADDIW  | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | ADDIW: 32-bit add immediate, positive result                   |
| TC_SLLIW  | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SLLIW: 32-bit shift left immediate, negative word result       |
| TC_SRLIW  | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SRLIW: 32-bit logical shift right immediate, zero extension    |
| TC_SRAIW  | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SRAIW: 32-bit arithmetic shift right immediate, sign extension |
| TC_PROP   | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | rd_addr_i propagation through the pipeline alongside result_o  |
| TC_B2B    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | Back-to-back transactions with valid_i held high (throughput)  |
| TC_BCKPR  | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | Output back-pressure: ready_i deasserted after result is valid |
| TC_ALL    | 2026-09-08 | Annim Jannat & Md. Sakib Hasan Shawon  | All test cases together                                        |

| REVISION | DATE       | AUTHOR                                 | DESCRIPTION      |
|----------|------------|----------------------------------------|------------------|
| 0.1      | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | Initial version  |
| 1.0      | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | Stable release   |

Author : Md. Sakib Hasan Shawon (mdsakibhasanshawon20@gmail.com)
Co-Author : Annim Jannat (jannatannim@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/
`include "adn_riscv_pkg.sv"

module adn_riscv_exe_i64_alu_tb;

  import adn_riscv_pkg::*;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  localparam int XLEN = 64;
  localparam time CLK_PERIOD = 10ns;  // 100 MHz
  localparam int TIMEOUT_CYCLES = 1000;  // watchdog for handshake waits

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  logic                   clk_i;
  logic                   arst_ni;

  rv_op_t                 alu_op_i;

  logic        [XLEN-1:0] operand_a_i;
  logic        [XLEN-1:0] operand_b_i;
  logic        [     4:0] rd_addr_i;

  logic                   valid_i;
  logic                   ready_o;

  logic        [XLEN-1:0] result_o;
  logic        [     4:0] rd_addr_o;

  logic                   valid_o;
  logic                   ready_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////
  int unsigned            watchdog_count;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  adn_riscv_exe_i64_alu #(
      .XLEN(XLEN)
  ) u_dut (
      .clk_i  (clk_i),
      .arst_ni(arst_ni),

      .alu_op_i(alu_op_i),

      .operand_a_i(operand_a_i),
      .operand_b_i(operand_b_i),
      .rd_addr_i  (rd_addr_i),

      .valid_i(valid_i),
      .ready_o(ready_o),

      .result_o (result_o),
      .rd_addr_o(rd_addr_o),

      .valid_o(valid_o),
      .ready_i(ready_i)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // drive the reset sequence and idle values
  task automatic reset_dut();
    arst_ni     <= 1'b0;
    alu_op_i    <= INVALID_INSTRUCTION;
    operand_a_i <= '0;
    operand_b_i <= '0;
    rd_addr_i   <= '0;
    valid_i     <= 1'b0;
    ready_i     <= 1'b1;
    repeat (5) @(posedge clk_i);
    arst_ni <= 1'b1;
    repeat (2) @(posedge clk_i);
  endtask

  // apply operands on the input handshake, then wait for the input to be accepted
  task automatic drive_input(input rv_op_t op, input logic [XLEN-1:0] a, input logic [XLEN-1:0] b,
                             input logic [4:0] rd);
    alu_op_i    <= op;
    operand_a_i <= a;
    operand_b_i <= b;
    rd_addr_i   <= rd;
    valid_i     <= 1'b1;

    watchdog_count = 0;
    do begin
      @(posedge clk_i);
      watchdog_count++;
      if (watchdog_count > TIMEOUT_CYCLES) begin
        $error("[%0t] TIMEOUT waiting for ready_o to accept input", $time);
        break;
      end
    end while (!ready_o);

    // deassert after the accepted cycle so only a single transaction is issued
    valid_i <= 1'b0;
  endtask

  // wait for a valid output, capturing result_o and rd_addr_o
  task automatic wait_output(output logic [XLEN-1:0] result, output logic [4:0] rd);
    watchdog_count = 0;
    do begin
      @(posedge clk_i);
      watchdog_count++;
      if (watchdog_count > TIMEOUT_CYCLES) begin
        $error("[%0t] TIMEOUT waiting for valid_o", $time);
        break;
      end
    end while (!(valid_o && ready_i));

    result = result_o;
    rd     = rd_addr_o;
  endtask

  // drive one operation end-to-end and self-check the result against an expected value
  task automatic check_op(input string tc_name, input rv_op_t op, input logic [XLEN-1:0] a,
                          input logic [XLEN-1:0] b, input logic [4:0] rd,
                          input logic [XLEN-1:0] exp_result);
    logic [XLEN-1:0] act_result;
    logic [     4:0] act_rd;
    bit              pass;

    drive_input(op, a, b, rd);
    wait_output(act_result, act_rd);

    pass = (act_result === exp_result) && (act_rd === rd);

    if (!pass) begin
      $display(
          "[%0t] %s FAILED: op=%p a=0x%0h b=0x%0h rd=%0d | exp_result=0x%0h act_result=0x%0h | exp_rd=%0d act_rd=%0d",
          $time, tc_name, op, a, b, rd, exp_result, act_result, rd, act_rd);
    end else begin
      $display("[%0t] %s PASSED: op=%p result=0x%0h rd=%0d", $time, tc_name, op, act_result,
               act_rd);
    end

    note_case(pass);
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST CASE TASKS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_TC_ADD();
    reset_dut();
    check_op("TC_ADD_ADD", ADD, 64'h0000_0000_0000_0005, 64'h0000_0000_0000_0003, 5'd1,
             64'h0000_0000_0000_0008);
  endtask

  task automatic test_TC_SUB();
    reset_dut();
    check_op("TC_SUB_SUB", SUB, 64'h0000_0000_0000_000A, 64'h0000_0000_0000_0003, 5'd2,
             64'h0000_0000_0000_0007);
  endtask

  task automatic test_TC_ADDI();
    reset_dut();
    check_op("TC_ADDI_ADDI", ADDI, 64'h0000_0000_0000_0064, 64'h0000_0000_0000_0019, 5'd3,
             64'h0000_0000_0000_007D);
  endtask

  task automatic test_TC_SLL();
    reset_dut();
    check_op("TC_SLL_SLL", SLL, 64'h0000_0000_0000_0001, 64'h0000_0000_0000_0004, 5'd4,
             64'h0000_0000_0000_0010);
  endtask

  task automatic test_TC_SLLI();
    reset_dut();
    check_op("TC_SLLI_SLLI", SLLI, 64'h0000_0000_0000_0001, 64'h0000_0000_0000_0008, 5'd5,
             64'h0000_0000_0000_0100);
  endtask

  task automatic test_TC_SLT();
    reset_dut();
    check_op("TC_SLT_SLT", SLT, 64'hFFFF_FFFF_FFFF_FFFB, 64'h0000_0000_0000_0003, 5'd6,
             64'h0000_0000_0000_0001);
  endtask

  task automatic test_TC_SLTI();
    reset_dut();
    check_op("TC_SLTI_SLTI", SLTI, 64'h0000_0000_0000_0005, 64'h0000_0000_0000_000A, 5'd7,
             64'h0000_0000_0000_0001);
  endtask

  task automatic test_TC_SLTU();
    reset_dut();
    check_op("TC_SLTU_SLTU", SLTU, 64'hFFFF_FFFF_FFFF_FFFB, 64'h0000_0000_0000_0003, 5'd8,
             64'h0000_0000_0000_0000);
  endtask

  task automatic test_TC_SLTIU();
    reset_dut();
    check_op("TC_SLTIU_SLTIU", SLTIU, 64'h0000_0000_0000_0003, 64'h0000_0000_0000_0005, 5'd9,
             64'h0000_0000_0000_0001);
  endtask

  task automatic test_TC_XOR();
    reset_dut();
    check_op("TC_XOR_XOR", XOR, 64'hAAAA_AAAA_AAAA_AAAA, 64'h5555_5555_5555_5555, 5'd10,
             64'hFFFF_FFFF_FFFF_FFFF);
  endtask

  task automatic test_TC_XORI();
    reset_dut();
    check_op("TC_XORI_XORI", XORI, 64'h0000_0000_0000_00FF, 64'h0000_0000_0000_000F, 5'd11,
             64'h0000_0000_0000_00F0);
  endtask

  task automatic test_TC_SRL();
    reset_dut();
    check_op("TC_SRL_SRL", SRL, 64'h8000_0000_0000_0000, 64'h0000_0000_0000_0004, 5'd12,
             64'h0800_0000_0000_0000);
  endtask

  task automatic test_TC_SRLI();
    reset_dut();
    check_op("TC_SRLI_SRLI", SRLI, 64'h0000_0000_0000_0010, 64'h0000_0000_0000_0004, 5'd13,
             64'h0000_0000_0000_0001);
  endtask

  task automatic test_TC_SRA();
    reset_dut();
    check_op("TC_SRA_SRA", SRA, 64'hFFFF_FFFF_FFFF_FFF8, 64'h0000_0000_0000_0001, 5'd14,
             64'hFFFF_FFFF_FFFF_FFFC);
  endtask

  task automatic test_TC_SRAI();
    reset_dut();
    check_op("TC_SRAI_SRAI", SRAI, 64'hFFFF_FFFF_FFFF_FFF0, 64'h0000_0000_0000_0004, 5'd15,
             64'hFFFF_FFFF_FFFF_FFFF);
  endtask

  task automatic test_TC_OR();
    reset_dut();
    check_op("TC_OR_OR", OR, 64'h0000_0000_0000_00F0, 64'h0000_0000_0000_000F, 5'd16,
             64'h0000_0000_0000_00FF);
  endtask

  task automatic test_TC_ORI();
    reset_dut();
    check_op("TC_ORI_ORI", ORI, 64'h0000_0000_0000_0000, 64'h0000_0000_0000_00FF, 5'd17,
             64'h0000_0000_0000_00FF);
  endtask

  task automatic test_TC_AND();
    reset_dut();
    check_op("TC_AND_AND", AND, 64'h0000_0000_0000_00FF, 64'h0000_0000_0000_000F, 5'd18,
             64'h0000_0000_0000_000F);
  endtask

  task automatic test_TC_ANDI();
    reset_dut();
    check_op("TC_ANDI_ANDI", ANDI, 64'h0000_0000_0000_00FF, 64'h0000_0000_0000_000F, 5'd19,
             64'h0000_0000_0000_000F);
  endtask

  task automatic test_TC_ADDW();
    reset_dut();
    check_op("TC_ADDW_ADDW", ADDW, 64'h0000_0000_7FFF_FFFF, 64'h0000_0000_0000_0001, 5'd20,
             64'hFFFF_FFFF_8000_0000);
  endtask

  task automatic test_TC_SUBW();
    reset_dut();
    check_op("TC_SUBW_SUBW", SUBW, 64'h0000_0000_0000_0000, 64'h0000_0000_0000_0001, 5'd21,
             64'hFFFF_FFFF_FFFF_FFFF);
  endtask

  task automatic test_TC_SLLW();
    reset_dut();
    check_op("TC_SLLW_SLLW", SLLW, 64'h0000_0000_0000_0001, 64'h0000_0000_0000_001F, 5'd22,
             64'hFFFF_FFFF_8000_0000);
  endtask

  task automatic test_TC_SRLW();
    reset_dut();
    check_op("TC_SRLW_SRLW", SRLW, 64'hFFFF_FFFF_FFFF_FFFF, 64'h0000_0000_0000_0004, 5'd23,
             64'h0000_0000_0FFF_FFFF);
  endtask

  task automatic test_TC_SRAW();
    reset_dut();
    check_op("TC_SRAW_SRAW", SRAW, 64'hFFFF_FFFF_8000_0000, 64'h0000_0000_0000_0004, 5'd24,
             64'hFFFF_FFFF_F800_0000);
  endtask

  task automatic test_TC_ADDIW();
    reset_dut();
    check_op("TC_ADDIW_ADDIW", ADDIW, 64'h0000_0000_0000_0005, 64'h0000_0000_0000_000A, 5'd25,
             64'h0000_0000_0000_000F);
  endtask

  task automatic test_TC_SLLIW();
    reset_dut();
    check_op("TC_SLLIW_SLLIW", SLLIW, 64'h0000_0000_0000_0001, 64'h0000_0000_0000_001F, 5'd26,
             64'hFFFF_FFFF_8000_0000);
  endtask

  task automatic test_TC_SRLIW();
    reset_dut();
    check_op("TC_SRLIW_SRLIW", SRLIW, 64'hFFFF_FFFF_FFFF_FFFF, 64'h0000_0000_0000_0004, 5'd27,
             64'h0000_0000_0FFF_FFFF);
  endtask

  task automatic test_TC_SRAIW();
    reset_dut();
    check_op("TC_SRAIW_SRAIW", SRAIW, 64'hFFFF_FFFF_8000_0000, 64'h0000_0000_0000_0004, 5'd28,
             64'hFFFF_FFFF_F800_0000);
  endtask

  task automatic test_TC_PROP();
    reset_dut();
    check_op("TC_PROP_RD_ADDR", ADD, 64'h0000_0000_0000_0001, 64'h0000_0000_0000_0001, 5'd31,
             64'h0000_0000_0000_0002);
  endtask

  task automatic test_TC_B2B();
    logic [XLEN-1:0] exp_results   [0:2];
    logic [     4:0] exp_rds       [0:2];
    logic [XLEN-1:0] act_results   [0:2];
    logic [     4:0] act_rds       [0:2];
    int              capture_count;
    bit              pass;
    int              i;

    reset_dut();

    exp_results[0] = 64'h0000_0000_0000_0002;  // ADD 1+1
    exp_results[1] = 64'h0000_0000_0000_0004;  // ADD 2+2
    exp_results[2] = 64'h0000_0000_0000_0006;  // ADD 3+3
    exp_rds[0] = 5'd1;
    exp_rds[1] = 5'd2;
    exp_rds[2] = 5'd3;

    pass = 1'b1;
    capture_count = 0;

    // start the monitor BEFORE issuing any pushes, so it's already
    // watching when push #1's result appears
    fork
      begin : result_monitor
        while (capture_count < 3) begin
          @(posedge clk_i);
          if (valid_o && ready_i) begin
            act_results[capture_count] = result_o;
            act_rds[capture_count]     = rd_addr_o;
            capture_count++;
          end
        end
      end
    join_none

    // issue three back-to-back inputs without deasserting valid_i in between
    for (i = 0; i < 3; i++) begin
      alu_op_i    <= ADD;
      operand_a_i <= i + 1;
      operand_b_i <= i + 1;
      rd_addr_i   <= exp_rds[i];
      valid_i     <= 1'b1;

      watchdog_count = 0;
      do begin
        @(posedge clk_i);
        watchdog_count++;
        if (watchdog_count > TIMEOUT_CYCLES) begin
          $error("[%0t] TC_B2B TIMEOUT waiting for ready_o (i=%0d)", $time, i);
          pass = 1'b0;
          break;
        end
      end while (!ready_o);
    end
    valid_i <= 1'b0;

    // now wait for the monitor to finish collecting all 3 (with its own watchdog)
    watchdog_count = 0;
    do begin
      @(posedge clk_i);
      watchdog_count++;
      if (watchdog_count > TIMEOUT_CYCLES) begin
        $error("[%0t] TC_B2B TIMEOUT waiting for all outputs", $time);
        pass = 1'b0;
        break;
      end
    end while (capture_count < 3);

    // check all three captured results, in order
    for (i = 0; i < 3; i++) begin
      if (act_results[i] !== exp_results[i] || act_rds[i] !== exp_rds[i]) begin
        $display(
            "[%0t] TC_B2B_BACK2BACK FAILED at i=%0d: exp_result=0x%0h act_result=0x%0h exp_rd=%0d act_rd=%0d",
            $time, i, exp_results[i], act_results[i], exp_rds[i], act_rds[i]);
        pass = 1'b0;
      end
    end

    if (pass) $display("[%0t] TC_B2B_BACK2BACK PASSED", $time);
    note_case(pass);
  endtask

  task automatic test_TC_BCKPR();
    logic [XLEN-1:0] act_result;
    logic [     4:0] act_rd;
    bit              pass;

    reset_dut();

    ready_i     <= 1'b0;

    alu_op_i    <= ADD;
    operand_a_i <= 64'h0000_0000_0000_0007;
    operand_b_i <= 64'h0000_0000_0000_0007;
    rd_addr_i   <= 5'd9;
    valid_i     <= 1'b1;

    watchdog_count = 0;
    do begin
      @(posedge clk_i);
      watchdog_count++;
      if (watchdog_count > TIMEOUT_CYCLES) begin
        $error("[%0t] TC_BCKPR TIMEOUT waiting for ready_o", $time);
        break;
      end
    end while (!ready_o);
    valid_i <= 1'b0;

    watchdog_count = 0;
    do begin
      @(posedge clk_i);
      watchdog_count++;
      if (watchdog_count > TIMEOUT_CYCLES) begin
        $error("[%0t] TC_BCKPR TIMEOUT waiting for valid_o", $time);
        break;
      end
    end while (!valid_o);

    // hold back-pressure for a few cycles, result must remain stable and valid
    pass = 1'b1;
    repeat (3) begin
      @(posedge clk_i);
      if (!valid_o || result_o !== 64'h0000_0000_0000_000E || rd_addr_o !== 5'd9) begin
        $display("[%0t] TC_BCKPR_BACKPRESSURE FAILED: output not held stable while ready_i=0",
                 $time);
        pass = 1'b0;
      end
    end

    // release back-pressure and accept the result
    ready_i <= 1'b1;
    @(posedge clk_i);
    act_result = result_o;
    act_rd     = rd_addr_o;
    if (act_result !== 64'h0000_0000_0000_000E || act_rd !== 5'd9) begin
      $display(
          "[%0t] TC_BCKPR_BACKPRESSURE FAILED: exp_result=0x%0h act_result=0x%0h exp_rd=%0d act_rd=%0d",
          $time, 64'h0000_0000_0000_000E, act_result, 5'd9, act_rd);
      pass = 1'b0;
    end

    ready_i <= 1'b1;

    if (pass) $display("[%0t] TC_BCKPR_BACKPRESSURE PASSED", $time);
    note_case(pass);
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  initial begin  // clock generation
    clk_i <= 1'b0;
    forever #(CLK_PERIOD / 2) clk_i <= ~clk_i;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin  // main initial

    case (test_name)

      "TC_ADD":    test_TC_ADD();
      "TC_SUB":    test_TC_SUB();
      "TC_ADDI":   test_TC_ADDI();
      "TC_SLL":    test_TC_SLL();
      "TC_SLLI":   test_TC_SLLI();
      "TC_SLT":    test_TC_SLT();
      "TC_SLTI":   test_TC_SLTI();
      "TC_SLTU":   test_TC_SLTU();
      "TC_SLTIU":  test_TC_SLTIU();
      "TC_XOR":    test_TC_XOR();
      "TC_XORI":   test_TC_XORI();
      "TC_SRL":    test_TC_SRL();
      "TC_SRLI":   test_TC_SRLI();
      "TC_SRA":    test_TC_SRA();
      "TC_SRAI":   test_TC_SRAI();
      "TC_OR":     test_TC_OR();
      "TC_ORI":    test_TC_ORI();
      "TC_AND":    test_TC_AND();
      "TC_ANDI":   test_TC_ANDI();
      "TC_ADDW":   test_TC_ADDW();
      "TC_SUBW":   test_TC_SUBW();
      "TC_SLLW":   test_TC_SLLW();
      "TC_SRLW":   test_TC_SRLW();
      "TC_SRAW":   test_TC_SRAW();
      "TC_ADDIW":  test_TC_ADDIW();
      "TC_SLLIW":  test_TC_SLLIW();
      "TC_SRLIW":  test_TC_SRLIW();
      "TC_SRAIW":  test_TC_SRAIW();
      "TC_PROP":   test_TC_PROP();
      "TC_B2B":    test_TC_B2B();
      "TC_BCKPR":  test_TC_BCKPR();

      "TC_ALL", "default": begin
        test_TC_ADD();
        test_TC_SUB();
        test_TC_ADDI();
        test_TC_SLL();
        test_TC_SLLI();
        test_TC_SLT();
        test_TC_SLTI();
        test_TC_SLTU();
        test_TC_SLTIU();
        test_TC_XOR();
        test_TC_XORI();
        test_TC_SRL();
        test_TC_SRLI();
        test_TC_SRA();
        test_TC_SRAI();
        test_TC_OR();
        test_TC_ORI();
        test_TC_AND();
        test_TC_ANDI();
        test_TC_ADDW();
        test_TC_SUBW();
        test_TC_SLLW();
        test_TC_SRLW();
        test_TC_SRAW();
        test_TC_ADDIW();
        test_TC_SLLIW();
        test_TC_SRLIW();
        test_TC_SRAIW();
        test_TC_PROP();
        test_TC_B2B();
        test_TC_BCKPR();
      end

    endcase

    $finish;

  end

endmodule
