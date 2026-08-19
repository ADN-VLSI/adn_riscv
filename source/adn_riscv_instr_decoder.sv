/*

### Purpose
This module serves as the instruction decoder for the ADN-RISC-V processor core. It takes a 32-bit encoded instruction as input and decodes it into a structured format (`decoded_instr_t`), identifying the operation type and extracting relevant immediate values and register indices based on the RISC-V ISA specifications.

### Use Case
The `adn_riscv_instr_decoder` is a critical component in the instruction fetch/decode stage of the ADN-RISC-V pipeline. Its primary responsibilities include:
- **Instruction Parsing**: Translating raw 32-bit binary instructions into a machine-readable `decoded_instr_t` struct.
- **Immediate Extraction**: Calculating and sign-extending immediate values for various instruction formats (I, S, B, U, J types).
- **Control Signal Generation**: Identifying the specific operation (e.g., ADD, LW, BEQ) to drive downstream execution units.
- **ISA Flexibility**: Supporting optional RISC-V extensions (Zifencei, Zicsr, Math/M-extension, Atomics/A-extension, and Floating Point/F & D extensions) via parameter-driven logic.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-18 | Foez Ahmed | Initial version                                        |
| 1.0      | 2026-08-18 | Foez Ahmed | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

`include "adn_riscv_pkg.sv"

module adn_riscv_instr_decoder
  import adn_riscv_pkg::*;
#(
    parameter int XLEN         = 64, // Data path width
    parameter bit EN_ZIFENCE_I = 1,  // Enable Zifencei extension
    parameter bit EN_ZICSR     = 1,  // Enable Zicsr extension
    parameter bit EN_MATH      = 1,  // Enable M-extension
    parameter bit EN_ATOMICS   = 1,  // Enable A-extension
    parameter bit EN_FLOAT     = 1,  // Enable F-extension
    parameter bit EN_DOUBLE    = 1   // Enable D-extension
) (
    input  logic           [31:0] encoded_instr_i, // Raw 32-bit instruction
    output decoded_instr_t        decoded_instr_o, // Decoded instruction structure
    output logic                  found_o          // Valid instruction detected
);

 logic [31:0] aimm; // SHIFT AMOUNT
 logic [31:0] bimm; // BTYPE INSTRUCTION IMMEDIATE
 logic [31:0] cimm; // CSR INSTRUCTION IMMEDIATE
 logic [31:0] iimm; // ITYPE INSTRUCTION IMMEDIATE
 logic [31:0] jimm; // JTYPE INSTRUCTION IMMEDIATE
 logic [31:0] rimm; // FLOATING ROUND MODE IMMEDIATE
 logic [31:0] simm; // RTYPE INSTRUCTION IMMEDIATE
 logic [31:0] timm; // ATOMICS IMMEDIATE
 logic [31:0] uimm; // UTYPE INSTRUCTION IMMEDIATE

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb aimm[5:0]   = encoded_instr_i[25:20];
  always_comb aimm[31:6]  = '0;

  always_comb bimm[0]     = '0;
  always_comb bimm[4:1]   = encoded_instr_i[11:8];
  always_comb bimm[10:5]  = encoded_instr_i[30:25];
  always_comb bimm[11]    = encoded_instr_i[7];
  always_comb bimm[12]    = encoded_instr_i[31];
  always_comb bimm[31:13] = {19{encoded_instr_i[31]}};

  always_comb cimm[11:0]  = encoded_instr_i[31:20];
  always_comb cimm[16:12] = encoded_instr_i[19:15];
  always_comb cimm[31:17] = '0;

  always_comb iimm[11:0]  = encoded_instr_i[31:20];
  always_comb iimm[31:12] = {20{encoded_instr_i[31]}};

  always_comb jimm[0]     = '0;
  always_comb jimm[10:1]  = encoded_instr_i[30:21];
  always_comb jimm[19:12] = encoded_instr_i[19:12];
  always_comb jimm[11]    = encoded_instr_i[20];
  always_comb jimm[20]    = encoded_instr_i[31];
  always_comb jimm[31:21] = {11{encoded_instr_i[31]}};

  always_comb rimm[2:0]   = encoded_instr_i[25:25];
  always_comb rimm[31:3]  = encoded_instr_i[26:26];

  always_comb simm[4:0]   = encoded_instr_i[11:7];
  always_comb simm[11:5]  = encoded_instr_i[31:25];
  always_comb simm[31:12] = {20{encoded_instr_i[31:25]}};

  always_comb timm[0]     = encoded_instr_i[25:25];
  always_comb timm[1]     = encoded_instr_i[26:26];
  always_comb timm[31:2]  = encoded_instr_i[26:26];

  always_comb uimm[11:0]  = '0;
  always_comb uimm[31:12] = encoded_instr_i[31:12];

  always_comb decoded_instr_o.rd = encoded_instr_i[11:7];
  always_comb decoded_instr_o.rs1 = encoded_instr_i[19:15];
  always_comb decoded_instr_o.rs2 = encoded_instr_i[24:20];
  always_comb decoded_instr_o.rs3 = encoded_instr_i[31:27];

  always_comb begin
    decoded_instr_o = '0;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // RV32I
    ////////////////////////////////////////////////////////////////////////////////////////////////

    if ((encoded_instr_i & 'b00000000000000000000000001111111) == 'b00000000000000000000000000110111) begin
      decoded_instr_o.op = LUI;
      decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000000000001111111) == 'b00000000000000000000000000010111) begin
      decoded_instr_o.op = AUIPC;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000000000001111111) == 'b00000000000000000000000001101111) begin
      decoded_instr_o.op = JAL;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000000000001100111) begin
      decoded_instr_o.op = JALR;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000000000001100011) begin
      decoded_instr_o.op = BEQ;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000001000001100011) begin
      decoded_instr_o.op = BNE;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000100000001100011) begin
      decoded_instr_o.op = BLT;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000101000001100011) begin
      decoded_instr_o.op = BGE;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000110000001100011) begin
      decoded_instr_o.op = BLTU;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000111000001100011) begin
      decoded_instr_o.op = BGEU;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000000000000000011) begin
      decoded_instr_o.op = LB;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000001000000000011) begin
      decoded_instr_o.op = LH;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000010000000000011) begin
      decoded_instr_o.op = LW;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000100000000000011) begin
      decoded_instr_o.op = LBU;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000101000000000011) begin
      decoded_instr_o.op = LHU;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000000000000100011) begin
      decoded_instr_o.op = SB;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000001000000100011) begin
      decoded_instr_o.op = SH;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000010000000100011) begin
      decoded_instr_o.op = SW;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000000000000010011) begin
      decoded_instr_o.op = ADDI;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000010000000010011) begin
      decoded_instr_o.op = SLTI;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000011000000010011) begin
      decoded_instr_o.op = SLTIU;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000100000000010011) begin
      decoded_instr_o.op = XORI;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000110000000010011) begin
      decoded_instr_o.op = ORI;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000111000000010011) begin
      decoded_instr_o.op = ANDI;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b11111100000000000111000001111111) == 'b00000000000000000001000000010011) begin
      decoded_instr_o.op = SLLI;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b11111100000000000111000001111111) == 'b00000000000000000101000000010011) begin
      decoded_instr_o.op = SRLI;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b11111100000000000111000001111111) == 'b01000000000000000101000000010011) begin
      decoded_instr_o.op = SRAI;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000000000000110011) begin
      decoded_instr_o.op = ADD;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b01000000000000000000000000110011) begin
      decoded_instr_o.op = SUB;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000001000000110011) begin
      decoded_instr_o.op = SLL;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000010000000110011) begin
      decoded_instr_o.op = SLT;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000011000000110011) begin
      decoded_instr_o.op = SLTU;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000100000000110011) begin
      decoded_instr_o.op = XOR;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000101000000110011) begin
      decoded_instr_o.op = SRL;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b01000000000000000101000000110011) begin
      decoded_instr_o.op = SRA;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000110000000110011) begin
      decoded_instr_o.op = OR;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000111000000110011) begin
      decoded_instr_o.op = AND;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000000000000001111) begin
      decoded_instr_o.op = FENCE;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b11111111111111111111111111111111) == 'b00000000000000000000000001110011) begin
      decoded_instr_o.op = ECALL;  // decoded_instr_o.imm = uimm;
    end

    if ((encoded_instr_i & 'b11111111111111111111111111111111) == 'b00000000000100000000000001110011) begin
      decoded_instr_o.op = EBREAK;  // decoded_instr_o.imm = uimm;
    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // RV64I
    ////////////////////////////////////////////////////////////////////////////////////////////////

    if (XLEN > 32) begin

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000110000000000011) begin
        decoded_instr_o.op = LWU;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000011000000000011) begin
        decoded_instr_o.op = LD;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000011000000100011) begin
        decoded_instr_o.op = SD;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000000000000011011) begin
        decoded_instr_o.op = ADDIW;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000001000000011011) begin
        decoded_instr_o.op = SLLIW;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000101000000011011) begin
        decoded_instr_o.op = SRLIW;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b01000000000000000101000000011011) begin
        decoded_instr_o.op = SRAIW;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000000000000111011) begin
        decoded_instr_o.op = ADDW;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b01000000000000000000000000111011) begin
        decoded_instr_o.op = SUBW;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000001000000111011) begin
        decoded_instr_o.op = SLLW;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000101000000111011) begin
        decoded_instr_o.op = SRLW;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b01000000000000000101000000111011) begin
        decoded_instr_o.op = SRAW;  // decoded_instr_o.imm = uimm;
      end

    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // Zifencei
    ////////////////////////////////////////////////////////////////////////////////////////////////

    if (EN_ZIFENCE_I) begin
      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000001000000001111) begin
        decoded_instr_o.op = FENCE_I;  // decoded_instr_o.imm = uimm;
      end
    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // Zicsr
    ////////////////////////////////////////////////////////////////////////////////////////////////

    if (EN_ZICSR) begin

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000001000001110011) begin
        decoded_instr_o.op = CSRRW;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000010000001110011) begin
        decoded_instr_o.op = CSRRS;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000011000001110011) begin
        decoded_instr_o.op = CSRRC;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000101000001110011) begin
        decoded_instr_o.op = CSRRWI;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000110000001110011) begin
        decoded_instr_o.op = CSRRSI;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000111000001110011) begin
        decoded_instr_o.op = CSRRCI;  // decoded_instr_o.imm = uimm;
      end

    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // RV32M
    ////////////////////////////////////////////////////////////////////////////////////////////////

    if (EN_MATH) begin

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000000000000110011) begin
        decoded_instr_o.op = MUL;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000001000000110011) begin
        decoded_instr_o.op = MULH;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000010000000110011) begin
        decoded_instr_o.op = MULHSU;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000011000000110011) begin
        decoded_instr_o.op = MULHU;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000100000000110011) begin
        decoded_instr_o.op = DIV;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000101000000110011) begin
        decoded_instr_o.op = DIVU;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000110000000110011) begin
        decoded_instr_o.op = REM;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000111000000110011) begin
        decoded_instr_o.op = REMU;  // decoded_instr_o.imm = uimm;
      end

      ////////////////////////////////////////////////////////////////////////////////////////////////
      // RV64M
      ////////////////////////////////////////////////////////////////////////////////////////////////

      if (XLEN > 32) begin

        if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000000000000111011) begin
          decoded_instr_o.op = MULW;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000100000000111011) begin
          decoded_instr_o.op = DIVW;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000101000000111011) begin
          decoded_instr_o.op = DIVUW;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000110000000111011) begin
          decoded_instr_o.op = REMW;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000111000000111011) begin
          decoded_instr_o.op = REMUW;  // decoded_instr_o.imm = uimm;
        end

      end

    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // RV32A
    ////////////////////////////////////////////////////////////////////////////////////////////////

    if (EN_ATOMICS) begin

      if ((encoded_instr_i & 'b11111001111100000111000001111111) == 'b00010000000000000010000000101111) begin
        decoded_instr_o.op = LR_W;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b00011000000000000010000000101111) begin
        decoded_instr_o.op = SC_W;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b00001000000000000010000000101111) begin
        decoded_instr_o.op = AMOSWAP_W;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b00000000000000000010000000101111) begin
        decoded_instr_o.op = AMOADD_W;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b00100000000000000010000000101111) begin
        decoded_instr_o.op = AMOXOR_W;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b01100000000000000010000000101111) begin
        decoded_instr_o.op = AMOAND_W;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b01000000000000000010000000101111) begin
        decoded_instr_o.op = AMOOR_W;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b10000000000000000010000000101111) begin
        decoded_instr_o.op = AMOMIN_W;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b10100000000000000010000000101111) begin
        decoded_instr_o.op = AMOMAX_W;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b11000000000000000010000000101111) begin
        decoded_instr_o.op = AMOMINU_W;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b11100000000000000010000000101111) begin
        decoded_instr_o.op = AMOMAXU_W;  // decoded_instr_o.imm = uimm;
      end

      ////////////////////////////////////////////////////////////////////////////////////////////////
      // RV64A
      ////////////////////////////////////////////////////////////////////////////////////////////////

      if (XLEN > 64) begin

        if ((encoded_instr_i & 'b11111001111100000111000001111111) == 'b00010000000000000011000000101111) begin
          decoded_instr_o.op = LR_D;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b00011000000000000011000000101111) begin
          decoded_instr_o.op = SC_D;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b00001000000000000011000000101111) begin
          decoded_instr_o.op = AMOSWAP_D;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b00000000000000000011000000101111) begin
          decoded_instr_o.op = AMOADD_D;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b00100000000000000011000000101111) begin
          decoded_instr_o.op = AMOXOR_D;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b01100000000000000011000000101111) begin
          decoded_instr_o.op = AMOAND_D;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b01000000000000000011000000101111) begin
          decoded_instr_o.op = AMOOR_D;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b10000000000000000011000000101111) begin
          decoded_instr_o.op = AMOMIN_D;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b10100000000000000011000000101111) begin
          decoded_instr_o.op = AMOMAX_D;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b11000000000000000011000000101111) begin
          decoded_instr_o.op = AMOMINU_D;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b11100000000000000011000000101111) begin
          decoded_instr_o.op = AMOMAXU_D;  // decoded_instr_o.imm = uimm;
        end

      end

    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // RV32F
    ////////////////////////////////////////////////////////////////////////////////////////////////

    if (EN_FLOAT) begin

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000010000000000111) begin
        decoded_instr_o.op = FLW;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000010000000100111) begin
        decoded_instr_o.op = FSW;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b00000110000000000000000001111111) == 'b00000000000000000000000001000011) begin
        decoded_instr_o.op = FMADD_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b00000110000000000000000001111111) == 'b00000000000000000000000001000111) begin
        decoded_instr_o.op = FMSUB_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b00000110000000000000000001111111) == 'b00000000000000000000000001001011) begin
        decoded_instr_o.op = FNMSUB_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b00000110000000000000000001111111) == 'b00000000000000000000000001001111) begin
        decoded_instr_o.op = FNMADD_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000000000001111111) == 'b00000000000000000000000001010011) begin
        decoded_instr_o.op = FADD_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000000000001111111) == 'b00001000000000000000000001010011) begin
        decoded_instr_o.op = FSUB_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000000000001111111) == 'b00010000000000000000000001010011) begin
        decoded_instr_o.op = FMUL_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000000000001111111) == 'b00011000000000000000000001010011) begin
        decoded_instr_o.op = FDIV_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b01011000000000000000000001010011) begin
        decoded_instr_o.op = FSQRT_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00100000000000000000000001010011) begin
        decoded_instr_o.op = FSGNJ_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00100000000000000001000001010011) begin
        decoded_instr_o.op = FSGNJN_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00100000000000000010000001010011) begin
        decoded_instr_o.op = FSGNJX_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00101000000000000000000001010011) begin
        decoded_instr_o.op = FMIN_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00101000000000000001000001010011) begin
        decoded_instr_o.op = FMAX_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11000000000000000000000001010011) begin
        decoded_instr_o.op = FCVT_W_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11000000000100000000000001010011) begin
        decoded_instr_o.op = FCVT_WU_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111111111100000111000001111111) == 'b11100000000000000000000001010011) begin
        decoded_instr_o.op = FMV_X_W;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b10100000000000000010000001010011) begin
        decoded_instr_o.op = FEQ_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b10100000000000000001000001010011) begin
        decoded_instr_o.op = FLT_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b10100000000000000000000001010011) begin
        decoded_instr_o.op = FLE_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111111111100000111000001111111) == 'b11100000000000000001000001010011) begin
        decoded_instr_o.op = FCLASS_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11010000000000000000000001010011) begin
        decoded_instr_o.op = FCVT_S_W;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11010000000100000000000001010011) begin
        decoded_instr_o.op = FCVT_S_WU;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111111111100000111000001111111) == 'b11110000000000000000000001010011) begin
        decoded_instr_o.op = FMV_W_X;  // decoded_instr_o.imm = uimm;
      end

      ////////////////////////////////////////////////////////////////////////////////////////////////
      // RV64F
      ////////////////////////////////////////////////////////////////////////////////////////////////

      if (XLEN > 32) begin

        if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11000000001000000000000001010011) begin
          decoded_instr_o.op = FCVT_L_S;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11000000001100000000000001010011) begin
          decoded_instr_o.op = FCVT_LU_S;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11010000001000000000000001010011) begin
          decoded_instr_o.op = FCVT_S_L;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11010000001100000000000001010011) begin
          decoded_instr_o.op = FCVT_S_LU;  // decoded_instr_o.imm = uimm;
        end

      end

    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // RV32D    
    ////////////////////////////////////////////////////////////////////////////////////////////////

    if (EN_DOUBLE) begin

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000011000000000111) begin
        decoded_instr_o.op = FLD;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000011000000100111) begin
        decoded_instr_o.op = FSD;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b00000110000000000000000001111111) == 'b00000010000000000000000001000011) begin
        decoded_instr_o.op = FMADD_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b00000110000000000000000001111111) == 'b00000010000000000000000001000111) begin
        decoded_instr_o.op = FMSUB_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b00000110000000000000000001111111) == 'b00000010000000000000000001001011) begin
        decoded_instr_o.op = FNMSUB_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b00000110000000000000000001111111) == 'b00000010000000000000000001001111) begin
        decoded_instr_o.op = FNMADD_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000000000001111111) == 'b00000010000000000000000001010011) begin
        decoded_instr_o.op = FADD_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000000000001111111) == 'b00001010000000000000000001010011) begin
        decoded_instr_o.op = FSUB_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000000000001111111) == 'b00010010000000000000000001010011) begin
        decoded_instr_o.op = FMUL_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000000000001111111) == 'b00011010000000000000000001010011) begin
        decoded_instr_o.op = FDIV_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b01011010000000000000000001010011) begin
        decoded_instr_o.op = FSQRT_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00100010000000000000000001010011) begin
        decoded_instr_o.op = FSGNJ_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00100010000000000001000001010011) begin
        decoded_instr_o.op = FSGNJN_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00100010000000000010000001010011) begin
        decoded_instr_o.op = FSGNJX_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00101010000000000000000001010011) begin
        decoded_instr_o.op = FMIN_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00101010000000000001000001010011) begin
        decoded_instr_o.op = FMAX_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b01000000000100000000000001010011) begin
        decoded_instr_o.op = FCVT_S_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b01000010000000000000000001010011) begin
        decoded_instr_o.op = FCVT_D_S;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b10100010000000000010000001010011) begin
        decoded_instr_o.op = FEQ_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b10100010000000000001000001010011) begin
        decoded_instr_o.op = FLT_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b10100010000000000000000001010011) begin
        decoded_instr_o.op = FLE_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111111111100000111000001111111) == 'b11100010000000000001000001010011) begin
        decoded_instr_o.op = FCLASS_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11000010000000000000000001010011) begin
        decoded_instr_o.op = FCVT_W_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11000010000100000000000001010011) begin
        decoded_instr_o.op = FCVT_WU_D;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11010010000000000000000001010011) begin
        decoded_instr_o.op = FCVT_D_W;  // decoded_instr_o.imm = uimm;
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11010010000100000000000001010011) begin
        decoded_instr_o.op = FCVT_D_WU;  // decoded_instr_o.imm = uimm;
      end

      ////////////////////////////////////////////////////////////////////////////////////////////////
      // RV64D
      ////////////////////////////////////////////////////////////////////////////////////////////////

      if (XLEN > 32) begin

        if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11000010001000000000000001010011) begin
          decoded_instr_o.op = FCVT_L_D;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11000010001100000000000001010011) begin
          decoded_instr_o.op = FCVT_LU_D;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111111111100000111000001111111) == 'b11100010000000000000000001010011) begin
          decoded_instr_o.op = FMV_X_D;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11010010001000000000000001010011) begin
          decoded_instr_o.op = FCVT_D_L;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11010010001100000000000001010011) begin
          decoded_instr_o.op = FCVT_D_LU;  // decoded_instr_o.imm = uimm;
        end

        if ((encoded_instr_i & 'b11111111111100000111000001111111) == 'b11110010000000000000000001010011) begin
          decoded_instr_o.op = FMV_D_X;  // decoded_instr_o.imm = uimm;
        end

      end

    end

  end

endmodule
