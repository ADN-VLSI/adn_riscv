/*

# Purpose
This module implements a high-performance 64-bit integer multiplier for the RISC-V architecture. It supports standard multiplication (MUL), high-part multiplication (MULH, MULHSU, MULHU), and word-sized multiplication (MULW) operations using a multi-stage pipelined architecture.

### Use Case
This module is designed to be integrated into the execution stage of a 64-bit RISC-V processor pipeline. It serves as the primary arithmetic unit for integer multiplication instructions. By utilizing a multi-stage pipeline, it balances high throughput with timing constraints, allowing the processor to handle complex multiplication operations without stalling the execution flow. It is particularly useful in compute-intensive applications requiring frequent 64-bit arithmetic operations.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-09-01 | Foez Ahmed | Initial version                                        |
| 1.0      | 2026-09-01 | Foez Ahmed | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_riscv_exe_m64_mult (
    input logic clk_i,          // Clock input
    input logic arst_ni,        // Asynchronous reset, active low
    
    input  logic        MUL_i,      // Multiply operation signal
    input  logic        MULH_i,     // Multiply high operation signal
    input  logic        MULHSU_i,   // Multiply high signed-unsigned operation signal
    input  logic        MULHU_i,    // Multiply high unsigned operation signal
    input  logic        MULW_i,     // Multiply word operation signal
    input  logic [63:0] rs1_i,      // Source register 1 input
    input  logic [63:0] rs2_i,      // Source register 2 input
    input  logic [5:0]  rd_i,       // Destination register input
    input  logic        valid_i,    // Valid input signal
    output logic        ready_o,    // Ready output signal
    
    output logic [63:0] wr_data_o,  // Write data output
    output logic [ 1:0] wr_size_o,  // Write size output
    output logic [ 5:0] wr_addr_o,  // Write address output
    output logic        valid_o,    // Valid output signal
    input  logic        ready_i     // Ready input signal
);
    
  //////////////////////////////////////////////////////////////////////////////////////////////////
  //-SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Pipeline handshake signals
  logic q0_valid; // Valid signal for stage 0
  logic q0_ready; // Ready signal for stage 0

  logic q0_q1_valid; // Valid signal between stage 0 and 1
  logic q0_q1_ready; // Ready signal between stage 0 and 1

  logic q1_q2_valid; // Valid signal between stage 1 and 2
  logic q1_q2_ready; // Ready signal between stage 1 and 2

  //////////////////////////////////////////////////////////////////////////////////////////////////
  //        _            _ _                       ___
  //  _ __ (_)_ __   ___| (_)_ __   ___      __ _ / _ \
  // | '_ \| | '_ \ / _ \ | | '_ \ / _ \    / _` | | | |
  // | |_) | | |_) |  __/ | | | | |  __/   | (_| | |_| |
  // | .__/|_| .__/ \___|_|_|_| |_|\___|    \__, |\___/
  // |_|     |_|                               |_|
  //
  //////////////////////////////////////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////
  // FUNC IDENTIFY
  ////////////////////////////////////////////////

  // Check if any multiplication operation is active
  logic this_module;
  assign this_module = MUL_i | MULH_i | MULHSU_i | MULHU_i | MULW_i;

  ////////////////////////////////////////////////
  // INITIAL VALID READY
  ////////////////////////////////////////////////

  // Control logic for input handshake
  assign q0_valid = this_module & valid_i;
  assign ready_o = this_module & q0_ready;

  ////////////////////////////////////////////////
  // MULTIPLIER, MULTIPLICAND, NEGATIVE, WORD, RD
  ////////////////////////////////////////////////

  // Operands and control flags for multiplication
  logic [63:0] multiplier;
  logic [63:0] multiplicand;
  logic        negative;

  always_comb begin
    multiplier   = rs2_i;
    multiplicand = rs1_i;
    negative     = '0;

    // Handle word-sized multiplication sign extension
    if (MULW_i) begin
      multiplier   = {{32{rs2_i[31]}}, rs2_i[31:0]};
      multiplicand = {{32{rs1_i[31]}}, rs1_i[31:0]};
    end

    // Determine sign for signed multiplication
    if (MUL_i | MULH_i | MULW_i) begin
      negative = multiplier[63] ^ multiplicand[63];
      if (multiplier[63]) multiplier = ~multiplier + 1;
      if (multiplicand[63]) multiplicand = ~multiplicand + 1;
    end else if (MULHSU_i) begin
      negative = multiplicand[63];
      if (multiplicand[63]) multiplicand = ~multiplicand + 1;
    end

  end

  // Flags for operation type
  logic upper;
  always_comb upper = MULH_i | MULHSU_i | MULHU_i;

  logic word;
  always_comb word = MULW_i;

  // Precomputed partial products
  logic [67:0] res_0001;
  logic [67:0] res_0011;
  logic [67:0] res_0111;
  logic [67:0] res_0101;
  logic [67:0] res_1001;
  logic [67:0] res_1011;
  logic [67:0] res_1101;
  logic [67:0] res_1111;

  always_comb res_0001 = multiplicand;
  always_comb res_0011 = {res_0001, 1'b0} + res_0001;
  always_comb res_0111 = {res_0001, 2'b0} + res_0011;
  always_comb res_0101 = {res_0001, 2'b0} + res_0001;
  always_comb res_1001 = {res_0001, 3'b0} + res_0001;
  always_comb res_1011 = {res_0001, 1'b0} + res_1001;
  always_comb res_1101 = {res_0001, 2'b0} + res_1001;
  always_comb res_1111 = {res_0011, 2'b0} + res_0011;

  // Pipeline stage 0 registers
  logic [5:0]  rd_q0;
  logic        word_q0;
  logic        upper_q0;
  logic        negative_q0;
  logic [67:0] res_0001_q0;
  logic [67:0] res_0011_q0;
  logic [67:0] res_0111_q0;
  logic [67:0] res_0101_q0;
  logic [67:0] res_1001_q0;
  logic [67:0] res_1011_q0;
  logic [67:0] res_1101_q0;
  logic [67:0] res_1111_q0;
  logic [63:0] multiplier_q0;

  // Stage 0 pipeline register
  adn_common_pipeline #(
      .DATA_WIDTH($bits({rd_q0, word_q0, upper_q0, negative_q0,
                res_0001_q0, res_0011_q0, res_0111_q0, res_0101_q0,
                res_1001_q0, res_1011_q0, res_1101_q0, res_1111_q0,
                multiplier_q0}))
  ) u_q0 (
      .arst_ni(arst_ni),
      .clk_i(clk_i),
      .clear_i('0),

      .data_in_i({rd_i, word, upper, negative,
                  res_0001, res_0011, res_0111, res_0101,
                  res_1001, res_1011, res_1101, res_1111,
                  multiplier}),
      .data_in_valid_i(q0_valid), .data_in_ready_o(q0_ready),

      .data_out_o({rd_q0, word_q0, upper_q0, negative_q0,
                  res_0001_q0, res_0011_q0, res_0111_q0, res_0101_q0,
                  res_1001_q0, res_1011_q0, res_1101_q0, res_1111_q0,
                  multiplier_q0}),
      .data_out_valid_o(q0_q1_valid), .data_out_ready_i(q0_q1_ready)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  //        _            _ _                      _
  //  _ __ (_)_ __   ___| (_)_ __   ___      __ _/ |
  // | '_ \| | '_ \ / _ \ | | '_ \ / _ \    / _` | |
  // | |_) | | |_) |  __/ | | | | |  __/   | (_| | |
  // | .__/|_| .__/ \___|_|_|_| |_|\___|    \__, |_|
  // |_|     |_|                               |_|
  //
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Crossbar and extension logic for partial product selection
  logic [15:0][67:0] ext68_res;
  logic [15:0][67:0] xbar_out;

  always_comb ext68_res['b0000] = '0;
  always_comb ext68_res['b0001] = res_0001_q0;
  always_comb ext68_res['b0010] = {res_0001_q0, 1'b0};
  always_comb ext68_res['b0011] = res_0011_q0;
  always_comb ext68_res['b0100] = {res_0001_q0, 2'b0};
  always_comb ext68_res['b0101] = res_0101_q0;
  always_comb ext68_res['b0110] = {res_0011_q0, 1'b0};
  always_comb ext68_res['b0111] = res_0111_q0;
  always_comb ext68_res['b1000] = {res_0001_q0, 3'b0};
  always_comb ext68_res['b1001] = res_1001_q0;
  always_comb ext68_res['b1010] = {res_0101_q0, 1'b0};
  always_comb ext68_res['b1011] = res_1011_q0;
  always_comb ext68_res['b1100] = {res_0011_q0, 2'b0};
  always_comb ext68_res['b1101] = res_1101_q0;
  always_comb ext68_res['b1110] = {res_0111_q0, 1'b0};
  always_comb ext68_res['b1111] = res_1111_q0;

  // Crossbar submodule to select partial products
  xbar #(
      .NUM_INPUT (16),
      .NUM_OUTPUT(16),
      .DATA_WIDTH(68)
  ) u_xbar (
      .input_vector_i(ext68_res),
      .output_vector_o(xbar_out),
      .select_vector_i(multiplier_q0)
  );

  logic [15:0][79:0] ext80;

  always_comb begin
    for (int i = 0; i < 16; i++) begin
      ext80[i] = xbar_out[i];
    end
  end

  // Summation of partial products
  logic [3:0][79:0] res80;

  always_comb begin
    for (int i = 0; i < 4; i++) begin
      res80[i] =   {ext80[4*i+3],12'b0} + {ext80[4*i+2],8'b0} + {ext80[4*i+1],4'b0} + ext80[4*i];
    end
  end

  // Pipeline stage 1 registers
  logic [5:0]       rd_q1;
  logic             word_q1;
  logic             upper_q1;
  logic             negative_q1;
  logic [3:0][79:0] res80_q1;

  // Stage 1 pipeline register
  adn_common_pipeline #(
      .DATA_WIDTH($bits({rd_q1, word_q1, upper_q1, negative_q1, res80_q1}))
  ) u_q1 (
      .arst_ni(arst_ni),
      .clk_i(clk_i),
      .clear_i('0),

      .data_in_i({rd_q0, word_q0, upper_q0, negative_q0, res80}),
      .data_in_valid_i(q0_q1_valid), .data_in_ready_o(q0_q1_ready),

      .data_out_o({rd_q1, word_q1, upper_q1, negative_q1, res80_q1}),
      .data_out_valid_o(q1_q2_valid), .data_out_ready_i(q1_q2_ready)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  //        _            _ _                      ____
  //  _ __ (_)_ __   ___| (_)_ __   ___      __ _|___ \
  // | '_ \| | '_ \ / _ \ | | '_ \ / _ \    / _` | __) |
  // | |_) | | |_) |  __/ | | | | |  __/   | (_| |/ __/
  // | .__/|_| .__/ \___|_|_|_| |_|\___|    \__, |_____|
  // |_|     |_|                               |_|
  //
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Final accumulation and result formatting
  logic [3:0][127:0] res128;
  logic [127:0] final_sum;
  logic [127:0] semi_final_res;
  logic [63:0] final_res;

  always_comb begin
    for (int i = 0; i < 4; i++) begin
      res128[i] = res80_q1[i];
    end
  end

  // Final summation logic
  always_comb final_sum = {res128[3], 48'b0} + {res128[2], 32'b0} + {res128[1], 16'b0} + res128[0];

  // Apply sign correction
  always_comb semi_final_res = negative_q1 ? ~final_sum + 1 : final_sum;

  // Select high or low part of result
  always_comb final_res = upper_q1 ? semi_final_res[127:64] : semi_final_res[63:0];

  logic word_q2;

  // Stage 2 pipeline register (Output stage)
  adn_common_pipeline #(
      .DATA_WIDTH($bits({wr_data_o, word_q2, wr_addr_o}))
  ) u_q2 (
      .arst_ni(arst_ni),
      .clk_i(clk_i),
      .clear_i('0),

      .data_in_i({final_res, word_q1, rd_q1}),
      .data_in_valid_i(q1_q2_valid), .data_in_ready_o(q1_q2_ready),

      .data_out_o({wr_data_o, word_q2, wr_addr_o}),
      .data_out_valid_o(valid_o), .data_out_ready_i(ready_i)
  );

  // Set write size based on word operation
  always_comb wr_size_o = word_q2 ? 2'b10 : 2'b11;

endmodule
