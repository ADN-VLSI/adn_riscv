/*

@foez-bhai, write the purpose of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

@foez-bhai, describe the use case of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-14 | Foez Ahmed | Initial version                                        |
| 1.0      | 2026-08-14 | Foez Ahmed | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of ADN-VLSI/adn_template
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

// @foez-bhai, add comments to the parameters, ports
module adn_riscv_regfile #(
    parameter int NUM_RD     = 1,
    parameter int NUM_RS     = 2,
    parameter int NUM_REG    = 32,
    parameter int DATA_WIDTH = 64,
    parameter int NUM_ZERO   = 1,
    parameter bit LOCKS_EN   = 1
) (
    input logic arst_ni,
    input logic clk_i,

    input  logic [$clog2(NUM_REG)-1:0] rs_addr_i[NUM_RS],
    output logic [     DATA_WIDTH-1:0] rs_data_o[NUM_RS],

    input logic [$clog2(NUM_REG)-1:0] rd_addr_i[NUM_RD],
    input logic [     DATA_WIDTH-1:0] rd_data_i[NUM_RD],
    input logic                       rd_we_i  [NUM_RD],

    input  logic [$clog2(NUM_REG)-1:0] rl_addr_i[NUM_RD],
    input  logic                       rl_we_i  [NUM_RD],
    output logic [        NUM_REG-1:0] locks_o
);

  // @foez-bhai, add comments to the functional blocks and signals

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [DATA_WIDTH-1:0] regs     [NUM_REG];
  logic [DATA_WIDTH-1:0] regs_next[NUM_REG];

  if (LOCKS_EN) begin : gen_locks
    logic [NUM_REG-1:0] r;
    logic [NUM_REG-1:0] w;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    foreach (rs_data_o[i]) begin
      rs_data_o[i] = regs[rs_addr_i[i]];
      foreach (rd_data_i[j]) begin
        if ((rs_addr_i[i] == rd_addr_i[j]) && rd_we_i[j]) begin
          rs_data_o[i] = rd_data_i[j];
        end
      end
    end
  end

  always_comb begin
    regs_next = regs;
    foreach (rd_data_i[i]) begin
      for (int j = NUM_ZERO; j < NUM_REG; j++) begin
        if ((j == rd_addr_i[i]) && rd_we_i[i]) regs_next[j] = rd_data_i[i];
      end
    end
  end

  if (LOCKS_EN) begin
    always_comb begin
      gen_locks.w = gen_locks.r;

      foreach (rl_data_i[i]) begin
        for (int j = NUM_ZERO; j < NUM_REG; j++) begin
          if ((j == rl_addr_i[i]) && rl_we_i[i]) gen_locks.w[j] = '1;
        end
      end

      foreach (rd_data_i[i]) begin
        for (int j = NUM_ZERO; j < NUM_REG; j++) begin
          if ((j == rd_addr_i[i]) && rd_we_i[i]) gen_locks.w[j] = '0;
        end
      end
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (~arst_ni) regs <= '0;
    else regs <= regs_next;
  end

  if (LOCKS_EN) begin
    always_ff @(posedge clk_i or negedge arst_ni) begin
      if (~arst_ni) gen_locks.r <= '0;
      else gen_locks.r <= gen_locks.w;
    end
    always_comb locks_o = gen_locks.w;
  end else begin
    always_comb locks_o = '0;
  end

endmodule

