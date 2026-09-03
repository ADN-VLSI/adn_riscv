/*

### Module Purpose
The `adn_riscv_exe_i64_lsu` module serves as the Load-Store Unit (LSU) for a 64-bit RISC-V processor core. It is responsible for managing memory access operations, including standard loads and stores, atomic memory operations (AMOs), and floating-point memory instructions. The module handles address calculation, data alignment, sign extension, and interfaces with the memory subsystem via a PMI (Processor Memory Interface) protocol.

### Use Case
This module acts as the bridge between the execution pipeline and the memory subsystem. Its primary use cases include:
- **Memory Access:** Executing load and store instructions by calculating effective addresses and managing data alignment for various widths (byte, half-word, word, double-word).
- **Atomic Operations:** Handling RISC-V atomic memory operations (AMOs) and Load-Reserved/Store-Conditional (LR/SC) sequences to ensure memory consistency in multi-core environments.
- **Fault Handling:** Monitoring memory responses to detect and report access faults or bus errors.
- **Data Formatting:** Performing sign extension for sub-word loads and byte-shifting for unaligned memory accesses.

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

module adn_riscv_exe_i64_lsu
  import adn_riscv_pkg::*;
#(
    parameter type rv_op_t   = logic, // RISC-V operation type definition
    parameter type pmi_req_t = logic, // PMI request structure type
    parameter type pmi_rsp_t = logic  // PMI response structure type
) (
    input logic clk_i,   // Clock input
    input logic arst_ni, // Asynchronous reset, active low

    input  rv_op_t        op_i,     // Operation inputs
    input  logic   [63:0] rs1_i,    // Source register 1 input (Base address)
    input  logic   [63:0] rs2_i,    // Source register 2 input (Store data)
    input  logic   [11:0] imm_i,    // Immediate input (Offset)
    input  logic   [ 5:0] rd_i,     // Destination register input
    input  logic          valid_i,  // Valid input signal
    output logic          ready_o,  // Ready output signal

    output sideband_t dmem_sideband_o,  // Memory sideband signals
    output pmi_req_t  dmem_pmi_req_o,   // PMI request output
    input  pmi_rsp_t  dmem_pmi_rsp_i,   // PMI grant input

    output logic [63:0] wr_data_o,  // Write data output (to register file)
    output logic [ 1:0] wr_size_o,  // Write size output
    output logic [ 5:0] wr_addr_o,  // Write address output
    output logic        valid_o,    // Valid output signal
    input  logic        ready_i,    // Ready input signal

    output logic [63:0] mem_fault_addr_o,  // Memory address output
    output logic        mem_fault_o        // Memory fault output
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic        instr_check_valid; // Valid signal for instruction check
  logic        instr_check_ready; // Ready signal for instruction check

  logic [ 1:0] wr_size;           // Write size control
  logic        wr_sign;           // Sign extension control

  logic [ 1:0] wr_size_;          // Registered write size
  logic        wr_sign_;          // Registered sign extension control

  logic        hs_cntr_iv;        // Handshake counter input valid
  logic        hs_cntr_ir;        // Handshake counter input ready
  logic        hs_cntr_ov;        // Handshake counter output valid
  logic        hs_cntr_or;        // Handshake counter output ready

  logic        req_fifo_div;      // Request FIFO data input valid
  logic        req_fifo_dir;      // Request FIFO data input ready
  logic        req_fifo_dov;      // Request FIFO data output valid
  logic        req_fifo_dor;      // Request FIFO data output ready

  logic        rsp_fifo_dov;      // Response FIFO data output valid
  logic        rsp_fifo_dor;      // Response FIFO data output ready

  logic [63:0] mem_rdata;         // Memory read data
  logic        mem_fault;         // Memory fault flag

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
        strb = 8'b0000_0001;
      end

      SH, LH, LHU: begin
        wr_size = 1;
        wr_sign = (op_i == LH);
        strb = 8'b0000_0011;
      end

      SW, FSW, SC_W, AMOSWAP_W, AMOADD_W, AMOXOR_W, AMOAND_W,
      AMOOR_W, AMOMIN_W, AMOMAX_W, AMOMINU_W, AMOMAXU_W, LW, LWU: begin
        wr_size = 2;
        wr_sign = (op_i == LW);
        strb = 8'b0000_1111;
      end

      SD, FSD, SC_D, AMOSWAP_D, AMOADD_D, AMOXOR_D, AMOAND_D,
      AMOOR_D, AMOMIN_D, AMOMAX_D, AMOMINU_D, AMOMAXU_D, LD: begin
        wr_size = 3;
        wr_sign = 0;
        strb = 8'b1111_1111;
      end

      default: begin
        wr_size = 0;
        wr_sign = 0;
        strb = 8'b0000_0000;
      end

    endcase
    dmem_pmi_req_o.mstrb = strb << (dmem_pmi_req_o.maddr[2:0]);
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
    data_out = data_out >> (mem_fault_addr_o[2:0] * 8);
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

  // Input handshake combiner
  adn_common_hs_combiner #(
      .NUM_TX(1),
      .NUM_RX(4)
  ) hs_comb_in (
      .valid_i(valid_i),
      .ready_o(ready_o),
      .valid_o({instr_check_valid, hs_cntr_iv, req_fifo_div, dmem_pmi_req_o.mreq}),
      .ready_i({instr_check_ready, hs_cntr_ir, req_fifo_dir, dmem_pmi_rsp_i.mgnt})
  );

  // Handshake counter for pipeline tracking
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

  // Request FIFO for address and metadata
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
      .data_out_o      ({mem_fault_addr_o, wr_addr_o, wr_size_, wr_sign_}),
      .data_out_valid_o(req_fifo_dov),
      .data_out_ready_i(req_fifo_dor),
      .count_o         ()
  );

  // Response FIFO for memory read data
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

  // Output handshake combiner
  adn_common_hs_combiner #(
      .NUM_TX(3),
      .NUM_RX(1)
  ) hs_comb_out (
      .valid_i({hs_cntr_ov, req_fifo_dov, rsp_fifo_dov}),
      .ready_o({hs_cntr_or, req_fifo_dor, rsp_fifo_dor}),
      .valid_o(valid_o),
      .ready_i(ready_i)
  );

endmodule
