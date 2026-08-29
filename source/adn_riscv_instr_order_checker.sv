/*

### Purpose
The `adn_riscv_instr_order_checker` module is designed to manage instruction dependencies and execution ordering within a RISC-V pipeline. It tracks register locks and memory operation status to ensure that instructions are dispatched or stalled correctly, preventing hazards by monitoring register availability and memory busy states.

### Use Case
This module acts as a gatekeeper in the RISC-V pipeline's issue stage. Its primary use case is to prevent Read-After-Write (RAW) hazards and structural hazards related to memory access. By maintaining a scoreboard of register locks (`locks_i`) and monitoring the status of memory operations (`mem_busy_i`), the module determines if an incoming instruction (`pl_valid_i`) can proceed to execution or must be stalled. It is essential for out-of-order execution logic or high-performance in-order pipelines where dependency tracking is required to maintain architectural correctness.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-29 | Foez Ahmed      | Initial version                                        |
| 1.0      | 2026-08-29 | Foez Ahmed      | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_riscv_instr_order_checker #(
    parameter int NR = 32 // Number of registers to track
) (
    input logic pl_valid_i, // Pipeline stage valid signal

    input logic                  blocking_i, // Signal to force stall all registers
    input logic [$clog2(NR)-1:0] rd_i,       // Destination register index
    input logic [        NR-1:0] reg_req_i,  // Register request mask

    input  logic [NR-1:0] locks_i, // Current register lock status
    output logic [NR-1:0] locks_o, // Updated register lock status

    input  logic mem_op_i,   // Memory operation flag
    input  logic mem_busy_i, // Memory busy status input
    output logic mem_busy_o, // Memory busy status output

    output logic arb_req_o // Arbitration request output
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Update memory busy status based on current operation and existing busy state
  always_comb mem_busy_o = mem_busy_i | (mem_op_i && mem_busy_i);

  // Determine if the pipeline can proceed based on memory availability and register dependencies
  always_comb
    arb_req_o = pl_valid_i  ?
                            ((mem_op_i & mem_busy_i) ?
                                                     '0
                                                     : (pl_valid_i & ~(|(locks_i & reg_req_i))))
                            : '0;

  // Logic to update the register scoreboard (locks) based on pipeline activity
  always_comb begin
    logic [NR-1:0] locks_mask;
    locks_mask = '0;
    locks_o = locks_i;
    if (pl_valid_i) begin
      if (blocking_i) begin
        // Stall all registers if blocking signal is asserted
        locks_o = '1;
      end else begin
        // Set lock for the destination register
        locks_mask[rd_i] = '1;
        locks_o |= locks_mask;
      end
    end
  end

endmodule
