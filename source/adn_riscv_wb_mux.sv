/*

### Purpose
This module functions as a Write-Back (WB) multiplexer for the ADN-RISC-V core. It aggregates multiple write-back requests from various pipeline stages or functional units, arbitrates between them based on a fixed priority scheme, and routes the selected data and address to the register file write port, including necessary sign-extension logic.

### Use Case
The `adn_riscv_wb_mux` is utilized at the final stage of the pipeline where multiple execution units (e.g., ALU, Load-Store Unit, Multiplier) attempt to write results back to the register file simultaneously. It ensures that only one valid result is committed per cycle based on the configured priority, preventing structural hazards and ensuring data integrity during the write-back phase.

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


module adn_riscv_wb_mux #(
    parameter type write_back_t = logic,          // Data structure for WB request
    parameter int NUM_REQ = 4,                    // Number of input request ports
    parameter bit HIGH_INDEX_PRIORITY = 0         // Priority scheme: 0=Low index, 1=High index
) (
    input  write_back_t [NUM_REQ-1:0] wb_i,       // Array of WB data inputs
    input  logic        [NUM_REQ-1:0] req_i,      // Request signals for each port
    output logic        [NUM_REQ-1:0] gnt_o,      // Grant signals for each port

    output logic [ 5:0] rd_addr_o,                // Selected register write address
    output logic [63:0] rd_data_o,                // Selected sign-extended write data
    output logic        rd_en_o                   // Write enable signal
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Index of the currently granted request port
  logic [$clog2(NUM_REQ)-1:0] port_idx;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Route the address from the selected port to the output
  always_comb rd_addr_o = wb_i[port_idx].addr;

  // Functional block: Sign-extension logic based on data size and sign bit
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

  // Submodule: Fixed priority arbiter to select which request gets access to the register file
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
