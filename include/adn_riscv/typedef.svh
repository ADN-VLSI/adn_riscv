/*

@foez-bhai, write the purpose of this file in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

@foez-bhai, describe the use case of this file in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-24 | Foez Ahmed      | Initial version                                        |
| 1.0      | 2026-08-24 | Foez Ahmed      | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

  // @foez-bhai, add comments to the functional blocks, signals, and macros

  `define ADN_RISCV_T(__NM__, __CLOG2_NUM_REGS__, __XLEN__)                                        \
    typedef struct packed {                                                                        \
      rv_op_t                                 op;                                                  \
      logic [     ``__CLOG2_NUM_REGS__``-1:0] rd;                                                  \
      logic [     ``__CLOG2_NUM_REGS__``-1:0] rs1;                                                 \
      logic [     ``__CLOG2_NUM_REGS__``-1:0] rs2;                                                 \
      logic [     ``__CLOG2_NUM_REGS__``-1:0] rs3;                                                 \
      logic [                           31:0] imm;                                                 \
      logic [               ``__XLEN__``-1:0] pc;                                                  \
      logic [2**(``__CLOG2_NUM_REGS__``)-1:0] reg_reqs;                                            \
      logic                                   mem_op;                                              \
      logic                                   blocking;                                            \
    } ``__NM__``_decoded_instr_t;                                                                  \

