/*

@foez-bhai, write the purpose of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

@foez-bhai, describe the use case of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-09-08 | Foez Ahmed      | Initial version                                        |
| 1.0      | 2026-09-08 | Foez Ahmed      | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

//  typedef struct packed {
//    logic [ 5:0] addr;
//    logic [63:0] data;
//    logic [ 1:0] size;
//    logic        sign;
//  } write_back_t;


// @foez-bhai, add comments to the parameters, ports
module adn_riscv_wb_mux #(
    parameter type write_back_t = logic,
    parameter int NUM_REQ = 4,
    parameter bit HIGH_INDEX_PRIORITY = 0
) (
    input  write_back_t [NUM_REQ-1:0] wb_i,
    input  logic        [NUM_REQ-1:0] req_i,
    output logic        [NUM_REQ-1:0] gnt_o,

    output logic [ 5:0] rd_addr_o,
    output logic [63:0] rd_data_o,
    output logic        rd_en_o
);

  // @foez-bhai, add comments to the functional blocks, signals, and submodules

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [$clog2(NUM_REQ)-1:0] port_idx;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb rd_addr_o = wb_i[port_idx].addr;

  always_comb begin
    logic [63:0] data;
    data = wb_i[port_idx].data;
    case ({
      wb_i[port_idx].size, wb_i[port_idx].sign
    })
      3'b000:  data = {56'b0, wb_i[port_idx].data[7:0]};
      3'b001:  data = {{56{wb_i[port_idx].data[7]}}, wb_i[port_idx].data[7:0]};
      3'b010:  data = {48'b0, wb_i[port_idx].data[15:0]};
      3'b011:  data = {{48{wb_i[port_idx].data[15]}}, wb_i[port_idx].data[15:0]};
      3'b100:  data = {32'b0, wb_i[port_idx].data[31:0]};
      3'b101:  data = {{32{wb_i[port_idx].data[31]}}, wb_i[port_idx].data[31:0]};
      default: data = wb_i[port_idx].data;
    endcase
    rd_data_o = data;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_fixed_priority_arbiter #(
      .NUM_REQ(NUM_REQ),
      .HIGH_INDEX_PRIORITY(HIGH_INDEX_PRIORITY)
  ) u_arbiter (
      .req_i       (req_i),
      .allow_req_i ('1),
      .gnt_o       (gnt_o),
      .addr_o      (port_idx),
      .addr_valid_o(rd_en_o)
  );

endmodule
