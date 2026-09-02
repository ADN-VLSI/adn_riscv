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
  import adn_riscv_pkg::*;
#(
    parameter int XLEN = 64
) (

    // ------------------------------------------------
    // required for pipelining
    // ------------------------------------------------
    input logic clk_i,
    input logic arst_ni,

    // ------------------------------------------------
    // ALU operation control
    // ------------------------------------------------
    input rv_op_t     alu_op_i,

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

    Exceptional instructions: this module assumes immediate values are inside
    operand_b_i
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

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // temp result storage
  logic [XLEN-1:0] result_xlen;
  logic [31:0]     result_word;

  logic sub;  // decide if the selected instruction/s is subtractor
  logic [XLEN-1:0] addsub_result; // result for add/sub
  logic [XLEN-1:0] result_comb; // result from the always_comb alu

  logic [XLEN-1:0] operand_b_addsub;  // holder for operand b based on sub

  // for pipeline:
  //      here both pipe_data_in and pipe_data_out will hold addr along with the result
  logic [XLEN+5-1:0]  pipe_data_in; // extra 5 bit to hold rd_addr_i
  logic [XLEN+5-1:0]  pipe_data_out; // extra 5 bit to hold rd_addr_i


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  always_comb begin
    sub = '0;
    case (alu_op_i)
      SUB, SUBW: sub = 1'b1;
      default: ;
    endcase
  end


  always_comb begin
     operand_b_addsub = sub ? (~operand_b_i): operand_b_i;
     addsub_result = operand_a_i + operand_b_addsub + sub;
  end

  always_comb begin: operation
    result_xlen = '0;
    result_word = '0;

      case (alu_op_i)
        ADD, ADDI, SUB: result_xlen = addsub_result;
        // RISCV Spec:
        // The operand to be shifted is in rs1, and the shift amount is encoded in
        //      the lower 6 bits of the I-immediate field for RV64I. In RV64I, only
        //      the low 6 bits of rs2 are considered for the shift amount.
        // ---------------------- My design choice -------------------------------------
        // SLLI gets its shift amount from immediate. Here operand_b_i is supposed to get
        // the immediate value so the lower 6 bit can work. SLTI and others are same.
        // If the decoder is not producing operands this way, then an extra module can be
        //      implemented that will do the immediate assignment to the operand_b based on the
        //      instructions
        SLL,  SLLI:         result_xlen = operand_a_i << operand_b_i[5:0];
        SLT,  SLTI:         result_xlen = $signed(operand_a_i) < $signed(operand_b_i);
        SLTU, SLTIU:        result_xlen = operand_a_i < operand_b_i;
        XOR,  XORI:         result_xlen = operand_a_i ^ operand_b_i;
        SRL,  SRLI:         result_xlen = operand_a_i >> operand_b_i[5:0];
        SRA,  SRAI:         result_xlen = $signed(operand_a_i) >>> operand_b_i[5:0];
        OR,   ORI:          result_xlen = operand_a_i | operand_b_i;
        AND,  ANDI:         result_xlen = operand_a_i & operand_b_i;
        SLLW, SLLIW:        result_word = operand_a_i[31:0] << operand_b_i[4:0];
        SRLW, SRLIW:        result_word = operand_a_i[31:0] >> operand_b_i[4:0];
        SRAW, SRAIW:        result_word = $signed(operand_a_i[31:0]) >>> operand_b_i[4:0];
        default: ;
      endcase
  end:operation

  // result selection based on instruction type - normal vs word
  always_comb begin
    case (alu_op_i)
      ADDW, ADDIW, SUBW: result_comb = {{(XLEN-32){addsub_result[31]}},addsub_result[31:0]};
      SLLW, SLLIW, SRLW,
      SRLIW, SRAW, SRAIW: result_comb = {{32{result_word[31]}},result_word};
      default: result_comb = result_xlen;
    endcase
  end

  // input to the pipeline
  always_comb pipe_data_in = {rd_addr_i, result_comb};

  // result extraction from the pipeline output
  always_comb result_o = pipe_data_out[XLEN-1:0];
  always_comb rd_addr_o = pipe_data_out[XLEN+5-1:XLEN]; // extracting the addr

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////
  adn_common_pipeline #(
      .DATA_WIDTH($bits(pipe_data_in))
  ) u_i64_pipeline (
      .arst_ni(arst_ni),
      .clk_i(clk_i),
      .clear_i('0),

      .data_in_i       ( pipe_data_in ),
      .data_in_valid_i ( valid_i ),
      .data_in_ready_o ( ready_o ),

      .data_out_o      ( pipe_data_out ),
      .data_out_valid_o( valid_o ),
      .data_out_ready_i( ready_i )
  );

endmodule

