/*

@foez---bhai, write the purpose of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

@foez---bhai, describe the use case of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-09-01 | Mohiuddin Reyad | Initial version                                        |
| 1.0      | 2026-09-01 | Mohiuddin Reyad | Stable release                                         |

Author : Mohiuddin Reyad (mreyad30207@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/
`include "adn_riscv_pkg.sv"

// @foez---bhai, add comments to the parameters, ports
module adn_riscv_exe_i64_alu
  import adn_riscv_pkg::rv_op_t;
#(
    parameter int XLEN = 64
) (

    // ------------------------------------------------
    // required for pipelining
    // ------------------------------------------------
    input logic clk_i,
    input logic arst_ni,

    // instructions inputs
    // input logic   ADDI,
    // input logic   SLTI,
    // input logic   SLTIU,
    // input logic   XORI,
    // input logic   ORI,
    // input logic   ANDI,
    // input logic   SLLI,
    // input logic   SRLI,
    // input logic   SRAI,
    // input logic   ADD,
    // input logic   SUB,
    // input logic   SLL,
    // input logic   SLT,
    // input logic   SLTU,
    // input logic   XOR,
    // input logic   SRL,
    // input logic   SRA,
    // input logic   OR,
    // input logic   AND,
    // input logic   ADDIW,
    // input logic   SLLIW,
    // input logic   SRLIW,
    // input logic   SRAIW,
    // input logic   ADDW,
    // input logic   SUBW,
    // input logic   SLLW,
    // input logic   SRLW,
    // input logic   SRAW,

    // ------------------------------------------------
    // ALU operation control
    // ------------------------------------------------
    input rv_op_t     alu_op_i,
    input  logic      word_op_i, // 1 -> 32bit, 0 -> XLEN operation


    // ------------------------------------------------
    // Operands and destination register
    // ------------------------------------------------
    input logic [XLEN-1:0] operand_a_i, // contents of the register: operand value
    input logic [XLEN-1:0] operand_b_i, // contents of the register: operand value, or
                                        //        the sign extended immediate value
    input logic [4:0]  rd_addr_i,         // index of the destination register

    // ------------------------------------------------
    // Input handshake
    // ------------------------------------------------
    input logic valid_i,
    output logic ready_o,

    // ------------------------------------------------
    // ALU result
    // ------------------------------------------------
    output logic [XLEN-1:0] result_o,
    output logic [4:0]      rd_addr_o,

    // ------------------------------------------------
    // Output handshake
    // ------------------------------------------------
    output logic        valid_o,
    input logic         ready_i
);

  // @foez---bhai, add comments to the functional blocks, signals, and submodules

  /*
  RV64I register-immediate instructions
    ADDI   SLTI   SLTIU   XORI   ORI   ANDI

  RV64I register-register instructions
    ADD   SUB   SLL   SLT   SLTU
    XOR   SRL   SRA   OR    AND
  RV64I word operations
    ADDIW
    ADDW   SUBW   SLLW   SRLW   SRAW

    Exceptional instructions:
      SLLI  SRLI  SRAI
      SLLIW SRLIW SRAIW
  */

  /* Planned Simplified Architecture

  operand_a_i ───┐
                 │
  operand_b_i ───┼──> ALU combinational logic ──> pipeline ──> result_o
                 │                                  │
  alu_op_i ──────┤                                  ├──> rd_addr_o
                 │                                  ├──> valid_o
  word_op_i ─────┘                                  └──> ready_o

  */

  // temp result storage
  logic [XLEN-1:0] result_xlen;
  logic [31:0]     result_word;

  // shift amount
  logic [5:0] shamt_xlen;
  logic [4:0] shamt_word;

  logic sub;  // decide if the selected instruction/s is subtractor

  always_comb begin
    sub = '0;
    case (alu_op_i)
      SUB, SUBW: sub = 1'b1;
      default: ;
    endcase
  end

  always_comb result_o = word_op_i ? {{32{result_word[31]}},result_word} : result_xlen;

  logic [XLEN-1:0] operand_b_addsub;  // holder for operand b based on sub

  always_comb operand_b_addsub = sub ? (~operand_b_i): operand_b_i;

  always_comb begin
    result_xlen = '0;
    result_word = '0;

    if (word_op_i) begin
      case (alu_op_i)
        ADD, ADDI, SUB: result_xlen = operand_a_i + operand_b_addsub + sub;

        default: ;
      endcase
    end
    else begin
      case (alu_op_i)
        ADDW, ADDIW, SUBW: result_word = operand_a_i + operand_b_addsub + sub;
        default: ;
      endcase
    end
  end

endmodule

