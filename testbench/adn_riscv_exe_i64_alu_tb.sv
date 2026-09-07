/*

| TEST CASE | DATE       | AUTHOR                                 | DESCRIPTION                                                    |
|-----------|------------|----------------------------------------|----------------------------------------------------------------|
| TC_001    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | ADD: simple positive addition                                  |
| TC_002    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SUB: simple subtraction                                        |
| TC_003    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | ADDI: register + immediate addition                            |
| TC_004    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SLL: logical shift left, shift amount from operand_b_i[5:0]    |
| TC_005    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SLLI: logical shift left with immediate                        |
| TC_006    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SLT: signed less-than, negative operand_a_i                    |
| TC_007    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SLTI: signed less-than immediate                               |
| TC_008    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SLTU: unsigned less-than, large unsigned operand_a_i           |
| TC_009    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SLTIU: unsigned less-than immediate                            |
| TC_010    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | XOR: alternating bit pattern                                   |
| TC_011    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | XORI: XOR with immediate                                       |
| TC_012    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SRL: logical shift right of MSB-set value                      |
| TC_013    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SRLI: logical shift right with immediate                       |
| TC_014    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SRA: arithmetic shift right, negative operand_a_i              |
| TC_015    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SRAI: arithmetic shift right immediate, negative operand_a_i   |
| TC_016    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | OR: bitwise OR                                                 |
| TC_017    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | ORI: bitwise OR with immediate                                 |
| TC_018    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | AND: bitwise AND                                               |
| TC_019    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | ANDI: bitwise AND with immediate                               |
| TC_020    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | ADDW: 32-bit add that overflows into sign bit, sign extension  |
| TC_021    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SUBW: 32-bit subtract producing a negative word result         |
| TC_022    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SLLW: 32-bit shift left producing a negative word result       |
| TC_023    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SRLW: 32-bit logical shift right, zero extension               |
| TC_024    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SRAW: 32-bit arithmetic shift right, sign extension            |
| TC_025    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | ADDIW: 32-bit add immediate, positive result                   |
| TC_026    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SLLIW: 32-bit shift left immediate, negative word result       |
| TC_027    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SRLIW: 32-bit logical shift right immediate, zero extension    |
| TC_028    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | SRAIW: 32-bit arithmetic shift right immediate, sign extension |
| TC_029    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | rd_addr_i propagation through the pipeline alongside result_o  |
| TC_030    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | Back-to-back transactions with valid_i held high (throughput)  |
| TC_031    | 2026-09-07 | Annim Jannat & Md. Sakib Hasan Shawon  | Output back-pressure: ready_i deasserted after result is valid |

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
  localparam int XLEN        = 64;
  localparam time CLK_PERIOD = 10ns;   // 100 MHz
  localparam int  TIMEOUT_CYCLES = 1000; // watchdog for handshake waits

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  logic clk_i;
  logic arst_ni;

  rv_op_t alu_op_i;

  logic [XLEN-1:0] operand_a_i;
  logic [XLEN-1:0] operand_b_i;
  logic [4:0]      rd_addr_i;

  logic valid_i;
  logic ready_o;

  logic [XLEN-1:0] result_o;
  logic [4:0]      rd_addr_o;

  logic valid_o;
  logic ready_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////
  int unsigned watchdog_count;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  adn_riscv_exe_i64_alu #(
      .XLEN(XLEN)
  ) u_dut (
      .clk_i      (clk_i),
      .arst_ni    (arst_ni),

      .alu_op_i   (alu_op_i),

      .operand_a_i(operand_a_i),
      .operand_b_i(operand_b_i),
      .rd_addr_i  (rd_addr_i),

      .valid_i    (valid_i),
      .ready_o    (ready_o),

      .result_o   (result_o),
      .rd_addr_o  (rd_addr_o),

      .valid_o    (valid_o),
      .ready_i    (ready_i)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // drive the reset sequence and idle values
  task automatic reset_dut();
    arst_ni     = 1'b0;
    alu_op_i    = INVALID_INSTRUCTION;
    operand_a_i = '0;
    operand_b_i = '0;
    rd_addr_i   = '0;
    valid_i     = 1'b0;
    ready_i     = 1'b1;
    repeat (5) @(posedge clk_i);
    arst_ni = 1'b1;
    repeat (2) @(posedge clk_i);
  endtask

  // apply operands on the input handshake, then wait for the input to be accepted
  task automatic drive_input(
      input rv_op_t          op,
      input logic [XLEN-1:0] a,
      input logic [XLEN-1:0] b,
      input logic [4:0]      rd
  );
    alu_op_i    = op;
    operand_a_i = a;
    operand_b_i = b;
    rd_addr_i   = rd;
    valid_i     = 1'b1;

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
    valid_i = 1'b0;
  endtask

  // wait for a valid output, capturing result_o and rd_addr_o
  task automatic wait_output(
      output logic [XLEN-1:0] result,
      output logic [4:0]      rd
  );
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
  task automatic check_op(
      input string           tc_name,
      input rv_op_t          op,
      input logic [XLEN-1:0] a,
      input logic [XLEN-1:0] b,
      input logic [4:0]      rd,
      input logic [XLEN-1:0] exp_result
  );
    logic [XLEN-1:0] act_result;
    logic [4:0]      act_rd;
    bit              pass;

    drive_input(op, a, b, rd);
    wait_output(act_result, act_rd);

    pass = (act_result === exp_result) && (act_rd === rd);

    if (!pass) begin
      $display("[%0t] %s FAILED: op=%p a=0x%0h b=0x%0h rd=%0d | exp_result=0x%0h act_result=0x%0h | exp_rd=%0d act_rd=%0d",
                $time, tc_name, op, a, b, rd, exp_result, act_result, rd, act_rd);
    end else begin
      $display("[%0t] %s PASSED: op=%p result=0x%0h rd=%0d", $time, tc_name, op, act_result, act_rd);
    end

    note_case(pass);
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  initial begin  // clock generation
    clk_i = 1'b0;
    forever #(CLK_PERIOD / 2) clk_i = ~clk_i;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin  // main initial

    reset_dut();

    // ------------------------------------------------
    // RV64I register-register / register-immediate ops
    // ------------------------------------------------

    // TC_001: ADD - 5 + 3 = 8
    check_op("TC_001_ADD", ADD,
              64'h0000_0000_0000_0005, 64'h0000_0000_0000_0003, 5'd1,
              64'h0000_0000_0000_0008);

    // TC_002: SUB - 10 - 3 = 7
    check_op("TC_002_SUB", SUB,
              64'h0000_0000_0000_000A, 64'h0000_0000_0000_0003, 5'd2,
              64'h0000_0000_0000_0007);

    // TC_003: ADDI - 100 + 25 = 125
    check_op("TC_003_ADDI", ADDI,
              64'h0000_0000_0000_0064, 64'h0000_0000_0000_0019, 5'd3,
              64'h0000_0000_0000_007D);

    // TC_004: SLL - 1 << 4 = 16
    check_op("TC_004_SLL", SLL,
              64'h0000_0000_0000_0001, 64'h0000_0000_0000_0004, 5'd4,
              64'h0000_0000_0000_0010);

    // TC_005: SLLI - 1 << 8 = 256
    check_op("TC_005_SLLI", SLLI,
              64'h0000_0000_0000_0001, 64'h0000_0000_0000_0008, 5'd5,
              64'h0000_0000_0000_0100);

    // TC_006: SLT - (-5) < 3 (signed) => 1
    check_op("TC_006_SLT", SLT,
              64'hFFFF_FFFF_FFFF_FFFB, 64'h0000_0000_0000_0003, 5'd6,
              64'h0000_0000_0000_0001);

    // TC_007: SLTI - 5 < 10 (signed) => 1
    check_op("TC_007_SLTI", SLTI,
              64'h0000_0000_0000_0005, 64'h0000_0000_0000_000A, 5'd7,
              64'h0000_0000_0000_0001);

    // TC_008: SLTU - large unsigned value is NOT less than 3 => 0
    check_op("TC_008_SLTU", SLTU,
              64'hFFFF_FFFF_FFFF_FFFB, 64'h0000_0000_0000_0003, 5'd8,
              64'h0000_0000_0000_0000);

    // TC_009: SLTIU - 3 < 5 (unsigned) => 1
    check_op("TC_009_SLTIU", SLTIU,
              64'h0000_0000_0000_0003, 64'h0000_0000_0000_0005, 5'd9,
              64'h0000_0000_0000_0001);

    // TC_010: XOR - alternating pattern -> all ones
    check_op("TC_010_XOR", XOR,
              64'hAAAA_AAAA_AAAA_AAAA, 64'h5555_5555_5555_5555, 5'd10,
              64'hFFFF_FFFF_FFFF_FFFF);

    // TC_011: XORI - 0xFF ^ 0x0F = 0xF0
    check_op("TC_011_XORI", XORI,
              64'h0000_0000_0000_00FF, 64'h0000_0000_0000_000F, 5'd11,
              64'h0000_0000_0000_00F0);

    // TC_012: SRL - MSB set, shift right by 4
    check_op("TC_012_SRL", SRL,
              64'h8000_0000_0000_0000, 64'h0000_0000_0000_0004, 5'd12,
              64'h0800_0000_0000_0000);

    // TC_013: SRLI - 0x10 >> 4 = 0x1
    check_op("TC_013_SRLI", SRLI,
              64'h0000_0000_0000_0010, 64'h0000_0000_0000_0004, 5'd13,
              64'h0000_0000_0000_0001);

    // TC_014: SRA - (-8) >>> 1 (signed) = -4
    check_op("TC_014_SRA", SRA,
              64'hFFFF_FFFF_FFFF_FFF8, 64'h0000_0000_0000_0001, 5'd14,
              64'hFFFF_FFFF_FFFF_FFFC);

    // TC_015: SRAI - (-16) >>> 4 (signed) = -1
    check_op("TC_015_SRAI", SRAI,
              64'hFFFF_FFFF_FFFF_FFF0, 64'h0000_0000_0000_0004, 5'd15,
              64'hFFFF_FFFF_FFFF_FFFF);

    // TC_016: OR - 0xF0 | 0x0F = 0xFF
    check_op("TC_016_OR", OR,
              64'h0000_0000_0000_00F0, 64'h0000_0000_0000_000F, 5'd16,
              64'h0000_0000_0000_00FF);

    // TC_017: ORI - 0x00 | 0xFF = 0xFF
    check_op("TC_017_ORI", ORI,
              64'h0000_0000_0000_0000, 64'h0000_0000_0000_00FF, 5'd17,
              64'h0000_0000_0000_00FF);

    // TC_018: AND - 0xFF & 0x0F = 0x0F
    check_op("TC_018_AND", AND,
              64'h0000_0000_0000_00FF, 64'h0000_0000_0000_000F, 5'd18,
              64'h0000_0000_0000_000F);

    // TC_019: ANDI - 0xFF & 0x0F = 0x0F
    check_op("TC_019_ANDI", ANDI,
              64'h0000_0000_0000_00FF, 64'h0000_0000_0000_000F, 5'd19,
              64'h0000_0000_0000_000F);

    // ------------------------------------------------
    // RV64I word (32-bit) ops, all sign extended per spec
    // ------------------------------------------------

    // TC_020: ADDW - 0x7FFFFFFF + 1 overflows into the 32-bit sign bit
    check_op("TC_020_ADDW", ADDW,
              64'h0000_0000_7FFF_FFFF, 64'h0000_0000_0000_0001, 5'd20,
              64'hFFFF_FFFF_8000_0000);

    // TC_021: SUBW - 0 - 1 (32-bit) = -1, sign extended
    check_op("TC_021_SUBW", SUBW,
              64'h0000_0000_0000_0000, 64'h0000_0000_0000_0001, 5'd21,
              64'hFFFF_FFFF_FFFF_FFFF);

    // TC_022: SLLW - 1 << 31 (32-bit) sets the word's sign bit
    check_op("TC_022_SLLW", SLLW,
              64'h0000_0000_0000_0001, 64'h0000_0000_0000_001F, 5'd22,
              64'hFFFF_FFFF_8000_0000);

    // TC_023: SRLW - logical shift right of an all-ones word, zero extended
    check_op("TC_023_SRLW", SRLW,
              64'hFFFF_FFFF_FFFF_FFFF, 64'h0000_0000_0000_0004, 5'd23,
              64'h0000_0000_0FFF_FFFF);

    // TC_024: SRAW - arithmetic shift right of a negative word, sign extended
    check_op("TC_024_SRAW", SRAW,
              64'hFFFF_FFFF_8000_0000, 64'h0000_0000_0000_0004, 5'd24,
              64'hFFFF_FFFF_F800_0000);

    // TC_025: ADDIW - 5 + 10 (32-bit immediate) = 15
    check_op("TC_025_ADDIW", ADDIW,
              64'h0000_0000_0000_0005, 64'h0000_0000_0000_000A, 5'd25,
              64'h0000_0000_0000_000F);

    // TC_026: SLLIW - 1 << 31 (32-bit immediate) sets the word's sign bit
    check_op("TC_026_SLLIW", SLLIW,
              64'h0000_0000_0000_0001, 64'h0000_0000_0000_001F, 5'd26,
              64'hFFFF_FFFF_8000_0000);

    // TC_027: SRLIW - logical shift right immediate, zero extended
    check_op("TC_027_SRLIW", SRLIW,
              64'hFFFF_FFFF_FFFF_FFFF, 64'h0000_0000_0000_0004, 5'd27,
              64'h0000_0000_0FFF_FFFF);

    // TC_028: SRAIW - arithmetic shift right immediate, sign extended
    check_op("TC_028_SRAIW", SRAIW,
              64'hFFFF_FFFF_8000_0000, 64'h0000_0000_0000_0004, 5'd28,
              64'hFFFF_FFFF_F800_0000);

    // ------------------------------------------------
    // Destination address / handshake behavior
    // ------------------------------------------------

    // TC_029: rd_addr_i must travel through the pipeline alongside the result
    check_op("TC_029_RD_ADDR", ADD,
              64'h0000_0000_0000_0001, 64'h0000_0000_0000_0001, 5'd31,
              64'h0000_0000_0000_0002);

    // TC_030: back-to-back transactions with valid_i held high (throughput test)
    begin
      logic [XLEN-1:0] exp_results [0:2];
      logic [4:0]      exp_rds     [0:2];
      logic [XLEN-1:0] act_result;
      logic [4:0]      act_rd;
      bit              pass;
      int              i;

      exp_results[0] = 64'h0000_0000_0000_0002; // ADD 1+1
      exp_results[1] = 64'h0000_0000_0000_0004; // ADD 2+2
      exp_results[2] = 64'h0000_0000_0000_0006; // ADD 3+3
      exp_rds[0] = 5'd1;
      exp_rds[1] = 5'd2;
      exp_rds[2] = 5'd3;

      pass = 1'b1;

      // issue three back-to-back inputs without deasserting valid_i in between
      for (i = 0; i < 3; i++) begin
        alu_op_i    = ADD;
        operand_a_i = i + 1;
        operand_b_i = i + 1;
        rd_addr_i   = exp_rds[i];
        valid_i     = 1'b1;

        watchdog_count = 0;
        do begin
          @(posedge clk_i);
          watchdog_count++;
          if (watchdog_count > TIMEOUT_CYCLES) begin
            $error("[%0t] TC_030 TIMEOUT waiting for ready_o (i=%0d)", $time, i);
            pass = 1'b0;
            break;
          end
        end while (!ready_o);
      end
      valid_i = 1'b0;

      // collect the three expected outputs, in order
      for (i = 0; i < 3; i++) begin
        wait_output(act_result, act_rd);
        if (act_result !== exp_results[i] || act_rd !== exp_rds[i]) begin
          $display("[%0t] TC_030_BACK2BACK FAILED at i=%0d: exp_result=0x%0h act_result=0x%0h exp_rd=%0d act_rd=%0d",
                    $time, i, exp_results[i], act_result, exp_rds[i], act_rd);
          pass = 1'b0;
        end
      end

      if (pass) $display("[%0t] TC_030_BACK2BACK PASSED", $time);
      note_case(pass);
    end

    // TC_031: output back-pressure - deassert ready_i, confirm valid_o holds, then accept
    begin
      logic [XLEN-1:0] act_result;
      logic [4:0]      act_rd;
      bit              pass;

      ready_i = 1'b0;

      alu_op_i    = ADD;
      operand_a_i = 64'h0000_0000_0000_0007;
      operand_b_i = 64'h0000_0000_0000_0007;
      rd_addr_i   = 5'd9;
      valid_i     = 1'b1;

      watchdog_count = 0;
      do begin
        @(posedge clk_i);
        watchdog_count++;
        if (watchdog_count > TIMEOUT_CYCLES) begin
          $error("[%0t] TC_031 TIMEOUT waiting for ready_o", $time);
          break;
        end
      end while (!ready_o);
      valid_i = 1'b0;

      watchdog_count = 0;
      do begin
        @(posedge clk_i);
        watchdog_count++;
        if (watchdog_count > TIMEOUT_CYCLES) begin
          $error("[%0t] TC_031 TIMEOUT waiting for valid_o", $time);
          break;
        end
      end while (!valid_o);

      // hold back-pressure for a few cycles, result must remain stable and valid
      pass = 1'b1;
      repeat (3) begin
        @(posedge clk_i);
        if (!valid_o || result_o !== 64'h0000_0000_0000_000E || rd_addr_o !== 5'd9) begin
          $display("[%0t] TC_031_BACKPRESSURE FAILED: output not held stable while ready_i=0", $time);
          pass = 1'b0;
        end
      end

      // release back-pressure and accept the result
      ready_i = 1'b1;
      @(posedge clk_i);
      act_result = result_o;
      act_rd     = rd_addr_o;
      if (act_result !== 64'h0000_0000_0000_000E || act_rd !== 5'd9) begin
        $display("[%0t] TC_031_BACKPRESSURE FAILED: exp_result=0x%0h act_result=0x%0h exp_rd=%0d act_rd=%0d",
                  $time, 64'h0000_0000_0000_000E, act_result, 5'd9, act_rd);
        pass = 1'b0;
      end

      ready_i = 1'b1;

      if (pass) $display("[%0t] TC_031_BACKPRESSURE PASSED", $time);
      note_case(pass);
    end

    $finish;

  end

endmodule
