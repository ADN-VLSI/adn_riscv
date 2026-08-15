/*

### Purpose
This module implements a parameterized RISC-V register file supporting multiple read and write
ports, optional register locking mechanisms, and configurable data widths. It provides asynchronous
reset capabilities and handles transparent read-after-write behavior via internal combinatorial 
forwarding logic.

### Use Case
The `adn_riscv_regfile` is designed to serve as the primary architectural state storage in a RISC-V
processor pipeline. Its primary use cases include:
- **General Purpose Register (GPR) File:** Providing high-speed access for integer arithmetic units.
- **Pipeline Integration:** Supporting multiple read/write ports to facilitate concurrent
instruction dispatch and write-back.
- **Hazard Management:** Utilizing internal combinatorial forwarding to ensure that read operations 
immediately reflect pending writes within the same cycle.
- **Resource Locking:** Enabling atomic operations or synchronization primitives by tracking
register availability via the optional locking mechanism.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-14 | Foez Ahmed      | Initial version                                        |
| 1.0      | 2026-08-14 | Foez Ahmed      | Stable release                                         |
| 1.1      | 2026-08-15 | Foez Ahmed      | Added optional output pipelining feature               |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of ADN-VLSI/adn_template
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_riscv_regfile #(
    parameter int NUM_RD     = 1,   // Number of write ports
    parameter int NUM_RS     = 2,   // Number of read ports
    parameter int NUM_REG    = 32,  // Number of registers in the file
    parameter int DATA_WIDTH = 64,  // Width of each register in bits
    parameter int NUM_ZERO   = 1,   // Number of hardwired zero registers
    parameter bit OUTPUT_PL  = 0,   // @foez-bhai, add comments
    parameter bit LOCKS_EN   = 1    // Enable register locking mechanism
) (
    input logic arst_ni,  // Asynchronous reset, active low
    input logic clk_i,    // System clock

    input  logic [$clog2(NUM_REG)-1:0] rs_addr_i[NUM_RS],  // Read source addresses
    output logic [     DATA_WIDTH-1:0] rs_data_o[NUM_RS],  // Read source data outputs

    input logic [$clog2(NUM_REG)-1:0] rd_addr_i[NUM_RD],  // Write destination addresses
    input logic [     DATA_WIDTH-1:0] rd_data_i[NUM_RD],  // Write destination data inputs
    input logic                       rd_we_i  [NUM_RD],  // Write enable signals

    input  logic [$clog2(NUM_REG)-1:0] rl_addr_i[NUM_RD],  // Register lock addresses
    input  logic                       rl_we_i  [NUM_RD],  // Register lock enable signals
    output logic [        NUM_REG-1:0] locks_o             // Current lock status vector
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [NUM_REG-1:0][DATA_WIDTH-1:0] regs;  // Register file storage array
  logic [NUM_REG-1:0][DATA_WIDTH-1:0] regs_next;  // Next state for register file

  if (LOCKS_EN) begin : gen_locks
    logic [NUM_REG-1:0] r;  // Current lock status register
    logic [NUM_REG-1:0] w;  // Next lock status logic
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Read port logic without forwarding
  if (OUTPUT_PL) always_comb foreach (rs_data_o[i]) rs_data_o[i] = regs[rs_addr_i[i]];
  // Read port logic with forwarding support
  else
    always_comb foreach (rs_data_o[i]) rs_data_o[i] = regs_next[rs_addr_i[i]];

  // Write port logic for register updates
  always_comb begin
    regs_next = regs;
    foreach (rd_data_i[i]) begin
      // Skip zero register (index 0)
      for (int j = NUM_ZERO; j < NUM_REG; j++) begin
        if ((j == rd_addr_i[i]) && rd_we_i[i]) begin
          regs_next[j] = rd_data_i[i];
        end
      end
    end
  end

  // Register locking logic
  if (LOCKS_EN) begin
    always_comb begin
      gen_locks.w = gen_locks.r;

      // Set lock on request
      foreach (rl_addr_i[i]) begin
        for (int j = NUM_ZERO; j < NUM_REG; j++) begin
          if ((j == rl_addr_i[i]) && rl_we_i[i]) begin
            gen_locks.w[j] = '1;
          end
        end
      end

      // Clear lock on write-back
      foreach (rd_data_i[i]) begin
        for (int j = NUM_ZERO; j < NUM_REG; j++) begin
          if ((j == rd_addr_i[i]) && rd_we_i[i]) begin
            gen_locks.w[j] = '0;
          end
        end
      end
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Register file state update
  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (~arst_ni) regs <= '0;
    else regs <= regs_next;
  end

  // Lock status state update
  if (LOCKS_EN) begin
    always_ff @(posedge clk_i or negedge arst_ni) begin
      if (~arst_ni) gen_locks.r <= '0;
      else gen_locks.r <= gen_locks.w;
    end
    if (OUTPUT_PL) always_comb locks_o = gen_locks.r;
    else always_comb locks_o = gen_locks.w;
  end else begin
    always_comb locks_o = '0;
  end

endmodule
