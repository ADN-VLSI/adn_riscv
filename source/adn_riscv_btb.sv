/*

### Purpose
The `adn_riscv_btb` module implements a Branch Target Buffer (BTB) designed to predict the outcomes of branch and jump instructions in a RISC-V processor. It caches target addresses for previously executed branches, allowing the pipeline to fetch the correct instruction stream early and minimize performance penalties associated with control flow changes.

### Use Case
This module is utilized in the instruction fetch stage of a RISC-V pipeline. When the processor encounters a branch or jump instruction, the BTB is queried using the current program counter (PC). If a match is found, the module provides the predicted target address, allowing the fetch unit to redirect the instruction stream immediately. If the prediction is incorrect or a new branch is encountered, the module updates its internal buffer using a state-based replacement policy to improve future prediction accuracy.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-29 | Foez Ahmed | Initial version                                        |
| 1.0      | 2026-08-29 | Foez Ahmed | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_riscv_btb #(
    parameter int NUM_BTB = 32, // Number of entries in the Branch Target Buffer
    parameter int XLEN    = 64  // Data width of the processor
) (
    input logic clk_i,   // Clock input
    input logic arst_ni, // Asynchronous reset input

    input logic [XLEN-1:0] current_addr_i,  // Current address (EXEC) input
    input logic [XLEN-1:0] next_addr_i,     // Next address (EXEC) input
    input logic [XLEN-1:0] pc_i,            // Program counter (IF) input
    input logic            is_jump_i,       // Is jump/branch (IF) input

    output logic            match_found_o,  // Found match in buffer output
    output logic            flush_o,        // Pipeline flush signal output
    output logic [XLEN-1:0] next_pc_o       // Next program counter (in case of jump) output
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  typedef logic [XLEN-1:2] reduced_addr_t;  // Reduced address type (excluding last 2 bits)

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Buffer to store current addresses
  reduced_addr_t current_addr_buffer[NUM_BTB];
  // Buffer to store next addresses
  reduced_addr_t next_addr_buffer[NUM_BTB];
  // Valid bits for buffer entries
  logic [NUM_BTB-1:0] valid_buffer;
  // Strength bits for buffer entries
  logic [NUM_BTB-1:0] strength_buffer;
  // Valid + Strength bits for buffer entries
  logic [1:0] valid_strength[NUM_BTB];
  // Counter for buffer entries
  logic [$clog2(NUM_BTB)-1:0] buffer_counter;

  // Write enable signals for buffer entries
  logic [NUM_BTB-1:0] write_enable;
  // Flag to check if next address is not equal to current address + 4
  logic addr_mismatch;

  // Match signals for program counter and current address
  logic [NUM_BTB-1:0] pc_addr_match;
  // Index of matching row in buffer
  logic [$clog2(NUM_BTB)-1:0] match_index;
  // Index of empty row in buffer
  logic [$clog2(NUM_BTB)-1:0] empty_index;
  // Index of row to write in buffer
  logic [$clog2(NUM_BTB)-1:0] write_index;
  // Input and Output state for State Decider - {valid, strength}
  logic [1:0] input_state, output_state;

  // State Definitions
  parameter logic [1:0] INVALID = 2'b00, VALID_WEAK = 2'b10, VALID_STRONG = 2'b11;

  // Flag to indicate if an empty row is found
  logic empty_found;
  // Flag to indicate if a match is found
  logic match_found;
  // Table update event
  logic update_table;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Check for matches between program counter and current addresses in buffer
  for (genvar i = 0; i < NUM_BTB; i++) begin : g_pc_addr_match
    always_comb pc_addr_match[i] = valid_buffer[i] & (pc_i[XLEN-1:2] == current_addr_buffer[i]);
  end

  // Output match_found signal if a match is found or table is updated
  always_comb match_found_o = match_found | flush_o;

  // Output next program counter based on table update or buffer content
  always_comb next_pc_o = flush_o ? next_addr_i : {next_addr_buffer[match_index], 2'b00};

  // Check if next address is not equal to current address + 4
  always_comb addr_mismatch = (current_addr_i + 4 != next_addr_i);

  // Flush buffer if there's a new jump or buffer entry is incorrect
  always_comb flush_o = is_jump_i & (addr_mismatch ^ match_found);

  // Update table if there's a flush EXCEPT when VALID_STRONG
  always_comb update_table = flush_o & ~(&input_state);

  // Determine the row index to write in buffer
  always_comb
    write_index = addr_mismatch ? (empty_found ? empty_index : buffer_counter) : match_index;

  for (genvar i = 0; i < NUM_BTB; i++) begin : g_valid_strength
    assign valid_strength[i] = {valid_buffer[i], strength_buffer[i]};
  end

  // Multiplexer for choosing input state for FSM
  always_comb input_state = valid_strength[write_index];

  // State Decider
  always_comb begin
    case (input_state)
      INVALID:      output_state = addr_mismatch ? VALID_STRONG : INVALID;
      VALID_WEAK:   output_state = addr_mismatch ? VALID_STRONG : INVALID;
      VALID_STRONG: output_state = addr_mismatch ? VALID_STRONG : VALID_WEAK;
      default:      output_state = INVALID;
    endcase
  end

  always_comb begin
    write_enable = '0;
    write_enable[write_index] = update_table;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Instance of the encoder module to find matching row index
  adn_common_encoder #(
      .NUM_WIRE(NUM_BTB)
  ) pc_addr_match_find (
      .wire_in(pc_addr_match),
      .index_o(match_index),
      .index_valid_o(match_found)
  );

  // Instance of the priority encoder module to find empty row index
  adn_common_priority_encoder #(
      .NUM_WIRE(NUM_BTB),
      .HIGH_INDEX_PRIORITY(0)
  ) empty_row_find (
      .d_i(~valid_buffer),
      .addr_o(empty_index),
      .addr_valid_o(empty_found)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Sequential logic to update buffer entries
  for (genvar i = 0; i < NUM_BTB; i++) begin : g_regs
    always @(posedge clk_i) begin
      if (write_enable[i]) begin
        current_addr_buffer[i] <= current_addr_i[XLEN-1:2];
      end
    end

    always @(posedge clk_i) begin
      if (write_enable[i]) begin
        next_addr_buffer[i] <= next_addr_i[XLEN-1:2];
      end
    end

    // Sequential logic to update valid bits for buffer entries
    always_ff @(posedge clk_i or negedge arst_ni) begin
      if (~arst_ni) begin
        valid_buffer[i] <= '0;
      end else if (write_enable[i]) begin
        valid_buffer[i] <= output_state[1];
      end
    end

    // Sequential logic to update strength bits for buffer entries
    always_ff @(posedge clk_i or negedge arst_ni) begin
      if (~arst_ni) begin
        strength_buffer[i] <= '0;
      end else if (write_enable[i]) begin
        strength_buffer[i] <= output_state[0];
      end
    end
  end

  // Sequential logic to update counter
  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (~arst_ni) begin
      buffer_counter <= '0;
    end else begin
      if (~empty_found & is_jump_i) buffer_counter <= buffer_counter + 1;
    end
  end

endmodule
