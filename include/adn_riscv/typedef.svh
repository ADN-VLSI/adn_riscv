/*

# Purpose
This file defines the core SystemVerilog data types, structures, and macros used throughout the
ADN-RISCV architecture to ensure consistent data representation and type safety across the design.

# Use Case
This header file serves as the central repository for global type definitions and parameterized
macros within the ADN-RISCV project. By centralizing these definitions, it enforces strict type
consistency across different modules, prevents signal width mismatches, and simplifies the
instantiation of complex instruction structures. It is intended to be included in all design units
that require access to the architecture's standard data types and instruction formats.

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

  // Macro to define a decoded instruction structure based on architecture parameters
  `define ADN_RISCV_T(__NM__, __CLOG2_NUM_REGS__, __XLEN__)                                        \
    typedef struct packed {                                                                        \
      rv_op_t                                 op;         /* Instruction opcode */                 \
      logic [     ``__CLOG2_NUM_REGS__``-1:0] rd;         /* Destination register index */         \
      logic [     ``__CLOG2_NUM_REGS__``-1:0] rs1;        /* Source register 1 index */            \
      logic [     ``__CLOG2_NUM_REGS__``-1:0] rs2;        /* Source register 2 index */            \
      logic [     ``__CLOG2_NUM_REGS__``-1:0] rs3;        /* Source register 3 index */            \
      logic [                           31:0] imm;        /* Immediate value */                    \
      logic [               ``__XLEN__``-1:0] pc;         /* Program counter */                    \
      logic [2**(``__CLOG2_NUM_REGS__``)-1:0] reg_reqs;   /* Register access requests */           \
      logic                                   mem_op;     /* Memory operation flag */              \
      logic                                   blocking;   /* Blocking instruction flag */          \
    } ``__NM__``_decoded_instr_t;                                                                  \
