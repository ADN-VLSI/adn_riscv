/*

### Purpose
This module implements the 64-bit Arithmetic Logic Unit (ALU) for the ADN-RISCV core. It performs integer arithmetic, logical operations, and word-level operations as defined by the RV64I instruction set architecture, including support for pipelined execution.

### Use Case
This module serves as the primary execution unit for integer arithmetic and logical operations within the ADN-RISCV processor pipeline. It receives operands from the register file or immediate generator, performs the requested operation based on the decoded instruction, and passes the result through a pipeline stage to ensure timing closure and maintain throughput in the execution stage.

#### RV64I register-immediate instructions
    `ADDI` `SLTI` `SLTIU` `XORI` `ORI` `ANDI`

#### RV64I register-register instructions
    `ADD` `SUB` `SLL` `SLT` `SLTU` `XOR` `SRL` `SRA` `OR`  `AND`

#### RV64I word operations
    `ADDIW` `ADDW`   `SUBW`   `SLLW`   `SRLW`   `SRAW`

#### Exceptional instructions: this module assumes immediate values are inside operand_b_i
    `SLLI` `SRLI` `SRAI` `SLLIW` `SRLIW` `SRAIW`

### Planned Simplified Architecture

    operand_a_i ───┐
                   │
    operand_b_i ───┼──> ALU combinational logic ──> pipeline ──> result_o
                   │                                  │
    alu_op_i ──────┤                                  ├──> rd_addr_o
                   │                                  ├──> valid_o
    word_op_i ─────┘                                  └──> ready_o


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

module adn_riscv_exe_i64_alu
  import adn_riscv_pkg::*;
#(
    // Data width of the ALU, default is 64-bit for RV64I
    parameter int XLEN = 64
) (

    // ------------------------------------------------
    // required for pipelining
    // ------------------------------------------------

    // Clock signal for the pipeline registers
    input logic clk_i,
    // Asynchronous reset signal, active low
    input logic arst_ni,

    // ------------------------------------------------
    // ALU operation control
    // ------------------------------------------------

    // ALU operation control: selects the operation to be performed
    input rv_op_t alu_op_i,

    // ------------------------------------------------
    // Operands and destination register
    // ------------------------------------------------

    // ALU operand a value (rs1)
    input logic [XLEN-1:0] operand_a_i,
    // ALU operand b value (rs2 or sign-extended immediate)
    input logic [XLEN-1:0] operand_b_i,
    // Destination register index
    input logic [4:0] rd_addr_i,

    // ------------------------------------------------
    // Input handshake
    // ------------------------------------------------

    // Valid signal for input data
    input  logic valid_i,
    // Ready signal indicating ALU is ready to accept new data
    output logic ready_o,

    // ------------------------------------------------
    // ALU result
    // ------------------------------------------------

    // Computed ALU result
    output logic [XLEN-1:0] result_o,
    // Destination register index passed through the pipeline
    output logic [     4:0] rd_addr_o,

    // ------------------------------------------------
    // Output handshake
    // ------------------------------------------------

    // Valid signal for output data
    output logic valid_o,
    // Ready signal from the next stage
    input  logic ready_i

);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Intermediate result storage for 64-bit and 32-bit operations
  logic [  XLEN-1:0] result_xlen;
  logic [      31:0] result_word;

  // Control signal to determine if the operation is a subtraction
  logic              sub;  
  // Result of the adder/subtractor block
  logic [  XLEN-1:0] addsub_result;  
  // Final combinational result before pipeline
  logic [  XLEN-1:0] result_comb;  

  // Operand B modified for subtraction (two's complement)
  logic [  XLEN-1:0] operand_b_addsub;  

  // Pipeline data bus: combines result and destination register address
  logic [XLEN+5-1:0] pipe_data_in;  
  logic [XLEN+5-1:0] pipe_data_out;  


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Logic to detect subtraction operations
  always_comb begin
    sub = '0;
    case (alu_op_i)
      SUB, SUBW: sub = 1'b1;
      default:   ;
    endcase
  end

  // Adder/Subtractor functional block
  always_comb begin
    operand_b_addsub = sub ? (~operand_b_i) : operand_b_i;
    addsub_result = operand_a_i + operand_b_addsub + sub;
  end

  // Main ALU operation functional block
  always_comb begin : operation
    result_xlen = '0;
    result_word = '0;

    case (alu_op_i)
      ADD, ADDI, SUB: result_xlen = addsub_result;
      SLL, SLLI:      result_xlen = operand_a_i << operand_b_i[5:0];
      SLT, SLTI:      result_xlen = $signed(operand_a_i) < $signed(operand_b_i);
      SLTU, SLTIU:    result_xlen = operand_a_i < operand_b_i;
      XOR, XORI:      result_xlen = operand_a_i ^ operand_b_i;
      SRL, SRLI:      result_xlen = operand_a_i >> operand_b_i[5:0];
      SRA, SRAI:      result_xlen = $signed(operand_a_i) >>> operand_b_i[5:0];
      OR, ORI:        result_xlen = operand_a_i | operand_b_i;
      AND, ANDI:      result_xlen = operand_a_i & operand_b_i;
      SLLW, SLLIW:    result_word = operand_a_i[31:0] << operand_b_i[4:0];
      SRLW, SRLIW:    result_word = operand_a_i[31:0] >> operand_b_i[4:0];
      SRAW, SRAIW:    result_word = $signed(operand_a_i[31:0]) >>> operand_b_i[4:0];
      default:        ;
    endcase
  end : operation

  // Result selection block: handles sign extension for word-level operations
  always_comb begin
    case (alu_op_i)
      ADDW, ADDIW, SUBW: result_comb = {{(XLEN - 32) {addsub_result[31]}}, addsub_result[31:0]};
      SLLW, SLLIW, SRLW, SRLIW, SRAW, SRAIW: result_comb = {{32{result_word[31]}}, result_word};
      default: result_comb = result_xlen;
    endcase
  end

  // Prepare data for pipeline stage
  always_comb pipe_data_in = {rd_addr_i, result_comb};

  // Extract result and address from pipeline output
  always_comb result_o = pipe_data_out[XLEN-1:0];
  always_comb rd_addr_o = pipe_data_out[XLEN+5-1:XLEN];  

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Pipeline stage submodule to ensure timing closure
  adn_common_pipeline #(
      .DATA_WIDTH($bits(pipe_data_in))
  ) u_i64_pipeline (
      .arst_ni(arst_ni),
      .clk_i  (clk_i),
      .clear_i('0),

      .data_in_i      (pipe_data_in),
      .data_in_valid_i(valid_i),
      .data_in_ready_o(ready_o),

      .data_out_o      (pipe_data_out),
      .data_out_valid_o(valid_o),
      .data_out_ready_i(ready_i)
  );

endmodule
