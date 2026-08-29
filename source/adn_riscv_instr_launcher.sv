/*

# Purpose
The `adn_riscv_instr_launcher` module serves as a high-performance instruction dispatch and ordering unit for a RISC-V processor. It manages a multi-stage pipeline structure that buffers incoming decoded instructions, performs dependency checking via order checkers, and uses a fixed-priority arbiter to ensure instructions are launched to the execution units in the correct order while maintaining data integrity and handling resource locks.

# Use Case
The `adn_riscv_instr_launcher` is designed to be placed between the instruction decoder and the execution units in a RISC-V pipeline. Its primary use cases include:
- **Instruction Buffering**: Providing a multi-stage buffer to decouple the decode stage from execution, allowing for smoother instruction flow.
- **Dependency Management**: Ensuring that instructions with data dependencies (e.g., register hazards) are held back until their required operands are available.
- **In-Order Dispatch**: Guaranteeing that instructions are issued to execution units in the correct program order, even if they arrive at the launcher out of sequence or are delayed by resource locks.
- **Resource Arbitration**: Managing access to shared execution resources by arbitrating between multiple pending instructions across different pipeline stages.

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

module adn_riscv_instr_launcher #(
    parameter type decoded_instr_t = logic, // Data type for the decoded instruction
    parameter int  NR              = 32,    // Number of registers to track for dependencies
    parameter int  NOS             = 8      // Number of pipeline stages
) (
    input logic arst_ni,  // Asynchronous reset, active low
    input logic clk_i,    // Clock input
    input logic clear_i,  // Synchronous clear signal

    input  decoded_instr_t instr_in_i,        // Incoming decoded instruction
    input  logic           instr_in_valid_i,  // Valid signal for incoming instruction
    output logic           instr_in_ready_o,  // Ready signal for incoming instruction

    input logic [NR-1:0] locks_i,  // Input lock signals for registers from regfile

    output decoded_instr_t instr_out_o,        // Outgoing decoded instruction
    output logic           instr_out_valid_o,  // Valid signal for outgoing instruction
    input  logic           instr_out_ready_i   // Ready signal for outgoing instruction
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [NOS:0] clears;  // Clear signals for individual pipeline stages

  decoded_instr_t [NOS:0] pl_ins;        // Pipeline stage input data buses
  logic [NOS:0]           pl_ins_valid;  // Pipeline stage input valid flags
  logic [NOS:0]           pl_ins_ready;  // Pipeline stage input ready backpressure
  decoded_instr_t [NOS:0] pl_outs;       // Pipeline stage output data buses
  logic [NOS:0]           pl_outs_valid; // Pipeline stage output valid flags
  logic [NOS:0]           pl_outs_ready; // Pipeline stage output ready backpressure

  logic [NR-1:0] locks[NOS+2];  // Propagated register lock status chain
  logic          mem_busy[NOS+2]; // Propagated memory busy status chain

  logic [NOS:0] arb_req;  // Arbitration requests from each stage
  logic [NOS:0] arb_gnt;  // Arbitration grants for each stage

  logic [$clog2(NOS+1)-1:0] gnt_idx;  // Encoded index of the granted pipeline stage

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Assign input instruction to the first pipeline stage
  always_comb pl_ins[0] = instr_in_i;
  always_comb pl_ins_valid[0] = instr_in_valid_i;
  always_comb instr_in_ready_o = pl_ins_ready[0];

  // Initialize lock signals
  always_comb locks[0] = locks_i;
  always_comb mem_busy[0] = '0;

  // Assign output instruction and valid signal based on granted request index
  always_comb instr_out_o = pl_outs[gnt_idx];

  always_comb pl_outs_ready = arb_gnt;

  // Generate clear signals for pipeline stages
  always_comb begin
    for (int i = 0; i < NOS; i++) begin : g_clears
      clears[i] = clears[i+1] & (gnt_idx != (i + 1));
    end
    clears[NOS] = clear_i;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Generate pipeline stages for instruction buffering
  for (genvar i = 0; i < NOS; i++) begin : g_splits
    adn_common_pipeline_split #(
        .DATA_WIDTH($bits(instr_in_i))
    ) u_pipeline_split (
        .arst_ni                   (arst_ni),
        .clk_i                     (clk_i),
        .clear_i                   (clears[NOS-1]),
        .data_in_i                 (pl_ins[i]),
        .data_in_valid_i           (pl_ins_valid[i]),
        .data_in_ready_o           (pl_ins_ready[i]),
        .data_out_primary_o        (pl_outs[NOS-i]),
        .data_out_primary_valid_o  (pl_outs_valid[NOS-i]),
        .data_out_primary_ready_i  (pl_outs_ready[NOS-i]),
        .data_out_secondary_o      (pl_ins[i+1]),
        .data_out_secondary_valid_o(pl_ins_valid[i+1]),
        .data_out_secondary_ready_i(pl_ins_ready[i+1])
    );
  end

  // Final pipeline stage buffer
  adn_common_pipeline #(
      .DATA_WIDTH($bits(instr_in_i))
  ) u_pipeline_final (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .clear_i         (clears[0]),
      .data_in_i       (pl_ins[NOS]),
      .data_in_valid_i (pl_ins_valid[NOS]),
      .data_in_ready_o (pl_ins_ready[NOS]),
      .data_out_o      (pl_outs[0]),
      .data_out_valid_o(pl_outs_valid[0]),
      .data_out_ready_i(pl_outs_ready[0])
  );

  // Generate dependency checkers for each pipeline stage
  for (genvar i = 0; i < NOS + 1; i++) begin : g_checkers
    adn_riscv_instr_order_checker #() u_order_checker (
        .pl_valid_i(pl_outs_valid[i]),
        .blocking_i(pl_outs[i].blocking),
        .rd_i      (pl_outs[i].rd),
        .reg_req_i (pl_outs[i].reg_req),
        .locks_i   (locks[i]),
        .locks_o   (locks[i+1]),
        .mem_op_i  (pl_outs[i].mem_op),
        .mem_busy_i(mem_busy[i]),
        .mem_busy_o(mem_busy[i+1]),
        .arb_req_o (arb_req[i])
    );
  end

  // Fixed priority arbiter for arbitration among pipeline stages
  adn_common_fixed_priority_arbiter #(
      .NUM_REQ            (NOS + 1),
      .HIGH_INDEX_PRIORITY(0)
  ) u_fixed_priority_arbiter (
      .allow_req_i(instr_out_ready_i),
      .req_i      (arb_req),
      .gnt_o      (arb_gnt)
  );

  // Encoder for determining the granted request index
  adn_common_encoder #(
      .NUM_WIRE(NOS + 1)
  ) u_encoder (
      .wire_in(arb_gnt),
      .index_o(gnt_idx),
      .index_valid_o(instr_out_valid_o)
  );

endmodule
