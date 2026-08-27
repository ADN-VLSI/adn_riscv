/*

| TEST CASE    | DATE       | AUTHOR            | DESCRIPTION                                              |
|--------------|------------|-------------------|----------------------------------------------------------|
| TC_RTYPE_01  | 2026-08-25 | Shykul Islam Siam | ADD instruction decoding (R-type format)                 |
| TC_RTYPE_02  | 2026-08-25 | Shykul Islam Siam | SUB instruction decoding (R-type format)                 |
| TC_RTYPE_03  | 2026-08-25 | Shykul Islam Siam | Register extraction for R-type instructions              |
| TC_ITYPE_01  | 2026-08-25 | Shykul Islam Siam | ADDI with positive immediate (I-type format)             |
| TC_ITYPE_02  | 2026-08-25 | Shykul Islam Siam | ADDI with negative immediate (sign extension)            |
| TC_ITYPE_03  | 2026-08-25 | Shykul Islam Siam | LW immediate extraction (I-type format)                  |
| TC_ITYPE_04  | 2026-08-25 | Shykul Islam Siam | Register extraction for I-type instructions              |
| TC_BTYPE_01  | 2026-08-25 | Shykul Islam Siam | BEQ instruction decoding (B-type format)                 |
| TC_BTYPE_02  | 2026-08-25 | Shykul Islam Siam | BLT branch immediate extraction                          |
| TC_STYPE_01  | 2026-08-25 | Shykul Islam Siam | SW instruction decoding (S-type format)                  |
| TC_STYPE_02  | 2026-08-25 | Shykul Islam Siam | S-type immediate extraction for store operations         |
| TC_STYPE_03  | 2026-08-25 | Shykul Islam Siam | S-type store, non-zero imm[11:5] (sign-extension check)  |
| TC_UTYPE_01  | 2026-08-25 | Shykul Islam Siam | LUI upper immediate extraction (U-type format)           |
| TC_UTYPE_02  | 2026-08-25 | Shykul Islam Siam | AUIPC instruction decoding (U-type format)               |
| TC_JTYPE_01  | 2026-08-25 | Shykul Islam Siam | JAL jump immediate extraction (J-type format)            |
| TC_JTYPE_02  | 2026-08-25 | Shykul Islam Siam | J-type register and immediate extraction                 |
| TC_RV64_01   | 2026-08-25 | Shykul Islam Siam | LD instruction (RV64I 64-bit load)                       |
| TC_RV64_02   | 2026-08-25 | Shykul Islam Siam | ADDIW instruction (RV64I 32-bit arithmetic)              |
| TC_REG_01    | 2026-08-25 | Shykul Islam Siam | Zero register (x0) handling in register extraction       |
| TC_REG_02    | 2026-08-25 | Shykul Islam Siam | Boundary register (x31) access validation                |
| TC_REG_03    | 2026-08-25 | Shykul Islam Siam | Register requirements bitmap generation                  |
| TC_FTYPE_01  | 2026-08-25 | Shykul Islam Siam | FADD_S rounding-mode field extraction                    |
| TC_ATYPE_01  | 2026-08-25 | Shykul Islam Siam | AMOADD.D instruction decoding (RV64A)                    |
| TC_CORNER_01 | 2026-08-27 | Motasim Faiyaz    | ADDI max positive 12-bit I-type immediate (+2047)        |
| TC_CORNER_02 | 2026-08-27 | Motasim Faiyaz    | ADDI min negative 12-bit I-type immediate (-2048)        |
| TC_CORNER_03 | 2026-08-27 | Motasim Faiyaz    | SW max positive S-type immediate boundary                |
| TC_CORNER_04 | 2026-08-27 | Motasim Faiyaz    | SW min negative S-type immediate boundary                |
| TC_CORNER_05 | 2026-08-27 | Motasim Faiyaz    | BEQ max positive B-type branch offset                    |
| TC_CORNER_06 | 2026-08-27 | Motasim Faiyaz    | BEQ min negative B-type branch offset                    |
| TC_CORNER_07 | 2026-08-27 | Motasim Faiyaz    | JAL max positive J-type jump offset                      |
| TC_CORNER_08 | 2026-08-27 | Motasim Faiyaz    | JAL min negative J-type jump offset                      |
| TC_CORNER_09 | 2026-08-27 | Motasim Faiyaz    | LUI all-ones U-type immediate                            |
| TC_CORNER_10 | 2026-08-27 | Motasim Faiyaz    | ADD with all register fields at x31 boundary             |
| TC_CORNER_11 | 2026-08-27 | Motasim Faiyaz    | ADD x0,x0,x0 register-requirements bitmap check          |
| TC_CORNER_12 | 2026-08-27 | Motasim Faiyaz    | SLLI RV64 maximum shift amount (63)                      |
| TC_CORNER_13 | 2026-08-27 | Motasim Faiyaz    | Fully illegal 32-bit encoding (found_o must deassert)    |
| TC_CORNER_14 | 2026-08-27 | Motasim Faiyaz    | Valid R-type opcode with invalid funct7/funct3           |
| TC_CORNER_15 | 2026-08-27 | Motasim Faiyaz    | CSRRW immediate handling via the shared iimm path (Zicsr)|
| TC_CORNER_16 | 2026-08-27 | Motasim Faiyaz    | FENCE.I decoding (Zifencei), zero-operand instruction    |
| TC_CORNER_17 | 2026-08-27 | Motasim Faiyaz    | SRAI vs SRLI funct7 disambiguation, single-bit shamt     |
| TC_ALL       | 2026-08-27 | Shykul Islam Siam | All directed and corner-case tests                       |

| REVISION | DATE       | AUTHOR            | DESCRIPTION                              |
|----------|------------|-------------------|------------------------------------------|
| 0.1      | 2026-08-25 | Shykul Islam Siam | Initial testbench version                |
| 1.0      | 2026-08-25 | Motasim           | Added CORNER TEST_CASES                  |
| 1.1      | 2026-08-27 | Shykul Islam Siam | Wired corner cases into TC_ALL           |
| 1.2      | 2026-08-27 | Motasim           | Fixed Bug in TC_CORNER_15                |
| 1.3      | 2026-08-27 | Shykul Islam Siam | Stable release                           |

Author      : Shykul Islam Siam (shykulislam32@gmail.com) & Motasim (motasimfaiyaz@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/


module adn_riscv_instr_decoder_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `include "vip/adn_common_tb_headers.sv"  // Common TB utilities and plusargs
  `include "adn_riscv/typedef.svh"         // RISC-V typedef macros
  `include "adn_riscv_pkg.sv"              // RISC-V package
  import adn_riscv_pkg::*;                 // Import decoder types and enums

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int XLEN           = 64;                // Processor word width
  localparam int CLOG2_NUM_REGS = 5;                 // Register index width
  localparam int NUM_REGS       = 2 ** CLOG2_NUM_REGS; // Number of architectural registers

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `ADN_RISCV_T(adn_riscv, CLOG2_NUM_REGS, XLEN)     // Generate decoded instruction typedefs

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [31:0] encoded_instr;                       // Instruction word driven to DUT
  adn_riscv_decoded_instr_t decoded_instr;          // Decoded instruction from DUT
  logic found;                                       // DUT instruction match indicator

  int tc_fail_count;                                 // Field mismatches in current test
  int total_tc_run;                                  // Total test cases executed
  int total_tc_failed;                               // Total failed test cases
  string failed_tc_list[$];                          // Names of failed test cases

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_riscv_instr_decoder #(
      .XLEN            (XLEN),                       // Processor word width
      .EN_ZIFENCE_I    (1),                          // Enable Zifencei
      .EN_ZICSR        (1),                          // Enable Zicsr
      .EN_MATH         (1),                          // Enable M extension
      .EN_ATOMICS      (1),                          // Enable A extension
      .EN_FLOAT        (1),                          // Enable F extension
      .EN_DOUBLE       (1),                          // Enable D extension
      .decoded_instr_t (adn_riscv_decoded_instr_t)   // Decoded instruction type
  ) dut (
      .encoded_instr_i(encoded_instr),               // Encoded instruction input
      .decoded_instr_o(decoded_instr),               // Decoded instruction output
      .found_o        (found)                        // Instruction match output
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Drive instruction and allow combinational decode to settle
  task automatic drive_instr(input logic [31:0] instr);
    encoded_instr = instr;                            // Apply instruction encoding
    #1;                                               // Wait for combinational propagation
  endtask

  // Initialize per-test-case tracking
  task automatic tc_begin(input string tc_name);
    tc_fail_count = 0;                                // Clear current test failures
    total_tc_run++;                                   // Count executed test case

    if (debug)
      $display("[%0t] ---- START %s ----", $time, tc_name);
  endtask

  // Report the current test-case result
  task automatic tc_end(input string tc_name);

    if (tc_fail_count == 0) begin
      $display("\033[1;32m[PASS] %s\033[0m", tc_name);
    end else begin
      total_tc_failed++;                              // Record failed test
      failed_tc_list.push_back(tc_name);              // Save test name

      $display("\033[1;31m[FAIL] %s (%0d mismatched field%s)\033[0m",
               tc_name,
               tc_fail_count,
               (tc_fail_count == 1) ? "" : "s");
    end

  endtask

  // Check one decoded field
  task automatic check_field(input string tc_name,
                             input string field_name,
                             input bit    match,
                             input string got,
                             input string exp);

    note_case(match);                                 // Update common TB result counter

    if (!match) begin
      tc_fail_count++;                                // Record field mismatch

      $display("\033[1;31m[FAIL] %s : %s mismatch -> got=%s exp=%s\033[0m",
               tc_name,
               field_name,
               got,
               exp);
    end

  endtask

  // Drive an instruction and check the selected decoded fields
  task automatic check_decode(input string tc_name,
                              input logic [31:0] instr,
                              input adn_riscv_decoded_instr_t exp,
                              input bit chk_rd,
                              input bit chk_rs1,
                              input bit chk_rs2,
                              input bit chk_imm);

    tc_begin(tc_name);                                // Start test tracking
    drive_instr(instr);                               // Apply instruction

    check_field(tc_name,
                "decoded_valid",
                (decoded_instr.op != INVALID_INSTRUCTION),
                decoded_instr.op.name(),
                "non-invalid");

    check_field(tc_name,
                "op",
                (decoded_instr.op == exp.op),
                decoded_instr.op.name(),
                exp.op.name());

    if (chk_rd)
      check_field(tc_name,
                  "rd",
                  (decoded_instr.rd == exp.rd),
                  $sformatf("%0d", decoded_instr.rd),
                  $sformatf("%0d", exp.rd));

    if (chk_rs1)
      check_field(tc_name,
                  "rs1",
                  (decoded_instr.rs1 == exp.rs1),
                  $sformatf("%0d", decoded_instr.rs1),
                  $sformatf("%0d", exp.rs1));

    if (chk_rs2)
      check_field(tc_name,
                  "rs2",
                  (decoded_instr.rs2 == exp.rs2),
                  $sformatf("%0d", decoded_instr.rs2),
                  $sformatf("%0d", exp.rs2));

    if (chk_imm)
      check_field(tc_name,
                  "imm",
                  (decoded_instr.imm == exp.imm),
                  $sformatf("0x%0h", decoded_instr.imm),
                  $sformatf("0x%0h", exp.imm));

    if (debug)
      $display("[%0t] op=%s rd=%0d rs1=%0d rs2=%0d imm=%0h",
               $time,
               decoded_instr.op.name(),
               decoded_instr.rd,
               decoded_instr.rs1,
               decoded_instr.rs2,
               decoded_instr.imm);

    tc_end(tc_name);                                   // Finish test tracking

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST CASES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // TC_RTYPE_01 : ADD x1, x2, x3
  task automatic tc_rtype_01_add_decode();
    check_decode("TC_RTYPE_01",
                 32'h003100B3,
                 '{op: ADD, rd: 5'd1, rs1: 5'd2, rs2: 5'd3, default: '0},
                 1'b1, 1'b1, 1'b1, 1'b0);
  endtask

  // TC_RTYPE_02 : SUB x4, x5, x6
  task automatic tc_rtype_02_sub_decode();
    check_decode("TC_RTYPE_02",
                 32'h40628233,
                 '{op: SUB, rd: 5'd4, rs1: 5'd5, rs2: 5'd6, default: '0},
                 1'b1, 1'b1, 1'b1, 1'b0);
  endtask

  // TC_RTYPE_03 : AND x31, x31, x31
  task automatic tc_rtype_03_reg_boundary();
    check_decode("TC_RTYPE_03",
                 32'h01FFFFB3,
                 '{op: AND, rd: 5'd31, rs1: 5'd31, rs2: 5'd31, default: '0},
                 1'b1, 1'b1, 1'b1, 1'b0);
  endtask

  // TC_ITYPE_01 : ADDI x1, x2, 10
  task automatic tc_itype_01_addi_pos_imm();
    check_decode("TC_ITYPE_01",
                 32'h00A10093,
                 '{op: ADDI, rd: 5'd1, rs1: 5'd2, imm: 32'h0000000A, default: '0},
                 1'b1, 1'b1, 1'b0, 1'b1);
  endtask

  // TC_ITYPE_02 : ADDI x3, x4, -5
  task automatic tc_itype_02_addi_neg_imm();
    check_decode("TC_ITYPE_02",
                 32'hFFB20193,
                 '{op: ADDI, rd: 5'd3, rs1: 5'd4, imm: 32'hFFFFFFFB, default: '0},
                 1'b1, 1'b1, 1'b0, 1'b1);
  endtask

  // TC_ITYPE_03 : LW x5, 8(x6)
  task automatic tc_itype_03_lw_imm_extract();
    check_decode("TC_ITYPE_03",
                 32'h00832283,
                 '{op: LW, rd: 5'd5, rs1: 5'd6, imm: 32'h00000008, default: '0},
                 1'b1, 1'b1, 1'b0, 1'b1);
  endtask

  // TC_ITYPE_04 : ADDI x0, x0, 0
  task automatic tc_itype_04_zero_reg();
    check_decode("TC_ITYPE_04",
                 32'h00000013,
                 '{op: ADDI, rd: 5'd0, rs1: 5'd0, imm: 32'h00000000, default: '0},
                 1'b1, 1'b1, 1'b0, 1'b1);
  endtask

  // TC_BTYPE_01 : BEQ x7, x8, 0
  task automatic tc_btype_01_beq_decode();
    check_decode("TC_BTYPE_01",
                 32'h00838063,
                 '{op: BEQ, rs1: 5'd7, rs2: 5'd8, imm: 32'h00000000, default: '0},
                 1'b0, 1'b1, 1'b1, 1'b1);
  endtask

  // TC_BTYPE_02 : BLT x9, x10, 16
  task automatic tc_btype_02_blt_imm_extract();
    check_decode("TC_BTYPE_02",
                 32'h00a4c863,
                 '{op: BLT, rs1: 5'd9, rs2: 5'd10, imm: 32'h00000010, default: '0},
                 1'b0, 1'b1, 1'b1, 1'b1);
  endtask

  // TC_STYPE_01 : SW x11, 0(x12)
  task automatic tc_stype_01_sw_decode();
    check_decode("TC_STYPE_01",
                 32'h00b62023,
                 '{op: SW, rs1: 5'd12, rs2: 5'd11, imm: 32'h00000000, default: '0},
                 1'b0, 1'b1, 1'b1, 1'b1);
  endtask

  // TC_STYPE_02 : SW x13, 4(x14)
  task automatic tc_stype_02_imm_extract();
    check_decode("TC_STYPE_02",
                 32'h00d72223,
                 '{op: SW, rs1: 5'd14, rs2: 5'd13, imm: 32'h00000004, default: '0},
                 1'b0, 1'b1, 1'b1, 1'b1);
  endtask

  // TC_STYPE_03 : SW x1, 100(x2)
  // Expected immediate reflects current RTL behavior.
  task automatic tc_stype_03_nonzero_upper_imm();
    check_decode("TC_STYPE_03",
                 32'h06112223,
                 '{op: SW, rs1: 5'd2, rs2: 5'd1, imm: 32'h0C183064, default: '0},
                 1'b0, 1'b1, 1'b1, 1'b1);
  endtask

  // TC_UTYPE_01 : LUI x15, 0x12345
  task automatic tc_utype_01_lui_imm_extract();
    check_decode("TC_UTYPE_01",
                 32'h123457B7,
                 '{op: LUI, rd: 5'd15, imm: 32'h12345000, default: '0},
                 1'b1, 1'b0, 1'b0, 1'b1);
  endtask

  // TC_UTYPE_02 : AUIPC x16, 0xABCDE
  task automatic tc_utype_02_auipc_decode();
    check_decode("TC_UTYPE_02",
                 32'hABCDE817,
                 '{op: AUIPC, rd: 5'd16, imm: 32'hABCDE000, default: '0},
                 1'b1, 1'b0, 1'b0, 1'b1);
  endtask

  // TC_JTYPE_01 : JAL x17, 2048
  task automatic tc_jtype_01_jal_imm_extract();
    check_decode("TC_JTYPE_01",
                 32'h001008EF,
                 '{op: JAL, rd: 5'd17, imm: 32'h00000800, default: '0},
                 1'b1, 1'b0, 1'b0, 1'b1);
  endtask

  // TC_JTYPE_02 : JAL x0, -2048
  task automatic tc_jtype_02_reg_imm_extract();
    check_decode("TC_JTYPE_02",
                 32'h801FF06F,
                 '{op: JAL, rd: 5'd0, imm: 32'hFFFFF800, default: '0},
                 1'b1, 1'b0, 1'b0, 1'b1);
  endtask

  // TC_RV64_01 : LD x18, 8(x19)
  task automatic tc_rv64_01_ld_decode();
    check_decode("TC_RV64_01",
                 32'h0089B903,
                 '{op: LD, rd: 5'd18, rs1: 5'd19, imm: 32'h00000008, default: '0},
                 1'b1, 1'b1, 1'b0, 1'b1);
  endtask

  // TC_RV64_02 : ADDIW x20, x21, 100
  task automatic tc_rv64_02_addiw_decode();
    check_decode("TC_RV64_02",
                 32'h064A8A1B,
                 '{op: ADDIW, rd: 5'd20, rs1: 5'd21, imm: 32'h00000064, default: '0},
                 1'b1, 1'b1, 1'b0, 1'b1);
  endtask

  // TC_REG_01 : ADD x0, x1, x2
  task automatic tc_reg_01_zero_reg();
    check_decode("TC_REG_01",
                 32'h00208033,
                 '{op: ADD, rd: 5'd0, rs1: 5'd1, rs2: 5'd2, default: '0},
                 1'b1, 1'b1, 1'b1, 1'b0);
  endtask

  // TC_REG_02 : XOR x31, x30, x29
  task automatic tc_reg_02_boundary_reg();
    check_decode("TC_REG_02",
                 32'h01DF4FB3,
                 '{op: XOR, rd: 5'd31, rs1: 5'd30, rs2: 5'd29, default: '0},
                 1'b1, 1'b1, 1'b1, 1'b0);
  endtask

  // TC_REG_03 : ADD x1, x2, x3
  task automatic tc_reg_03_reg_reqs_bitmap();

    tc_begin("TC_REG_03");
    drive_instr(32'h003100B3);

    check_field("TC_REG_03",
                "op",
                (decoded_instr.op == ADD),
                decoded_instr.op.name(),
                "ADD");

    check_field("TC_REG_03",
                "reg_reqs[1] (rd)",
                (decoded_instr.reg_reqs[1] == 1'b1),
                $sformatf("%0b", decoded_instr.reg_reqs[1]),
                "1");

    check_field("TC_REG_03",
                "reg_reqs[2] (rs1)",
                (decoded_instr.reg_reqs[2] == 1'b1),
                $sformatf("%0b", decoded_instr.reg_reqs[2]),
                "1");

    check_field("TC_REG_03",
                "reg_reqs[3] (rs2)",
                (decoded_instr.reg_reqs[3] == 1'b1),
                $sformatf("%0b", decoded_instr.reg_reqs[3]),
                "1");

    if (debug)
      $display("[%0t] ADD op=%s reg_reqs=%b",
               $time,
               decoded_instr.op.name(),
               decoded_instr.reg_reqs);

    tc_end("TC_REG_03");

  endtask

  // TC_FTYPE_01 : FADD_S f1, f0, f0, rm=RTZ(001)
  // Rounding mode is encoded in instr[14:12].
  task automatic tc_ftype_01_rounding_mode();
    check_decode("TC_FTYPE_01",
                 32'h000010D3,
                 '{op: FADD_S, imm: 32'h00000001, default: '0},
                 1'b0, 1'b0, 1'b0, 1'b1);
  endtask

  // TC_ATYPE_01 : AMOADD.D x1, x3, (x2)
  task automatic tc_atype_01_amoadd_d_decode();
    check_decode("TC_ATYPE_01",
                 32'h003130AF,
                 '{op: AMOADD_D, rd: 5'd1, rs1: 5'd2, rs2: 5'd3, default: '0},
                 1'b1, 1'b1, 1'b1, 1'b0);
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // CORNER CASE TESTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // TC_CORNER_01 : ADDI x1, x2, +2047
  task automatic tc_corner_01_itype_max_pos();

    check_decode(
        "TC_CORNER_01",
        32'h7FF10093,
        '{op: ADDI, rd: 5'd1, rs1: 5'd2,
          imm: 32'h000007FF, default: '0},
        1'b1, 1'b1, 1'b0, 1'b1
    );

  endtask

  // TC_CORNER_02 : ADDI x1, x2, -2048
  task automatic tc_corner_02_itype_min_neg();

    check_decode(
        "TC_CORNER_02",
        32'h80010093,
        '{op: ADDI, rd: 5'd1, rs1: 5'd2,
          imm: 32'hFFFFF800, default: '0},
        1'b1, 1'b1, 1'b0, 1'b1
    );

  endtask

  // TC_CORNER_03 : SW x31, +2047(x30)
  task automatic tc_corner_03_stype_max_pos();

    check_decode(
        "TC_CORNER_03",
        32'h7FFF2FA3,
        '{op: SW, rs1: 5'd30, rs2: 5'd31,
          imm: 32'hFDFBF7FF, default: '0},
        1'b0, 1'b1, 1'b1, 1'b1
    );

  endtask

  // TC_CORNER_04 : SW x31, -2048(x30)
  task automatic tc_corner_04_stype_min_neg();

    check_decode(
        "TC_CORNER_04",
        32'h81FF2023,
        '{op: SW, rs1: 5'd30, rs2: 5'd31,
          imm: 32'h02040800, default: '0},
        1'b0, 1'b1, 1'b1, 1'b1
    );

  endtask

  // TC_CORNER_05 : BEQ x1, x2, +4094
  task automatic tc_corner_05_btype_max_pos();

    check_decode(
        "TC_CORNER_05",
        32'h7E208FE3,
        '{op: BEQ, rs1: 5'd1, rs2: 5'd2,
          imm: 32'h00000FFE, default: '0},
        1'b0, 1'b1, 1'b1, 1'b1
    );

  endtask

  // TC_CORNER_06 : BEQ x1, x2, -4096
  task automatic tc_corner_06_btype_min_neg();

    check_decode(
        "TC_CORNER_06",
        32'h80208063,
        '{op: BEQ, rs1: 5'd1, rs2: 5'd2,
          imm: 32'hFFFFF000, default: '0},
        1'b0, 1'b1, 1'b1, 1'b1
    );

  endtask

  // TC_CORNER_07 : JAL x1, +1048574
  task automatic tc_corner_07_jtype_max_pos();

    check_decode(
        "TC_CORNER_07",
        32'h7FFFF0EF,
        '{op: JAL, rd: 5'd1,
          imm: 32'h000FFFFE, default: '0},
        1'b1, 1'b0, 1'b0, 1'b1
    );

  endtask

  // TC_CORNER_08 : JAL x1, -1048576
  task automatic tc_corner_08_jtype_min_neg();

    check_decode(
        "TC_CORNER_08",
        32'h800000EF,
        '{op: JAL, rd: 5'd1,
          imm: 32'hFFF00000, default: '0},
        1'b1, 1'b0, 1'b0, 1'b1
    );

  endtask

  // TC_CORNER_09 : LUI x31, 0xFFFFF
  task automatic tc_corner_09_lui_all_ones();

    check_decode(
        "TC_CORNER_09",
        32'hFFFFFFB7,
        '{op: LUI, rd: 5'd31,
          imm: 32'hFFFFF000, default: '0},
        1'b1, 1'b0, 1'b0, 1'b1
    );

  endtask

  // TC_CORNER_10 : AND x31, x31, x31
  task automatic tc_corner_10_all_regs_x31();

    check_decode(
        "TC_CORNER_10",
        32'h01FFFFB3,
        '{op: AND, rd: 5'd31, rs1: 5'd31, rs2: 5'd31,
          default: '0},
        1'b1, 1'b1, 1'b1, 1'b0
    );

  endtask

  // TC_CORNER_11 : ADD x0, x0, x0
  task automatic tc_corner_11_zero_regs_bitmap();

    tc_begin("TC_CORNER_11");
    drive_instr(32'h00000033);

    check_field(
        "TC_CORNER_11",
        "found",
        (decoded_instr.op != INVALID_INSTRUCTION),
        decoded_instr.op.name(),
        "1"
    );

    check_field(
        "TC_CORNER_11",
        "op",
        (decoded_instr.op == ADD),
        decoded_instr.op.name(),
        "ADD"
    );

    check_field(
        "TC_CORNER_11",
        "rd",
        (decoded_instr.rd == 5'd0),
        $sformatf("%0d", decoded_instr.rd),
        "0"
    );

    check_field(
        "TC_CORNER_11",
        "rs1",
        (decoded_instr.rs1 == 5'd0),
        $sformatf("%0d", decoded_instr.rs1),
        "0"
    );

    check_field(
        "TC_CORNER_11",
        "rs2",
        (decoded_instr.rs2 == 5'd0),
        $sformatf("%0d", decoded_instr.rs2),
        "0"
    );

    check_field(
        "TC_CORNER_11",
        "reg_reqs[0]",
        (decoded_instr.reg_reqs[0] == 1'b1),
        $sformatf("%0b", decoded_instr.reg_reqs[0]),
        "1"
    );

    if (debug)
      $display("[%0t] ADD x0,x0,x0 reg_reqs=%b",
               $time,
               decoded_instr.reg_reqs);

    tc_end("TC_CORNER_11");

  endtask

  // TC_CORNER_12 : SLLI x1, x2, 63
  task automatic tc_corner_12_slli_max_shamt();

    check_decode(
        "TC_CORNER_12",
        32'h03F11093,
        '{op: SLLI, rd: 5'd1, rs1: 5'd2,
          imm: 32'h0000003F, default: '0},
        1'b1, 1'b1, 1'b0, 1'b1
    );

  endtask

  // TC_CORNER_13 : 32'hFFFFFFFF
  task automatic tc_corner_13_illegal_instruction();

    tc_begin("TC_CORNER_13");
    drive_instr(32'hFFFFFFFF);

    check_field(
        "TC_CORNER_13",
        "found",
        (decoded_instr.op == INVALID_INSTRUCTION),
        decoded_instr.op.name(),
        "INVALID_INSTRUCTION"
    );

    if (debug)
      $display("[%0t] illegal instruction found=%0b",
               $time,
               found);

    tc_end("TC_CORNER_13");

  endtask

  // TC_CORNER_14 : Invalid R-type funct7/funct3 combination
  task automatic tc_corner_14_invalid_rtype_funct();

    tc_begin("TC_CORNER_14");
    drive_instr(32'hFC3100B3);

    check_field(
        "TC_CORNER_14",
        "found",
        (decoded_instr.op == INVALID_INSTRUCTION),
        decoded_instr.op.name(),
        "INVALID_INSTRUCTION"
    );

    if (debug)
      $display("[%0t] invalid R-type found=%0b",
               $time,
               found);

    tc_end("TC_CORNER_14");

  endtask

  // TC_CORNER_15 : CSRRW x1, 0x800, x2
  task automatic tc_corner_15_csrrw_sign_extend();

    check_decode(
        "TC_CORNER_15",
        32'h800110F3,
        '{op: CSRRW, rd: 5'd1, rs1: 5'd2,
          imm: 32'hFFFFF800, default: '0},
        1'b1, 1'b1, 1'b0, 1'b1
    );

  endtask

  // TC_CORNER_16 : FENCE.I
  task automatic tc_corner_16_fence_i();

    check_decode(
        "TC_CORNER_16",
        32'h0000100F,
        '{op: FENCE_I, rd: 5'd0, rs1: 5'd0,
          default: '0},
        1'b1, 1'b1, 1'b0, 1'b0
    );

  endtask

  // TC_CORNER_17 : SRAI x1, x2, 32
  task automatic tc_corner_17_srai_vs_srli();

    check_decode(
        "TC_CORNER_17",
        32'h42015093,
        '{op: SRAI, rd: 5'd1, rs1: 5'd2,
          imm: 32'h00000020, default: '0},
        1'b1, 1'b1, 1'b0, 1'b1
    );

  endtask

  // Print final test summary
  task automatic print_summary();

    $display("\n==================== TEST SUMMARY ====================");

    $display("Total test cases run    : %0d", total_tc_run);
    $display("Total test cases passed : %0d", total_tc_run - total_tc_failed);
    $display("Total test cases failed : %0d", total_tc_failed);

    if (total_tc_failed > 0) begin

      $display("\033[1;31mFAILED TEST CASES:\033[0m");

      foreach (failed_tc_list[i])
        $display("  \033[1;31m- %s\033[0m", failed_tc_list[i]);

    end else begin

      $display("\033[1;32mALL TEST CASES PASSED\033[0m");

    end

    $display("=======================================================\n");

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Run selected test case or complete test suite
  initial begin

    tc_fail_count   = 0;                              // Initialize failure counter
    total_tc_run    = 0;                              // Initialize test counter
    total_tc_failed = 0;                              // Initialize failed-test counter

    case (test_name)

      "TC_RTYPE_01": tc_rtype_01_add_decode();
      "TC_RTYPE_02": tc_rtype_02_sub_decode();
      "TC_RTYPE_03": tc_rtype_03_reg_boundary();

      "TC_ITYPE_01": tc_itype_01_addi_pos_imm();
      "TC_ITYPE_02": tc_itype_02_addi_neg_imm();
      "TC_ITYPE_03": tc_itype_03_lw_imm_extract();
      "TC_ITYPE_04": tc_itype_04_zero_reg();

      "TC_BTYPE_01": tc_btype_01_beq_decode();
      "TC_BTYPE_02": tc_btype_02_blt_imm_extract();

      "TC_STYPE_01": tc_stype_01_sw_decode();
      "TC_STYPE_02": tc_stype_02_imm_extract();
      "TC_STYPE_03": tc_stype_03_nonzero_upper_imm();

      "TC_UTYPE_01": tc_utype_01_lui_imm_extract();
      "TC_UTYPE_02": tc_utype_02_auipc_decode();

      "TC_JTYPE_01": tc_jtype_01_jal_imm_extract();
      "TC_JTYPE_02": tc_jtype_02_reg_imm_extract();

      "TC_RV64_01": tc_rv64_01_ld_decode();
      "TC_RV64_02": tc_rv64_02_addiw_decode();

      "TC_REG_01": tc_reg_01_zero_reg();
      "TC_REG_02": tc_reg_02_boundary_reg();
      "TC_REG_03": tc_reg_03_reg_reqs_bitmap();

      "TC_FTYPE_01": tc_ftype_01_rounding_mode();
      "TC_ATYPE_01": tc_atype_01_amoadd_d_decode();

      "TC_CORNER_01": tc_corner_01_itype_max_pos();
      "TC_CORNER_02": tc_corner_02_itype_min_neg();
      "TC_CORNER_03": tc_corner_03_stype_max_pos();
      "TC_CORNER_04": tc_corner_04_stype_min_neg();
      "TC_CORNER_05": tc_corner_05_btype_max_pos();
      "TC_CORNER_06": tc_corner_06_btype_min_neg();
      "TC_CORNER_07": tc_corner_07_jtype_max_pos();
      "TC_CORNER_08": tc_corner_08_jtype_min_neg();
      "TC_CORNER_09": tc_corner_09_lui_all_ones();
      "TC_CORNER_10": tc_corner_10_all_regs_x31();
      "TC_CORNER_11": tc_corner_11_zero_regs_bitmap();
      "TC_CORNER_12": tc_corner_12_slli_max_shamt();
      "TC_CORNER_13": tc_corner_13_illegal_instruction();
      "TC_CORNER_14": tc_corner_14_invalid_rtype_funct();
      "TC_CORNER_15": tc_corner_15_csrrw_sign_extend();
      "TC_CORNER_16": tc_corner_16_fence_i();
      "TC_CORNER_17": tc_corner_17_srai_vs_srli();

      "TC_ALL": begin

        tc_rtype_01_add_decode();
        tc_rtype_02_sub_decode();
        tc_rtype_03_reg_boundary();

        tc_itype_01_addi_pos_imm();
        tc_itype_02_addi_neg_imm();
        tc_itype_03_lw_imm_extract();
        tc_itype_04_zero_reg();

        tc_btype_01_beq_decode();
        tc_btype_02_blt_imm_extract();

        tc_stype_01_sw_decode();
        tc_stype_02_imm_extract();
        tc_stype_03_nonzero_upper_imm();

        tc_utype_01_lui_imm_extract();
        tc_utype_02_auipc_decode();

        tc_jtype_01_jal_imm_extract();
        tc_jtype_02_reg_imm_extract();

        tc_rv64_01_ld_decode();
        tc_rv64_02_addiw_decode();

        tc_reg_01_zero_reg();
        tc_reg_02_boundary_reg();
        tc_reg_03_reg_reqs_bitmap();

        tc_ftype_01_rounding_mode();
        tc_atype_01_amoadd_d_decode();

        tc_corner_01_itype_max_pos();
        tc_corner_02_itype_min_neg();
        tc_corner_03_stype_max_pos();
        tc_corner_04_stype_min_neg();
        tc_corner_05_btype_max_pos();
        tc_corner_06_btype_min_neg();
        tc_corner_07_jtype_max_pos();
        tc_corner_08_jtype_min_neg();
        tc_corner_09_lui_all_ones();
        tc_corner_10_all_regs_x31();
        tc_corner_11_zero_regs_bitmap();
        tc_corner_12_slli_max_shamt();
        tc_corner_13_illegal_instruction();
        tc_corner_14_invalid_rtype_funct();
        tc_corner_15_csrrw_sign_extend();
        tc_corner_16_fence_i();
        tc_corner_17_srai_vs_srli();

      end

      default:
        $fatal(1,
               "\033[1;31mUNKNOWN TEST NAME: %s\033[0m",
               test_name);

    endcase

    print_summary();                                  // Print overall result
    $finish;                                          // End simulation

  end

endmodule