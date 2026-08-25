/*

| TEST CASE   | DATE       | AUTHOR             | DESCRIPTION                                                 |
|-------------|------------|--------------------|--------------------------------------------------------------|
| TC_RTYPE_01 | 2026-08-25 | Shykul Islam Siam  | ADD instruction decoding (R-type format)                    |
| TC_RTYPE_02 | 2026-08-25 | Shykul Islam Siam  | SUB instruction decoding (R-type format)                    |
| TC_RTYPE_03 | 2026-08-25 | Shykul Islam Siam  | Register extraction for R-type instructions                 |
| TC_ITYPE_01 | 2026-08-25 | Shykul Islam Siam  | ADDI instruction with positive immediate (I-type format)    |
| TC_ITYPE_02 | 2026-08-25 | Shykul Islam Siam  | ADDI instruction with negative immediate (sign extension)   |
| TC_ITYPE_03 | 2026-08-25 | Shykul Islam Siam  | LW instruction immediate extraction (I-type format)         |
| TC_ITYPE_04 | 2026-08-25 | Shykul Islam Siam  | Register extraction for I-type instructions                 |
| TC_BTYPE_01 | 2026-08-25 | Shykul Islam Siam  | BEQ instruction decoding (B-type format)                    |
| TC_BTYPE_02 | 2026-08-25 | Shykul Islam Siam  | BLT instruction branch immediate extraction                 |
| TC_STYPE_01 | 2026-08-25 | Shykul Islam Siam  | SW instruction decoding (S-type format)                     |
| TC_STYPE_02 | 2026-08-25 | Shykul Islam Siam  | S-type immediate extraction for store operations             |
| TC_STYPE_03 | 2026-08-25 | Shykul Islam Siam  | S-type store with non-zero imm[11:5] (sign-extension check)  |
| TC_UTYPE_01 | 2026-08-25 | Shykul Islam Siam  | LUI instruction upper immediate extraction (U-type format)   |
| TC_UTYPE_02 | 2026-08-25 | Shykul Islam Siam  | AUIPC instruction decoding (U-type format)                  |
| TC_JTYPE_01 | 2026-08-25 | Shykul Islam Siam  | JAL instruction jump immediate extraction (J-type format)    |
| TC_JTYPE_02 | 2026-08-25 | Shykul Islam Siam  | J-type register and immediate extraction                    |
| TC_RV64_01  | 2026-08-25 | Shykul Islam Siam  | LD instruction (RV64I 64-bit load)                           |
| TC_RV64_02  | 2026-08-25 | Shykul Islam Siam  | ADDIW instruction (RV64I 32-bit arithmetic)                 |
| TC_REG_01   | 2026-08-25 | Shykul Islam Siam  | Zero register (x0) handling in register extraction           |
| TC_REG_02   | 2026-08-25 | Shykul Islam Siam  | Boundary register (x31) access validation                   |
| TC_REG_03   | 2026-08-25 | Shykul Islam Siam  | Register requirements bitmap generation                     |
| TC_FTYPE_01 | 2026-08-25 | Shykul Islam Siam  | FADD_S rounding-mode field extraction                        |
| TC_ATYPE_01 | 2026-08-25 | Shykul Islam Siam  | AMOADD.D instruction decoding (RV64A)                        |

| REVISION | DATE       | AUTHOR             | DESCRIPTION                                                  |
|----------|------------|--------------------|----------------------------------------------------------------|
| 0.1      | 2026-08-25 | Shykul Islam Siam  | Initial testbench version                                    |
| 1.0      | 2026-08-25 | Shykul Islam Siam  | Stable release                                                |
| 1.1      | 2026-08-25 | Shykul Islam Siam  | Added per-test-case pass/fail reporting with field-level diag |
| 1.2      | 2026-08-25 | Shykul Islam Siam  | Added TC_STYPE_03, TC_FTYPE_01, TC_ATYPE_01 for extra coverage |

Author : Shykul Islam Siam (shykulislam32@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

// adn_riscv_pkg.sv contains a package...endpackage block, which is only
// legal at file/compilation-unit scope, not nested inside a module -
// so this include (and the matching import) must sit outside the module.
`include "adn_riscv_pkg.sv"
import adn_riscv_pkg::*;

module adn_riscv_instr_decoder_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // these two stay inside the module: adn_common_tb_headers.sv declares an
  // initial block (only legal inside a module), and typedef.svh's `ADN_RISCV_T
  // macro is invoked below using module-local localparams.
  `include "vip/adn_common_tb_headers.sv"  // test_name, test_count, debug, note_case()
  `include "adn_riscv/typedef.svh"         // adn_riscv typedef macros (adn_riscv_decoded_instr_t)

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  localparam int XLEN           = 64;                   // machine word width
  localparam int CLOG2_NUM_REGS = 5;                     // register-index width (2^5 = 32 registers)
  localparam int NUM_REGS       = 2 ** CLOG2_NUM_REGS;   // architectural register file size

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  `ADN_RISCV_T(adn_riscv, CLOG2_NUM_REGS, XLEN)  // defines adn_riscv_decoded_instr_t

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  logic                      [31:0] encoded_instr;  // raw instruction word into the DUT
  adn_riscv_decoded_instr_t         decoded_instr;   // decoded instruction fields from the DUT
  logic                             found;           // asserted when the encoding matched a known instruction

  // pass/fail bookkeeping so we can report exactly which TC_* failed, and on which field
  int  tc_fail_count;                 // number of mismatched fields seen inside the current test case
  int  total_tc_run;                  // number of test cases executed this run
  int  total_tc_failed;               // number of test cases that had >=1 mismatch this run
  string failed_tc_list[$];           // queue of test case names that failed, for the final summary

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  adn_riscv_instr_decoder #(
      .XLEN            (XLEN),                     // machine word width
      .EN_ZIFENCE_I    (1),                         // enable Zifencei extension
      .EN_ZICSR        (1),                         // enable Zicsr extension
      .EN_MATH         (1),                         // enable M extension
      .EN_ATOMICS      (1),                         // enable A extension
      .EN_FLOAT        (1),                         // enable F extension
      .EN_DOUBLE       (1),                         // enable D extension
      .decoded_instr_t (adn_riscv_decoded_instr_t)  // decoded instruction struct type
  ) dut (
      .encoded_instr_i(encoded_instr),  // instruction word in
      .decoded_instr_o(decoded_instr),  // decoded fields out
      .found_o        (found)           // match flag out
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // drive an instruction word and let the combinational decode settle
  task automatic drive_instr(input logic [31:0] instr);
    encoded_instr = instr;  // apply the encoding
    #1;                     // allow combinational logic to settle
  endtask

  // call at the top of every tc_* task to reset the per-test-case failure counter
  task automatic tc_begin(input string tc_name);
    tc_fail_count = 0;
    total_tc_run++;
    if (debug) $display("[%0t] ---- START %s ----", $time, tc_name);
  endtask

  // call at the bottom of every tc_* task; prints a clear PASS/FAIL line naming the test case
  task automatic tc_end(input string tc_name);
    if (tc_fail_count == 0) begin
      $display("\033[1;32m[PASS] %s\033[0m", tc_name);
    end else begin
      total_tc_failed++;
      failed_tc_list.push_back(tc_name);
      $display("\033[1;31m[FAIL] %s (%0d mismatched field%s)\033[0m", tc_name, tc_fail_count,
                (tc_fail_count == 1) ? "" : "s");
    end
  endtask

  // compare one field, bump note_case (existing scoreboard) and tc_fail_count (per-TC diagnostics),
  // and print exactly which field/tc mismatched and by how much
  task automatic check_field(input string tc_name, input string field_name, input bit match,
                              input string got, input string exp);
    note_case(match);  // preserve existing global pass/fail counting mechanism
    if (!match) begin
      tc_fail_count++;
      $display("\033[1;31m[FAIL] %s : %s mismatch -> got=%s exp=%s\033[0m", tc_name, field_name, got,
                exp);
    end
  endtask

  // drive an instruction and check its decoded fields against an expected partial struct;
  // chk_rd/chk_rs1/chk_rs2/chk_imm select which fields this instruction format actually carries
  task automatic check_decode(input string tc_name, input logic [31:0] instr,
                               input adn_riscv_decoded_instr_t exp, input bit chk_rd,
                               input bit chk_rs1, input bit chk_rs2, input bit chk_imm);
    tc_begin(tc_name);
    drive_instr(instr);  // apply encoding, let decode settle

    check_field(tc_name, "op", (decoded_instr.op == exp.op), decoded_instr.op.name(), exp.op.name());
    if (chk_rd)
      check_field(tc_name, "rd", (decoded_instr.rd == exp.rd), $sformatf("%0d", decoded_instr.rd),
                  $sformatf("%0d", exp.rd));
    if (chk_rs1)
      check_field(tc_name, "rs1", (decoded_instr.rs1 == exp.rs1), $sformatf("%0d", decoded_instr.rs1),
                  $sformatf("%0d", exp.rs1));
    if (chk_rs2)
      check_field(tc_name, "rs2", (decoded_instr.rs2 == exp.rs2), $sformatf("%0d", decoded_instr.rs2),
                  $sformatf("%0d", exp.rs2));
    if (chk_imm)
      check_field(tc_name, "imm", (decoded_instr.imm == exp.imm), $sformatf("0x%0h", decoded_instr.imm),
                  $sformatf("0x%0h", exp.imm));

    if (debug)
      $display("[%0t] op=%s rd=%0d rs1=%0d rs2=%0d imm=%0h", $time, decoded_instr.op.name(),
                decoded_instr.rd, decoded_instr.rs1, decoded_instr.rs2, decoded_instr.imm);

    tc_end(tc_name);
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST CASES
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_RTYPE_01 : ADD x1, x2, x3
  task automatic tc_rtype_01_add_decode();
    check_decode("TC_RTYPE_01", 32'h003100B3, '{op: ADD, rd: 5'd1, rs1: 5'd2, rs2: 5'd3, default: '0},
                 1'b1, 1'b1, 1'b1, 1'b0);
  endtask
  // TC_RTYPE_02 : SUB x4, x5, x6
  task automatic tc_rtype_02_sub_decode();
    check_decode("TC_RTYPE_02", 32'h40628233, '{op: SUB, rd: 5'd4, rs1: 5'd5, rs2: 5'd6, default: '0},
                 1'b1, 1'b1, 1'b1, 1'b0);
  endtask
  // TC_RTYPE_03 : AND x31, x31, x31 - register extraction at the boundary index
  task automatic tc_rtype_03_reg_boundary();
    check_decode("TC_RTYPE_03", 32'h01FFFFB3, '{op: AND, rd: 5'd31, rs1: 5'd31, rs2: 5'd31, default: '0},
                 1'b1, 1'b1, 1'b1, 1'b0);
  endtask
  // TC_ITYPE_01 : ADDI x1, x2, 10 - positive immediate
  task automatic tc_itype_01_addi_pos_imm();
    check_decode("TC_ITYPE_01", 32'h00A10093, '{op: ADDI, rd: 5'd1, rs1: 5'd2, imm: 32'h0000000A, default: '0},
                 1'b1, 1'b1, 1'b0, 1'b1);
  endtask
  // TC_ITYPE_02 : ADDI x3, x4, -5 - negative immediate, sign extension
  task automatic tc_itype_02_addi_neg_imm();
    check_decode("TC_ITYPE_02", 32'hFFB20193, '{op: ADDI, rd: 5'd3, rs1: 5'd4, imm: 32'hFFFFFFFB, default: '0},
                 1'b1, 1'b1, 1'b0, 1'b1);
  endtask
  // TC_ITYPE_03 : LW x5, 8(x6) - immediate extraction for loads
  task automatic tc_itype_03_lw_imm_extract();
    check_decode("TC_ITYPE_03", 32'h00832283, '{op: LW, rd: 5'd5, rs1: 5'd6, imm: 32'h00000008, default: '0},
                 1'b1, 1'b1, 1'b0, 1'b1);
  endtask
  // TC_ITYPE_04 : ADDI x0, x0, 0 - register extraction, zero register
  task automatic tc_itype_04_zero_reg();
    check_decode("TC_ITYPE_04", 32'h00000013, '{op: ADDI, rd: 5'd0, rs1: 5'd0, imm: 32'h00000000, default: '0},
                 1'b1, 1'b1, 1'b0, 1'b1);
  endtask
  // TC_BTYPE_01 : BEQ x7, x8, 0
  task automatic tc_btype_01_beq_decode();
    check_decode("TC_BTYPE_01", 32'h00838063, '{op: BEQ, rs1: 5'd7, rs2: 5'd8, imm: 32'h00000000, default: '0},
                 1'b0, 1'b1, 1'b1, 1'b1);
  endtask
  // TC_BTYPE_02 : BLT x9, x10, 16 - branch immediate extraction
  task automatic tc_btype_02_blt_imm_extract();
    check_decode("TC_BTYPE_02", 32'h00a4c863, '{op: BLT, rs1: 5'd9, rs2: 5'd10, imm: 32'h00000010, default: '0},
                 1'b0, 1'b1, 1'b1, 1'b1);
  endtask
  // TC_STYPE_01 : SW x11, 0(x12)
  task automatic tc_stype_01_sw_decode();
    check_decode("TC_STYPE_01", 32'h00b62023, '{op: SW, rs1: 5'd12, rs2: 5'd11, imm: 32'h00000000, default: '0},
                 1'b0, 1'b1, 1'b1, 1'b1);
  endtask
  // TC_STYPE_02 : SW x13, 4(x14) - immediate extraction for stores
  task automatic tc_stype_02_imm_extract();
    check_decode("TC_STYPE_02", 32'h00d72223, '{op: SW, rs1: 5'd14, rs2: 5'd13, imm: 32'h00000004, default: '0},
                 1'b0, 1'b1, 1'b1, 1'b1);
  endtask
  // TC_STYPE_03 : SW x1, 100(x2) - non-zero imm[11:5] pattern (0b0000011).
  // Verifies simm[31:12] sign-extension replicates instr[31] (the true sign bit),
  // not the imm[11:5]/funct7 field itself. Expected imm = 100 = 0x64.
  task automatic tc_stype_03_nonzero_upper_imm();
    check_decode("TC_STYPE_03", 32'h06112223, '{op: SW, rs1: 5'd2, rs2: 5'd1, imm: 32'h00000064, default: '0},
                 1'b0, 1'b1, 1'b1, 1'b1);
  endtask
  // TC_UTYPE_01 : LUI x15, 0x12345 - upper immediate extraction
  task automatic tc_utype_01_lui_imm_extract();
    check_decode("TC_UTYPE_01", 32'h123457B7, '{op: LUI, rd: 5'd15, imm: 32'h12345000, default: '0},
                 1'b1, 1'b0, 1'b0, 1'b1);
  endtask
  // TC_UTYPE_02 : AUIPC x16, 0xABCDE
  task automatic tc_utype_02_auipc_decode();
    check_decode("TC_UTYPE_02", 32'hABCDE817, '{op: AUIPC, rd: 5'd16, imm: 32'hABCDE000, default: '0},
                 1'b1, 1'b0, 1'b0, 1'b1);
  endtask
  // TC_JTYPE_01 : JAL x17, 2048 - jump immediate extraction
  task automatic tc_jtype_01_jal_imm_extract();
    check_decode("TC_JTYPE_01", 32'h001008EF, '{op: JAL, rd: 5'd17, imm: 32'h00000800, default: '0},
                 1'b1, 1'b0, 1'b0, 1'b1);
  endtask
  // TC_JTYPE_02 : JAL x0, -2048 - register and immediate extraction
  task automatic tc_jtype_02_reg_imm_extract();
    check_decode("TC_JTYPE_02", 32'h801FF06F, '{op: JAL, rd: 5'd0, imm: 32'hFFFFF800, default: '0},
                 1'b1, 1'b0, 1'b0, 1'b1);
  endtask
  // TC_RV64_01 : LD x18, 8(x19) - RV64I 64-bit load
  task automatic tc_rv64_01_ld_decode();
    check_decode("TC_RV64_01", 32'h0089B903, '{op: LD, rd: 5'd18, rs1: 5'd19, imm: 32'h00000008, default: '0},
                 1'b1, 1'b1, 1'b0, 1'b1);
  endtask
  // TC_RV64_02 : ADDIW x20, x21, 100 - RV64I 32-bit arithmetic
  task automatic tc_rv64_02_addiw_decode();
    check_decode("TC_RV64_02", 32'h064A8A1B, '{op: ADDIW, rd: 5'd20, rs1: 5'd21, imm: 32'h00000064, default: '0},
                 1'b1, 1'b1, 1'b0, 1'b1);
  endtask
  // TC_REG_01 : ADD x0, x1, x2 - zero register (x0) handling
  task automatic tc_reg_01_zero_reg();
    check_decode("TC_REG_01", 32'h00208033, '{op: ADD, rd: 5'd0, rs1: 5'd1, rs2: 5'd2, default: '0},
                 1'b1, 1'b1, 1'b1, 1'b0);
  endtask
  // TC_REG_02 : XOR x31, x30, x29 - boundary register access
  task automatic tc_reg_02_boundary_reg();
    check_decode("TC_REG_02", 32'h01DF4FB3, '{op: XOR, rd: 5'd31, rs1: 5'd30, rs2: 5'd29, default: '0},
                 1'b1, 1'b1, 1'b1, 1'b0);
  endtask
  // TC_REG_03 : ADD x1, x2, x3 - register requirements bitmap generation
  task automatic tc_reg_03_reg_reqs_bitmap();
    tc_begin("TC_REG_03");
    drive_instr(32'h003100B3);
    check_field("TC_REG_03", "op", (decoded_instr.op == ADD), decoded_instr.op.name(), "ADD");
    check_field("TC_REG_03", "reg_reqs[1] (rd)", (decoded_instr.reg_reqs[1] == 1'b1),
                $sformatf("%0b", decoded_instr.reg_reqs[1]), "1");
    check_field("TC_REG_03", "reg_reqs[2] (rs1)", (decoded_instr.reg_reqs[2] == 1'b1),
                $sformatf("%0b", decoded_instr.reg_reqs[2]), "1");
    check_field("TC_REG_03", "reg_reqs[3] (rs2)", (decoded_instr.reg_reqs[3] == 1'b1),
                $sformatf("%0b", decoded_instr.reg_reqs[3]), "1");
    if (debug)
      $display("[%0t] ADD op=%s reg_reqs=%b", $time, decoded_instr.op.name(), decoded_instr.reg_reqs);
    tc_end("TC_REG_03");
  endtask
  // TC_FTYPE_01 : FADD_S f1, f0, f0, rm=RTZ(001).
  // Verifies rimm is extracted from the true rm field at instr[14:12], not
  // from instr[25]/instr[26]. FADD_S forces funct7=0000000, so this vector
  // isolates the rm field cleanly. Expected imm = 3'b001 = 0x1.
  task automatic tc_ftype_01_rounding_mode();
    check_decode("TC_FTYPE_01", 32'h000010D3, '{op: FADD_S, imm: 32'h00000001, default: '0},
                 1'b0, 1'b0, 1'b0, 1'b1);
  endtask
  // TC_ATYPE_01 : AMOADD.D x1, x3, (x2).
  // Verifies RV64A (doubleword atomics) decode correctly when XLEN=64, matching
  // the XLEN>32 gating convention used by the other RV64 extension blocks
  // (RV64I/RV64M/RV64F/RV64D).
  task automatic tc_atype_01_amoadd_d_decode();
    check_decode("TC_ATYPE_01", 32'h003130AF, '{op: AMOADD_D, rd: 5'd1, rs1: 5'd2, rs2: 5'd3, default: '0},
                 1'b1, 1'b1, 1'b1, 1'b0);
  endtask

  // prints a final roll-up naming every test case that failed, so failures are never buried in a log
  task automatic print_summary();
    $display("\n==================== TEST SUMMARY ====================");
    $display("Total test cases run    : %0d", total_tc_run);
    $display("Total test cases passed : %0d", total_tc_run - total_tc_failed);
    $display("Total test cases failed : %0d", total_tc_failed);
    if (total_tc_failed > 0) begin
      $display("\033[1;31mFAILED TEST CASES:\033[0m");
      foreach (failed_tc_list[i]) $display("  \033[1;31m- %s\033[0m", failed_tc_list[i]);
    end else begin
      $display("\033[1;32mALL TEST CASES PASSED\033[0m");
    end
    $display("=======================================================\n");
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Runs the test selected via the common +test_name plusarg;
  // TC_ALL runs every test
  initial begin
    tc_fail_count   = 0;
    total_tc_run    = 0;
    total_tc_failed = 0;

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
      end

      default: $fatal(1, "\033[1;31mUNKNOWN TEST NAME: %s\033[0m", test_name);

    endcase

    print_summary();
    $finish;
  end

endmodule  // make simulate TOP=adn_riscv_instr_decoder_tb TN=TC_ALL