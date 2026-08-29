/*

@foez-bhai, write the purpose of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

@foez-bhai, describe the use case of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

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

// @foez-bhai, add comments to the parameters, ports
module adn_riscv_instr_order_checker #(
    parameter int NR = 32
) (
    input logic pl_valid_i,

    input logic                  blocking_i,
    input logic [$clog2(NR)-1:0] rd_i,
    input logic [        NR-1:0] reg_req_i,

    input  logic [NR-1:0] locks_i,
    output logic [NR-1:0] locks_o,

    input  logic mem_op_i,
    input  logic mem_busy_i,
    output logic mem_busy_o,

    output logic arb_req_o
);

  // @foez-bhai, add comments to the functional blocks, signals, and submodules

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb mem_busy_o = mem_busy_i | (mem_op_i && mem_busy_i);

  always_comb
    arb_req_o = pl_valid_i  ?
                            ((mem_op_i & mem_busy_i) ?
                                                     '0
                                                     : (pl_valid_i & ~(|(locks_i & reg_req_i))))
                            : '0;

  always_comb begin
    logic [NR-1:0] locks_mask;
    locks_mask = '0;
    locks_o = locks_i;
    if (pl_valid_i) begin
      if (blocking_i) begin
        locks_o = '1;
      end else begin
        locks_mask[rd_i] = '1;
        locks_o |= locks_mask;
      end
    end
  end

endmodule

