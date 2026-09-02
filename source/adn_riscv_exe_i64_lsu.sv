/*

@foez---bhai, write the purpose of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

@foez---bhai, describe the use case of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-09-01 | Foez Ahmed      | Initial version                                        |
| 1.0      | 2026-09-01 | Foez Ahmed      | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

// SUPPORTED OPERATIONS: LB LH LW LBU LHU LWU LD SB SH SW SD FLW FSW FLD FSD 
// LR_W SC_W AMOSWAP_W AMOADD_W AMOXOR_W AMOAND_W AMOOR_W AMOMIN_W AMOMAX_W AMOMINU_W AMOMAXU_W
// LR_D SC_D AMOSWAP_D AMOADD_D AMOXOR_D AMOAND_D AMOOR_D AMOMIN_D AMOMAX_D AMOMINU_D AMOMAXU_D

/*

  typedef struct packed {
    logic [63:0] maddr;
    logic        mwe;
    logic [63:0] mwdata;
    logic [ 7:0] mstrb;
    logic        mreq;
  } pmi_req_t;

  typedef struct packed {
    logic        mgnt;
    logic        mack;
    logic [63:0] mrdata;
    logic        mresp;
  } pmi_rsp_t;

  typedef enum [3:0] {
    NONE,
    LR,
    SC,
    AMOSWAP,
    AMOADD,
    AMOXOR,
    AMOAND,
    AMOOR,
    AMOMIN,
    AMOMAX,
    AMOMINU,
    AMOMAXU
  } amo_op_t;

  typedef struct packed {
    logic   aq;
    logic   rl;
    logic   doubleword;
    amo_op_t op;
  } sideband_t;

*/

`include "adn_riscv_pkg.sv"

// @foez---bhai, add comments to the parameters, ports
module adn_riscv_exe_i64_lsu
  import adn_riscv_pkg::*;
#(
    parameter type rv_op_t   = logic,
    parameter type pmi_req_t = logic,
    parameter type pmi_rsp_t = logic
) (
    input logic clk_i,   // Clock input
    input logic arst_ni, // Asynchronous reset, active low

    input  rv_op_t        op_i,     // Operation inputs
    input  logic   [63:0] rs1_i,    // Source register 1 input
    input  logic   [63:0] rs2_i,    // Source register 2 input
    input  logic   [11:0] imm_i,    // Immediate input
    input  logic   [ 5:0] rd_i,     // Destination register input
    input  logic          valid_i,  // Valid input signal
    output logic          ready_o,  // Ready output signal

    output sideband_t dmem_sideband_o,  // Memory sideband signals
    output pmi_req_t  dmem_pmi_req_o,   // PMI request output
    input  pmi_rsp_t  dmem_pmi_rsp_i,   // PMI grant input

    output logic [63:0] wr_data_o,  // Write data output
    output logic [ 1:0] wr_size_o,  // Write size output
    output logic [ 5:0] wr_addr_o,  // Write address output
    output logic        valid_o,    // Valid output signal
    input  logic        ready_i,    // Ready input signal

    output logic [63:0] mem_addr_o,  // Memory address output
    output logic        mem_fault_o  // Memory fault output
);

  // @foez---bhai, add comments to the functional blocks, signals, and submodules

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS GENERATED
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Calculate memory address
  always_comb dmem_pmi_req_o.maddr = rs1_i + {{52{imm_i[11]}}, imm_i};

  // Write enable signal based on operation
  always_comb dmem_pmi_req_o.mwe = op_i inside {SB, SH, SW, SD, FSW, FSD};

  // Write data from source register 2
  always_comb dmem_pmi_req_o.mwdata = rs2_i << (8 * (dmem_pmi_req_o.maddr[2:0]));

  // Write strobe signal based on operation
  always_comb begin
    logic [7:0] strb;

    case (op_i)

      SB: begin
        dmem_pmi_req_o.mstrb = 8'b0000_0001;
      end

      SH: begin
        dmem_pmi_req_o.mstrb = 8'b0000_0011;
      end

      SW, FSW, SC_W, AMOSWAP_W, AMOADD_W, AMOXOR_W, AMOAND_W,
      AMOOR_W, AMOMIN_W, AMOMAX_W, AMOMINU_W, AMOMAXU_W: begin
        dmem_pmi_req_o.mstrb = 8'b0000_1111;
      end

      SD, FSD, SC_D, AMOSWAP_D, AMOADD_D, AMOXOR_D, AMOAND_D,
      AMOOR_D, AMOMIN_D, AMOMAX_D, AMOMINU_D, AMOMAXU_D: begin
        dmem_pmi_req_o.mstrb = 8'b1111_1111;
      end

      default: begin
        dmem_pmi_req_o.mstrb = 8'b0000_0000;
      end

    endcase
    strb = strb << (dmem_pmi_req_o.maddr[2:0]);
    dmem_pmi_req_o.mstrb = strb;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INITIAL CHECKS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSERTIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INITIAL CHECKS
  //////////////////////////////////////////////////////////////////////////////////////////////////


endmodule

