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
`include "adn_riscv/typedef.svh"

module adn_riscv_instr_decoder
  import adn_riscv_pkg::*;
#(
    parameter int XLEN             = 64,     // Data path width
    parameter bit EN_ZIFENCE_I     = 1,      // Enable Zifencei extension
    parameter bit EN_ZICSR         = 1,      // Enable Zicsr extension
    parameter bit EN_MATH          = 1,      // Enable M-extension
    parameter bit EN_ATOMICS       = 1,      // Enable A-extension
    parameter bit EN_FLOAT         = 1,      // Enable F-extension
    parameter bit EN_DOUBLE        = 1,      // Enable D-extension
    parameter type decoded_instr_t = logic   // Decoded instruction structure type
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

  logic x_rd;
  logic x_rs1;
  logic x_rs2;
  logic f_rd;
  logic f_rs1;
  logic f_rs2;
  logic f_rs3;

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

  always_comb rimm[2:0]   = encoded_instr_i[14:12];
  always_comb rimm[31:3]  = '0;

  always_comb simm[4:0]   = encoded_instr_i[11:7];
  always_comb simm[11:5]  = encoded_instr_i[31:25];
  always_comb simm[31:12] = {20{encoded_instr_i[31:25]}};

  always_comb timm[0]     = encoded_instr_i[25:25];
  always_comb timm[1]     = encoded_instr_i[26:26];
  always_comb timm[31:2]  = '0;

  always_comb uimm[11:0]  = '0;
  always_comb uimm[31:12] = encoded_instr_i[31:12];

  always_comb begin 
    case ({x_rd,f_rd})
      'b01   : decoded_instr_o.rd  = {'1, encoded_instr_i[11:7]}; 
      'b10   : decoded_instr_o.rd  = {'0, encoded_instr_i[11:7]}; 
      default: decoded_instr_o.rd  = '0;
    endcase
  end

  always_comb begin 
    case ({x_rs1,f_rs1})
      'b01   : decoded_instr_o.rs1 = {'1, encoded_instr_i[19:15]};
      'b10   : decoded_instr_o.rs1 = {'0, encoded_instr_i[19:15]};
      default: decoded_instr_o.rs1 = '0;
    endcase
  end

 always_comb begin 
    case ({x_rs2,f_rs2})
      'b01   : decoded_instr_o.rs2 = {'1, encoded_instr_i[24:20]};
      'b10   : decoded_instr_o.rs2 = {'0, encoded_instr_i[24:20]};
      default: decoded_instr_o.rs2 = '0;
    endcase
  end

 always_comb begin 
    case (f_rs3)
      'b01   : decoded_instr_o.rs3 = {'1, encoded_instr_i[31:27]};
      default: decoded_instr_o.rs3 = '0;
    endcase
  end

  always_comb begin
    decoded_instr_o.reg_reqs = '0;
    decoded_instr_o.reg_reqs[decoded_instr_o.rd]  = '1;
    decoded_instr_o.reg_reqs[decoded_instr_o.rs1] = '1;
    decoded_instr_o.reg_reqs[decoded_instr_o.rs2] = '1;
    decoded_instr_o.reg_reqs[decoded_instr_o.rs3] = '1;
  end

  `define INSTR_USAGE(_FUNC_, _IMM_SRC_, _F_RS3_, _F_RS2_, _F_RS1_, _F_RD_, _X_RS2_, _X_RS1_, _X_RD_, _MEM_, _BLK_)   \
    decoded_instr_o.op = ``_FUNC_``;                                                                                  \
    decoded_instr_o.imm = ``_IMM_SRC_``;                                                                              \
    f_rd  = ``_F_RD_``;                                                                                               \
    f_rs1 = ``_F_RS1_``;                                                                                              \
    f_rs2 = ``_F_RS2_``;                                                                                              \
    f_rs3 = ``_F_RS3_``;                                                                                              \
    x_rd  = ``_X_RD_``;                                                                                               \
    x_rs1 = ``_X_RS1_``;                                                                                              \
    x_rs2 = ``_X_RS2_``;                                                                                              \

  always_comb begin

    decoded_instr_o.op = INVALID_INSTRUCTION;
    decoded_instr_o.imm = '0;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // RV32I
    ////////////////////////////////////////////////////////////////////////////////////////////////

    if ((encoded_instr_i & 'b00000000000000000000000001111111) == 'b00000000000000000000000000110111) begin
      `INSTR_USAGE(LUI, uimm, '0, '0, '0, '0, '0, '0, '1, '0, '0) // LUI
    end

    if ((encoded_instr_i & 'b00000000000000000000000001111111) == 'b00000000000000000000000000010111) begin
      `INSTR_USAGE(AUIPC, uimm, '0, '0, '0, '0, '0, '0, '1, '0, '0) // AUIPC
    end

    if ((encoded_instr_i & 'b00000000000000000000000001111111) == 'b00000000000000000000000001101111) begin
      `INSTR_USAGE(JAL, jimm, '0, '0, '0, '0, '0, '0, '1, '0, '1) // JAL
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000000000001100111) begin
      `INSTR_USAGE(JALR, iimm, '0, '0, '0, '0, '0, '1, '1, '0, '1) // JALR
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000000000001100011) begin
      `INSTR_USAGE(BEQ, bimm, '0, '0, '0, '0, '1, '1, '0, '0, '1) // BEQ
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000001000001100011) begin
      `INSTR_USAGE(BNE, bimm, '0, '0, '0, '0, '1, '1, '0, '0, '1) // BNE
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000100000001100011) begin
      `INSTR_USAGE(BLT, bimm, '0, '0, '0, '0, '1, '1, '0, '0, '1) // BLT
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000101000001100011) begin
      `INSTR_USAGE(BGE, bimm, '0, '0, '0, '0, '1, '1, '0, '0, '1) // BGE
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000110000001100011) begin
      `INSTR_USAGE(BLTU, bimm, '0, '0, '0, '0, '1, '1, '0, '0, '1) // BLTU
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000111000001100011) begin
      `INSTR_USAGE(BGEU, bimm, '0, '0, '0, '0, '1, '1, '0, '0, '1) // BGEU
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000000000000000011) begin
      `INSTR_USAGE(LB, iimm, '0, '0, '0, '0, '0, '1, '1, '1, '0) // LB
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000001000000000011) begin
      `INSTR_USAGE(LH, iimm, '0, '0, '0, '0, '0, '1, '1, '1, '0) // LH
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000010000000000011) begin
      `INSTR_USAGE(LW, iimm, '0, '0, '0, '0, '0, '1, '1, '1, '0) // LW
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000100000000000011) begin
      `INSTR_USAGE(LBU, iimm, '0, '0, '0, '0, '0, '1, '1, '1, '0) // LBU
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000101000000000011) begin
      `INSTR_USAGE(LHU, iimm, '0, '0, '0, '0, '0, '1, '1, '1, '0) // LHU
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000000000000100011) begin
      `INSTR_USAGE(SB, simm, '0, '0, '0, '0, '1, '1, '0, '1, '0) // SB
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000001000000100011) begin
      `INSTR_USAGE(SH, simm, '0, '0, '0, '0, '1, '1, '0, '1, '0) // SH
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000010000000100011) begin
      `INSTR_USAGE(SW, simm, '0, '0, '0, '0, '1, '1, '0, '1, '0) // SW
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000000000000010011) begin
      `INSTR_USAGE(ADDI, iimm, '0, '0, '0, '0, '0, '1, '1, '0, '0) // ADDI
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000010000000010011) begin
      `INSTR_USAGE(SLTI, iimm, '0, '0, '0, '0, '0, '1, '1, '0, '0) // SLTI
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000011000000010011) begin
      `INSTR_USAGE(SLTIU, iimm, '0, '0, '0, '0, '0, '1, '1, '0, '0) // SLTIU
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000100000000010011) begin
      `INSTR_USAGE(XORI, iimm, '0, '0, '0, '0, '0, '1, '1, '0, '0) // XORI
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000110000000010011) begin
      `INSTR_USAGE(ORI, iimm, '0, '0, '0, '0, '0, '1, '1, '0, '0) // ORI
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000111000000010011) begin
      `INSTR_USAGE(ANDI, iimm, '0, '0, '0, '0, '0, '1, '1, '0, '0) // ANDI
    end

    if ((encoded_instr_i & 'b11111100000000000111000001111111) == 'b00000000000000000001000000010011) begin
      `INSTR_USAGE(SLLI, aimm, '0, '0, '0, '0, '0, '1, '1, '0, '0) // SLLI
    end

    if ((encoded_instr_i & 'b11111100000000000111000001111111) == 'b00000000000000000101000000010011) begin
      `INSTR_USAGE(SRLI, aimm, '0, '0, '0, '0, '0, '1, '1, '0, '0) // SRLI
    end

    if ((encoded_instr_i & 'b11111100000000000111000001111111) == 'b01000000000000000101000000010011) begin
      `INSTR_USAGE(SRAI, aimm, '0, '0, '0, '0, '0, '1, '1, '0, '0) // SRAI
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000000000000110011) begin
      `INSTR_USAGE(ADD, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // ADD
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b01000000000000000000000000110011) begin
      `INSTR_USAGE(SUB, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // SUB
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000001000000110011) begin
      `INSTR_USAGE(SLL, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // SLL
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000010000000110011) begin
      `INSTR_USAGE(SLT, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // SLT
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000011000000110011) begin
      `INSTR_USAGE(SLTU, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // SLTU
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000100000000110011) begin
      `INSTR_USAGE(XOR, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // XOR
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000101000000110011) begin
      `INSTR_USAGE(SRL, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // SRL
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b01000000000000000101000000110011) begin
      `INSTR_USAGE(SRA, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // SRA
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000110000000110011) begin
      `INSTR_USAGE(OR, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // OR
    end

    if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000111000000110011) begin
      `INSTR_USAGE(AND, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // AND
    end

    if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000000000000001111) begin
      `INSTR_USAGE(FENCE, iimm, '0, '0, '0, '0, '0, '1, '1, '1, '0) // FENCE
    end

    if ((encoded_instr_i & 'b11111111111111111111111111111111) == 'b00000000000000000000000001110011) begin
      `INSTR_USAGE(ECALL, iimm, '0, '0, '0, '0, '0, '0, '0, '0, '1) // ECALL
    end

    if ((encoded_instr_i & 'b11111111111111111111111111111111) == 'b00000000000100000000000001110011) begin
      `INSTR_USAGE(EBREAK, iimm, '0, '0, '0, '0, '0, '0, '0, '0, '1) // EBREAK
    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // RV64I
    ////////////////////////////////////////////////////////////////////////////////////////////////

    if (XLEN > 32) begin

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000110000000000011) begin
        `INSTR_USAGE(LWU, iimm, '0, '0, '0, '0, '0, '1, '1, '1, '0) // LWU
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000011000000000011) begin
        `INSTR_USAGE(LD, iimm, '0, '0, '0, '0, '0, '1, '1, '1, '0) // LD
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000011000000100011) begin
        `INSTR_USAGE(SD, simm, '0, '0, '0, '0, '1, '1, '0, '1, '0) // SD
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000000000000011011) begin
        `INSTR_USAGE(ADDIW, iimm, '0, '0, '0, '0, '0, '1, '1, '0, '0) // ADDIW
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000001000000011011) begin
        `INSTR_USAGE(SLLIW, aimm, '0, '0, '0, '0, '0, '1, '1, '0, '0) // SLLIW
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000101000000011011) begin
        `INSTR_USAGE(SRLIW, aimm, '0, '0, '0, '0, '0, '1, '1, '0, '0) // SRLIW
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b01000000000000000101000000011011) begin
        `INSTR_USAGE(SRAIW, aimm, '0, '0, '0, '0, '0, '1, '1, '0, '0) // SRAIW
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000000000000111011) begin
        `INSTR_USAGE(ADDW, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // ADDW
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b01000000000000000000000000111011) begin
        `INSTR_USAGE(SUBW, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // SUBW
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000001000000111011) begin
        `INSTR_USAGE(SLLW, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // SLLW
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000000000000000101000000111011) begin
        `INSTR_USAGE(SRLW, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // SRLW
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b01000000000000000101000000111011) begin
        `INSTR_USAGE(SRAW, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // SRAW
      end

    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // Zifencei
    ////////////////////////////////////////////////////////////////////////////////////////////////

    if (EN_ZIFENCE_I) begin
      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000001000000001111) begin
        `INSTR_USAGE(FENCE_I, iimm, '0, '0, '0, '0, '0, '1, '1, '1, '0) // FENCE_I
      end
    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // Zicsr
    ////////////////////////////////////////////////////////////////////////////////////////////////

    if (EN_ZICSR) begin

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000001000001110011) begin
        `INSTR_USAGE(CSRRW, iimm, '0, '0, '0, '0, '0, '1, '1, '0, '0) // CSRRW
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000010000001110011) begin
        `INSTR_USAGE(CSRRS, iimm, '0, '0, '0, '0, '0, '1, '1, '0, '0) // CSRRS
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000011000001110011) begin
        `INSTR_USAGE(CSRRC, iimm, '0, '0, '0, '0, '0, '1, '1, '0, '0) // CSRRC
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000101000001110011) begin
        `INSTR_USAGE(CSRRWI, cimm, '0, '0, '0, '0, '0, '0, '1, '0, '0) // CSRRWI
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000110000001110011) begin
        `INSTR_USAGE(CSRRSI, cimm, '0, '0, '0, '0, '0, '0, '1, '0, '0) // CSRRSI
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000111000001110011) begin
        `INSTR_USAGE(CSRRCI, cimm, '0, '0, '0, '0, '0, '0, '1, '0, '0) // CSRRCI
      end

    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // RV32M
    ////////////////////////////////////////////////////////////////////////////////////////////////

    if (EN_MATH) begin

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000000000000110011) begin
        `INSTR_USAGE(MUL, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // MUL
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000001000000110011) begin
        `INSTR_USAGE(MULH, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // MULH
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000010000000110011) begin
        `INSTR_USAGE(MULHSU, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // MULHSU
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000011000000110011) begin
        `INSTR_USAGE(MULHU, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // MULHU
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000100000000110011) begin
        `INSTR_USAGE(DIV, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // DIV
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000101000000110011) begin
        `INSTR_USAGE(DIVU, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // DIVU
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000110000000110011) begin
        `INSTR_USAGE(REM, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // REM
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000111000000110011) begin
        `INSTR_USAGE(REMU, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // REMU
      end

      ////////////////////////////////////////////////////////////////////////////////////////////////
      // RV64M
      ////////////////////////////////////////////////////////////////////////////////////////////////

      if (XLEN > 32) begin

        if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000000000000111011) begin
          `INSTR_USAGE(MULW, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // MULW
        end

        if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000100000000111011) begin
          `INSTR_USAGE(DIVW, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // DIVW
        end

        if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000101000000111011) begin
          `INSTR_USAGE(DIVUW, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // DIVUW
        end

        if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000110000000111011) begin
          `INSTR_USAGE(REMW, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // REMW
        end

        if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00000010000000000111000000111011) begin
          `INSTR_USAGE(REMUW, '0, '0, '0, '0, '0, '1, '1, '1, '0, '0) // REMUW
        end

      end

    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // RV32A
    ////////////////////////////////////////////////////////////////////////////////////////////////

    if (EN_ATOMICS) begin

      if ((encoded_instr_i & 'b11111001111100000111000001111111) == 'b00010000000000000010000000101111) begin
        `INSTR_USAGE(LR_W, timm, '0, '0, '0, '0, '0, '1, '1, '1, '0) // LR_W
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b00011000000000000010000000101111) begin
        `INSTR_USAGE(SC_W, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // SC_W
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b00001000000000000010000000101111) begin
        `INSTR_USAGE(AMOSWAP_W, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // AMOSWAP_W
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b00000000000000000010000000101111) begin
        `INSTR_USAGE(AMOADD_W, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // AMOADD_W
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b00100000000000000010000000101111) begin
        `INSTR_USAGE(AMOXOR_W, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // AMOXOR_W
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b01100000000000000010000000101111) begin
        `INSTR_USAGE(AMOAND_W, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // AMOAND_W
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b01000000000000000010000000101111) begin
        `INSTR_USAGE(AMOOR_W, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // AMOOR_W
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b10000000000000000010000000101111) begin
        `INSTR_USAGE(AMOMIN_W, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // AMOMIN_W
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b10100000000000000010000000101111) begin
        `INSTR_USAGE(AMOMAX_W, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // AMOMAX_W
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b11000000000000000010000000101111) begin
        `INSTR_USAGE(AMOMINU_W, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // AMOMINU_W
      end

      if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b11100000000000000010000000101111) begin
        `INSTR_USAGE(AMOMAXU_W, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // AMOMAXU_W
      end

      ////////////////////////////////////////////////////////////////////////////////////////////////
      // RV64A
      ////////////////////////////////////////////////////////////////////////////////////////////////

      if (XLEN > 32) begin

        if ((encoded_instr_i & 'b11111001111100000111000001111111) == 'b00010000000000000011000000101111) begin
          `INSTR_USAGE(LR_D, timm, '0, '0, '0, '0, '0, '1, '1, '1, '0) // LR_D
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b00011000000000000011000000101111) begin
          `INSTR_USAGE(SC_D, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // SC_D
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b00001000000000000011000000101111) begin
          `INSTR_USAGE(AMOSWAP_D, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // AMOSWAP_D
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b00000000000000000011000000101111) begin
          `INSTR_USAGE(AMOADD_D, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // AMOADD_D
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b00100000000000000011000000101111) begin
          `INSTR_USAGE(AMOXOR_D, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // AMOXOR_D
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b01100000000000000011000000101111) begin
          `INSTR_USAGE(AMOAND_D, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // AMOAND_D
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b01000000000000000011000000101111) begin
          `INSTR_USAGE(AMOOR_D, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // AMOOR_D
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b10000000000000000011000000101111) begin
          `INSTR_USAGE(AMOMIN_D, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // AMOMIN_D
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b10100000000000000011000000101111) begin
          `INSTR_USAGE(AMOMAX_D, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // AMOMAX_D
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b11000000000000000011000000101111) begin
          `INSTR_USAGE(AMOMINU_D, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // AMOMINU_D
        end

        if ((encoded_instr_i & 'b11111000000000000111000001111111) == 'b11100000000000000011000000101111) begin
          `INSTR_USAGE(AMOMAXU_D, timm, '0, '0, '0, '0, '1, '1, '1, '1, '0) // AMOMAXU_D
        end

      end

    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // RV32F
    ////////////////////////////////////////////////////////////////////////////////////////////////

    if (EN_FLOAT) begin

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000010000000000111) begin
        `INSTR_USAGE(FLW, iimm, '0, '0, '0, '1, '0, '1, '0, '1, '0) // FLW
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000010000000100111) begin
        `INSTR_USAGE(FSW, simm, '0, '0, '1, '0, '0, '1, '0, '1, '0) // FSW
      end

      if ((encoded_instr_i & 'b00000110000000000000000001111111) == 'b00000000000000000000000001000011) begin
        `INSTR_USAGE(FMADD_S, rimm, '1, '1, '1, '1, '0, '0, '0, '0, '0) // FMADD_S
      end

      if ((encoded_instr_i & 'b00000110000000000000000001111111) == 'b00000000000000000000000001000111) begin
        `INSTR_USAGE(FMSUB_S, rimm, '1, '1, '1, '1, '0, '0, '0, '0, '0) // FMSUB_S
      end

      if ((encoded_instr_i & 'b00000110000000000000000001111111) == 'b00000000000000000000000001001011) begin
        `INSTR_USAGE(FNMSUB_S, rimm, '1, '1, '1, '1, '0, '0, '0, '0, '0) // FNMSUB_S
      end

      if ((encoded_instr_i & 'b00000110000000000000000001111111) == 'b00000000000000000000000001001111) begin
        `INSTR_USAGE(FNMADD_S, rimm, '1, '1, '1, '1, '0, '0, '0, '0, '0) // FNMADD_S
      end

      if ((encoded_instr_i & 'b11111110000000000000000001111111) == 'b00000000000000000000000001010011) begin
        `INSTR_USAGE(FADD_S, rimm, '0, '1, '1, '1, '0, '0, '0, '0, '0) // FADD_S
      end

      if ((encoded_instr_i & 'b11111110000000000000000001111111) == 'b00001000000000000000000001010011) begin
        `INSTR_USAGE(FSUB_S, rimm, '0, '1, '1, '1, '0, '0, '0, '0, '0) // FSUB_S
      end

      if ((encoded_instr_i & 'b11111110000000000000000001111111) == 'b00010000000000000000000001010011) begin
        `INSTR_USAGE(FMUL_S, rimm, '0, '1, '1, '1, '0, '0, '0, '0, '0) // FMUL_S
      end

      if ((encoded_instr_i & 'b11111110000000000000000001111111) == 'b00011000000000000000000001010011) begin
        `INSTR_USAGE(FDIV_S, rimm, '0, '1, '1, '1, '0, '0, '0, '0, '0) // FDIV_S
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b01011000000000000000000001010011) begin
        `INSTR_USAGE(FSQRT_S, rimm, '0, '0, '1, '1, '0, '0, '0, '0, '0) // FSQRT_S
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00100000000000000000000001010011) begin
        `INSTR_USAGE(FSGNJ_S, '0, '0, '1, '1, '1, '0, '0, '0, '0, '0) // FSGNJ_S
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00100000000000000001000001010011) begin
        `INSTR_USAGE(FSGNJN_S, '0, '0, '1, '1, '1, '0, '0, '0, '0, '0) // FSGNJN_S
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00100000000000000010000001010011) begin
        `INSTR_USAGE(FSGNJX_S, '0, '0, '1, '1, '1, '0, '0, '0, '0, '0) // FSGNJX_S
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00101000000000000000000001010011) begin
        `INSTR_USAGE(FMIN_S, '0, '0, '1, '1, '1, '0, '0, '0, '0, '0) // FMIN_S
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00101000000000000001000001010011) begin
        `INSTR_USAGE(FMAX_S, '0, '0, '1, '1, '1, '0, '0, '0, '0, '0) // FMAX_S
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11000000000000000000000001010011) begin
        `INSTR_USAGE(FCVT_W_S, rimm, '0, '0, '1, '0, '0, '0, '1, '0, '0) // FCVT_W_S
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11000000000100000000000001010011) begin
        `INSTR_USAGE(FCVT_WU_S, rimm, '0, '0, '1, '0, '0, '0, '1, '0, '0) // FCVT_WU_S
      end

      if ((encoded_instr_i & 'b11111111111100000111000001111111) == 'b11100000000000000000000001010011) begin
        `INSTR_USAGE(FMV_X_W, '0, '0, '0, '1, '0, '0, '0, '1, '0, '0) // FMV_X_W
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b10100000000000000010000001010011) begin
        `INSTR_USAGE(FEQ_S, '0, '0, '1, '1, '0, '0, '0, '1, '0, '0) // FEQ_S
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b10100000000000000001000001010011) begin
        `INSTR_USAGE(FLT_S, '0, '0, '1, '1, '0, '0, '0, '1, '0, '0) // FLT_S
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b10100000000000000000000001010011) begin
        `INSTR_USAGE(FLE_S, '0, '0, '1, '1, '0, '0, '0, '1, '0, '0) // FLE_S
      end

      if ((encoded_instr_i & 'b11111111111100000111000001111111) == 'b11100000000000000001000001010011) begin
        `INSTR_USAGE(FCLASS_S, '0, '0, '0, '1, '0, '0, '0, '1, '0, '0) // FCLASS_S
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11010000000000000000000001010011) begin
        `INSTR_USAGE(FCVT_S_W, rimm, '0, '0, '0, '1, '0, '1, '0, '0, '0) // FCVT_S_W
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11010000000100000000000001010011) begin
        `INSTR_USAGE(FCVT_S_WU, rimm, '0, '0, '0, '1, '0, '1, '0, '0, '0) // FCVT_S_WU
      end

      if ((encoded_instr_i & 'b11111111111100000111000001111111) == 'b11110000000000000000000001010011) begin
        `INSTR_USAGE(FMV_W_X, '0, '0, '0, '0, '1, '0, '1, '0, '0, '0) // FMV_W_X
      end

      ////////////////////////////////////////////////////////////////////////////////////////////////
      // RV64F
      ////////////////////////////////////////////////////////////////////////////////////////////////

      if (XLEN > 32) begin

        if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11000000001000000000000001010011) begin
          `INSTR_USAGE(FCVT_L_S, rimm, '0, '0, '1, '0, '0, '0, '1, '0, '0) // FCVT_L_S
        end

        if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11000000001100000000000001010011) begin
          `INSTR_USAGE(FCVT_LU_S, rimm, '0, '0, '1, '0, '0, '0, '1, '0, '0) // FCVT_LU_S
        end

        if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11010000001000000000000001010011) begin
          `INSTR_USAGE(FCVT_S_L, rimm, '0, '0, '0, '1, '0, '1, '0, '0, '0) // FCVT_S_L
        end

        if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11010000001100000000000001010011) begin
          `INSTR_USAGE(FCVT_S_LU, rimm, '0, '0, '0, '1, '0, '1, '0, '0, '0) // FCVT_S_LU
        end

      end

    end

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // RV32D    
    ////////////////////////////////////////////////////////////////////////////////////////////////

    if (EN_DOUBLE) begin

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000011000000000111) begin
        `INSTR_USAGE(FLD, iimm, '0, '0, '0, '1, '0, '1, '0, '1, '0) // FLD
      end

      if ((encoded_instr_i & 'b00000000000000000111000001111111) == 'b00000000000000000011000000100111) begin
        `INSTR_USAGE(FSD, simm, '0, '0, '1, '0, '0, '1, '0, '1, '0) // FSD
      end

      if ((encoded_instr_i & 'b00000110000000000000000001111111) == 'b00000010000000000000000001000011) begin
        `INSTR_USAGE(FMADD_D, rimm, '1, '1, '1, '1, '0, '0, '0, '0, '0) // FMADD_D
      end

      if ((encoded_instr_i & 'b00000110000000000000000001111111) == 'b00000010000000000000000001000111) begin
        `INSTR_USAGE(FMSUB_D, rimm, '1, '1, '1, '1, '0, '0, '0, '0, '0) // FMSUB_D
      end

      if ((encoded_instr_i & 'b00000110000000000000000001111111) == 'b00000010000000000000000001001011) begin
        `INSTR_USAGE(FNMSUB_D, rimm, '1, '1, '1, '1, '0, '0, '0, '0, '0) // FNMSUB_D
      end

      if ((encoded_instr_i & 'b00000110000000000000000001111111) == 'b00000010000000000000000001001111) begin
        `INSTR_USAGE(FNMADD_D, rimm, '1, '1, '1, '1, '0, '0, '0, '0, '0) // FNMADD_D
      end

      if ((encoded_instr_i & 'b11111110000000000000000001111111) == 'b00000010000000000000000001010011) begin
        `INSTR_USAGE(FADD_D, rimm, '0, '1, '1, '1, '0, '0, '0, '0, '0) // FADD_D
      end

      if ((encoded_instr_i & 'b11111110000000000000000001111111) == 'b00001010000000000000000001010011) begin
        `INSTR_USAGE(FSUB_D, rimm, '0, '1, '1, '1, '0, '0, '0, '0, '0) // FSUB_D
      end

      if ((encoded_instr_i & 'b11111110000000000000000001111111) == 'b00010010000000000000000001010011) begin
        `INSTR_USAGE(FMUL_D, rimm, '0, '1, '1, '1, '0, '0, '0, '0, '0) // FMUL_D
      end

      if ((encoded_instr_i & 'b11111110000000000000000001111111) == 'b00011010000000000000000001010011) begin
        `INSTR_USAGE(FDIV_D, rimm, '0, '1, '1, '1, '0, '0, '0, '0, '0) // FDIV_D
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b01011010000000000000000001010011) begin
        `INSTR_USAGE(FSQRT_D, rimm, '0, '0, '1, '1, '0, '0, '0, '0, '0) // FSQRT_D
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00100010000000000000000001010011) begin
        `INSTR_USAGE(FSGNJ_D, '0, '0, '1, '1, '1, '0, '0, '0, '0, '0) // FSGNJ_D
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00100010000000000001000001010011) begin
        `INSTR_USAGE(FSGNJN_D, '0, '0, '1, '1, '1, '0, '0, '0, '0, '0) // FSGNJN_D
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00100010000000000010000001010011) begin
        `INSTR_USAGE(FSGNJX_D, '0, '0, '1, '1, '1, '0, '0, '0, '0, '0) // FSGNJX_D
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00101010000000000000000001010011) begin
        `INSTR_USAGE(FMIN_D, '0, '0, '1, '1, '1, '0, '0, '0, '0, '0) // FMIN_D
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b00101010000000000001000001010011) begin
        `INSTR_USAGE(FMAX_D, '0, '0, '1, '1, '1, '0, '0, '0, '0, '0) // FMAX_D
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b01000000000100000000000001010011) begin
        `INSTR_USAGE(FCVT_S_D, rimm, '0, '0, '1, '1, '0, '0, '0, '0, '0) // FCVT_S_D
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b01000010000000000000000001010011) begin
        `INSTR_USAGE(FCVT_D_S, rimm, '0, '0, '1, '1, '0, '0, '0, '0, '0) // FCVT_D_S
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b10100010000000000010000001010011) begin
        `INSTR_USAGE(FEQ_D, '0, '0, '1, '1, '0, '0, '0, '1, '0, '0) // FEQ_D
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b10100010000000000001000001010011) begin
        `INSTR_USAGE(FLT_D, '0, '0, '1, '1, '0, '0, '0, '1, '0, '0) // FLT_D
      end

      if ((encoded_instr_i & 'b11111110000000000111000001111111) == 'b10100010000000000000000001010011) begin
        `INSTR_USAGE(FLE_D, '0, '0, '1, '1, '0, '0, '0, '1, '0, '0) // FLE_D
      end

      if ((encoded_instr_i & 'b11111111111100000111000001111111) == 'b11100010000000000001000001010011) begin
        `INSTR_USAGE(FCLASS_D, '0, '0, '0, '1, '0, '0, '0, '1, '0, '0) // FCLASS_D
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11000010000000000000000001010011) begin
        `INSTR_USAGE(FCVT_W_D, rimm, '0, '0, '1, '0, '0, '0, '1, '0, '0) // FCVT_W_D
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11000010000100000000000001010011) begin
        `INSTR_USAGE(FCVT_WU_D, rimm, '0, '0, '1, '0, '0, '0, '1, '0, '0) // FCVT_WU_D
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11010010000000000000000001010011) begin
        `INSTR_USAGE(FCVT_D_W, rimm, '0, '0, '0, '1, '0, '1, '0, '0, '0) // FCVT_D_W
      end

      if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11010010000100000000000001010011) begin
        `INSTR_USAGE(FCVT_D_WU, rimm, '0, '0, '0, '1, '0, '1, '0, '0, '0) // FCVT_D_WU
      end

      ////////////////////////////////////////////////////////////////////////////////////////////////
      // RV64D
      ////////////////////////////////////////////////////////////////////////////////////////////////

      if (XLEN > 32) begin

        if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11000010001000000000000001010011) begin
          `INSTR_USAGE(FCVT_L_D, rimm, '0, '0, '1, '0, '0, '0, '1, '0, '0) // FCVT_L_D
        end

        if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11000010001100000000000001010011) begin
          `INSTR_USAGE(FCVT_LU_D, rimm, '0, '0, '1, '0, '0, '0, '1, '0, '0) // FCVT_LU_D
        end

        if ((encoded_instr_i & 'b11111111111100000111000001111111) == 'b11100010000000000000000001010011) begin
          `INSTR_USAGE(FMV_X_D, '0, '0, '0, '1, '0, '0, '0, '1, '0, '0) // FMV_X_D
        end

        if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11010010001000000000000001010011) begin
          `INSTR_USAGE(FCVT_D_L, rimm, '0, '0, '0, '1, '0, '1, '0, '0, '0) // FCVT_D_L
        end

        if ((encoded_instr_i & 'b11111111111100000000000001111111) == 'b11010010001100000000000001010011) begin
          `INSTR_USAGE(FCVT_D_LU, rimm, '0, '0, '0, '1, '0, '1, '0, '0, '0) // FCVT_D_LU
        end

        if ((encoded_instr_i & 'b11111111111100000111000001111111) == 'b11110010000000000000000001010011) begin
          `INSTR_USAGE(FMV_D_X, '0, '0, '0, '0, '1, '0, '1, '0, '0, '0) // FMV_D_X
        end

      end

    end

  end

  `undef INSTR_USAGE

endmodule
