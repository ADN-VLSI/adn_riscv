/*

@foez-bhai, write the purpose of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

@foez-bhai, describe the use case of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

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

`include "adn_riscv_pkg.sv"

// @foez-bhai, add comments to the parameters, ports
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

    output sideband_t dmem_sideband_o,  // Memory sideband signals // TODO
    output pmi_req_t  dmem_pmi_req_o,   // PMI request output
    input  pmi_rsp_t  dmem_pmi_rsp_i,   // PMI grant input

    output logic [63:0] wr_data_o,  // Write data output
    output logic [ 1:0] wr_size_o,  // Write size output
    output logic [ 5:0] wr_addr_o,  // Write address output
    output logic        valid_o,    // Valid output signal
    input  logic        ready_i,    // Ready input signal

    output logic [63:0] mem_fault_addr_o,  // Memory address output
    output logic        mem_fault_o        // Memory fault output
);

  // @foez-bhai, add comments to the functional blocks, signals, and submodules

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic        instr_check_valid;
  logic        instr_check_ready;

  logic [ 1:0] wr_size;
  logic        wr_sign;

  logic [ 1:0] wr_size_;
  logic        wr_sign_;

  logic        hs_cntr_iv;
  logic        hs_cntr_ir;
  logic        hs_cntr_ov;
  logic        hs_cntr_or;

  logic        req_fifo_div;
  logic        req_fifo_dir;
  logic        req_fifo_dov;
  logic        req_fifo_dor;

  logic        rsp_fifo_dov;
  logic        rsp_fifo_dor;

  logic [63:0] mem_rdata;
  logic        mem_fault;

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

      SB, LB, LBU: begin
        wr_size = 0;
        wr_sign = (op_i == LB);
        dmem_pmi_req_o.mstrb = 8'b0000_0001;
      end

      SH, LH, LHU: begin
        wr_size = 1;
        wr_sign = (op_i == LH);
        dmem_pmi_req_o.mstrb = 8'b0000_0011;
      end

      SW, FSW, SC_W, AMOSWAP_W, AMOADD_W, AMOXOR_W, AMOAND_W,
      AMOOR_W, AMOMIN_W, AMOMAX_W, AMOMINU_W, AMOMAXU_W, LW, LWU: begin
        wr_size = 2;
        wr_sign = (op_i == LW);
        dmem_pmi_req_o.mstrb = 8'b0000_1111;
      end

      SD, FSD, SC_D, AMOSWAP_D, AMOADD_D, AMOXOR_D, AMOAND_D,
      AMOOR_D, AMOMIN_D, AMOMAX_D, AMOMINU_D, AMOMAXU_D, LD: begin
        wr_size = 3;
        wr_sign = 0;
        dmem_pmi_req_o.mstrb = 8'b1111_1111;
      end

      default: begin
        wr_size = 0;
        wr_sign = 0;
        dmem_pmi_req_o.mstrb = 8'b0000_0000;
      end

    endcase
    strb = strb << (dmem_pmi_req_o.maddr[2:0]);
    dmem_pmi_req_o.mstrb = strb;
  end

  always_comb begin
    case (op_i)
      LR_W: begin
        dmem_sideband_o.op = LR;
        dmem_sideband_o.doubleword = '0;
      end

      SC_W: begin
        dmem_sideband_o.op = SC;
        dmem_sideband_o.doubleword = '0;
      end

      AMOSWAP_W: begin
        dmem_sideband_o.op = AMOSWAP;
        dmem_sideband_o.doubleword = '0;
      end

      AMOADD_W: begin
        dmem_sideband_o.op = AMOADD;
        dmem_sideband_o.doubleword = '0;
      end

      AMOXOR_W: begin
        dmem_sideband_o.op = AMOXOR;
        dmem_sideband_o.doubleword = '0;
      end

      AMOAND_W: begin
        dmem_sideband_o.op = AMOAND;
        dmem_sideband_o.doubleword = '0;
      end

      AMOOR_W: begin
        dmem_sideband_o.op = AMOOR;
        dmem_sideband_o.doubleword = '0;
      end

      AMOMIN_W: begin
        dmem_sideband_o.op = AMOMIN;
        dmem_sideband_o.doubleword = '0;
      end

      AMOMAX_W: begin
        dmem_sideband_o.op = AMOMAX;
        dmem_sideband_o.doubleword = '0;
      end

      AMOMINU_W: begin
        dmem_sideband_o.op = AMOMINU;
        dmem_sideband_o.doubleword = '0;
      end

      AMOMAXU_W: begin
        dmem_sideband_o.op = AMOMAXU;
        dmem_sideband_o.doubleword = '0;
      end

      LR_D: begin
        dmem_sideband_o.op = LR;
        dmem_sideband_o.doubleword = '1;
      end

      SC_D: begin
        dmem_sideband_o.op = SC;
        dmem_sideband_o.doubleword = '1;
      end

      AMOSWAP_D: begin
        dmem_sideband_o.op = AMOSWAP;
        dmem_sideband_o.doubleword = '1;
      end

      AMOADD_D: begin
        dmem_sideband_o.op = AMOADD;
        dmem_sideband_o.doubleword = '1;
      end

      AMOXOR_D: begin
        dmem_sideband_o.op = AMOXOR;
        dmem_sideband_o.doubleword = '1;
      end

      AMOAND_D: begin
        dmem_sideband_o.op = AMOAND;
        dmem_sideband_o.doubleword = '1;
      end

      AMOOR_D: begin
        dmem_sideband_o.op = AMOOR;
        dmem_sideband_o.doubleword = '1;
      end

      AMOMIN_D: begin
        dmem_sideband_o.op = AMOMIN;
        dmem_sideband_o.doubleword = '1;
      end

      AMOMAX_D: begin
        dmem_sideband_o.op = AMOMAX;
        dmem_sideband_o.doubleword = '1;
      end

      AMOMINU_D: begin
        dmem_sideband_o.op = AMOMINU;
        dmem_sideband_o.doubleword = '1;
      end

      AMOMAXU_D: begin
        dmem_sideband_o.op = AMOMAXU;
        dmem_sideband_o.doubleword = '1;
      end

      default: begin
        dmem_sideband_o.op = NONE;
        dmem_sideband_o.doubleword = '0;
      end

    endcase

    dmem_sideband_o.aq = imm_i[1];
    dmem_sideband_o.rl = imm_i[0];

  end

  always_comb begin
    instr_check_ready = instr_check_valid & op_i inside {
      LB,
      LH,
      LW,
      LBU,
      LHU,
      LWU,
      LD,
      SB,
      SH,
      SW,
      SD,
      FLW,
      FSW,
      FLD,
      FSD,
      LR_W,
      SC_W,
      AMOSWAP_W,
      AMOADD_W,
      AMOXOR_W,
      AMOAND_W,
      AMOOR_W,
      AMOMIN_W,
      AMOMAX_W,
      AMOMINU_W,
      AMOMAXU_W,
      LR_D,
      SC_D,
      AMOSWAP_D,
      AMOADD_D,
      AMOXOR_D,
      AMOAND_D,
      AMOOR_D,
      AMOMIN_D,
      AMOMAX_D,
      AMOMINU_D,
      AMOMAXU_D
    };
  end

  always_comb begin
    logic [63:0] data_out;
    data_out  = mem_rdata;
    mem_rdata = mem_rdata >> (mem_fault_addr_o[2:0] * 8);
    case (wr_size_)
      0: data_out = data_out & 64'h0000_0000_0000_00FF;
      1: data_out = data_out & 64'h0000_0000_0000_FFFF;
      2: data_out = data_out & 64'h0000_0000_FFFF_FFFF;
      default: data_out = data_out;
    endcase
    if (wr_sign_) begin
      case (wr_size_)
        0: data_out = {{56{data_out[7]}}, data_out[7:0]};
        1: data_out = {{48{data_out[15]}}, data_out[15:0]};
        2: data_out = {{32{data_out[31]}}, data_out[31:0]};
        default: data_out = data_out;
      endcase
    end
    wr_data_o = data_out;
    wr_size_o = 3;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_common_hs_combiner #(
      .NUM_TX(1),
      .NUM_RX(4)
  ) hs_comb_in (
      .valid_i(valid_i),
      .ready_o(ready_o),
      .valid_o({instr_check_valid, hs_cntr_iv, req_fifo_div, dmem_pmi_req_o.mreq}),
      .ready_i({instr_check_ready, hs_cntr_ir, req_fifo_dir, dmem_pmi_rsp_i.mgnt})
  );

  adn_common_hs_counter #(
      .DEPTH    (4),
      .PIPELINED(1)
  ) u_hs_counter (
      .clk_i            (clk_i),
      .arst_ni          (arst_ni),
      .data_in_valid_i  (hs_cntr_iv),
      .data_in_ready_o  (hs_cntr_ir),
      .data_out_valid_o (hs_cntr_ov),
      .data_out_ready_i (hs_cntr_or),
      .passing_through_o(),
      .count_o          ()
  );

  adn_common_fifo #(
      .DATA_WIDTH($bits(dmem_pmi_req_o.maddr) + $bits(rd_i) + $bits(wr_size) + $bits(wr_sign)),
      .FIFO_SIZE (2),
      .PIPELINED (1)
  ) req_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       ({dmem_pmi_req_o.maddr, rd_i, wr_size, wr_sign}),
      .data_in_valid_i (req_fifo_div),
      .data_in_ready_o (req_fifo_dir),
      .data_out_o      ({mem_fault_addr_o, wr_addr_o, wr_size, wr_sign}),
      .data_out_valid_o(req_fifo_dov),
      .data_out_ready_i(req_fifo_dor),
      .count_o         ()
  );

  adn_common_fifo #(
      .DATA_WIDTH($bits(dmem_pmi_rsp_i.mrdata) + $bits(dmem_pmi_rsp_i.mresp)),
      .FIFO_SIZE (2),
      .PIPELINED (1)
  ) rsp_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       ({dmem_pmi_rsp_i.mrdata, dmem_pmi_rsp_i.mresp}),
      .data_in_valid_i (dmem_pmi_rsp_i.mack),
      .data_in_ready_o (),
      .data_out_o      ({mem_rdata, mem_fault}),
      .data_out_valid_o(rsp_fifo_dov),
      .data_out_ready_i(rsp_fifo_dor),
      .count_o         ()
  );

  adn_common_hs_combiner #(
      .NUM_TX(3),
      .NUM_RX(1)
  ) hs_comb_out (
      .valid_i({hs_cntr_ov, req_fifo_dov, rsp_fifo_dov}),
      .ready_o({hs_cntr_ir, req_fifo_dir, rsp_fifo_dor}),
      .valid_o(valid_o),
      .ready_i(ready_i)
  );

endmodule
