# adn_riscv/typedef.svh  (include)

### Author: Foez Ahmed (foez.official@gmail.com)

### Source: typedef.svh

## Parameters

_None_


## Macros

|Name|Args|Description|Preview|
|-|-|-|-|
|ADN_RISCV_T|__NM__, __CLOG2_NUM_REGS__, __XLEN__|Macro to define a decoded instruction structure based on architecture parameters|`define ADN_RISCV_T(__NM__, __CLOG2_NUM_REGS__, __XLEN__)                                         typedef struct packed {|


## Description

# adn_riscv/typedef.svh 
This file defines the core SystemVerilog data types, structures, and macros used throughout the ADN-RISCV architecture to ensure consistent data representation and type safety across the design.

# adn_riscv/typedef.svh  Case
This header file serves as the central repository for global type definitions and parameterized macros within the ADN-RISCV project. By centralizing these definitions, it enforces strict type consistency across different modules, prevents signal width mismatches, and simplifies the instantiation of complex instruction structures. It is intended to be included in all design units that require access to the architecture's standard data types and instruction formats.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-24 | Foez Ahmed      | Initial version                                        |
| 1.0      | 2026-08-24 | Foez Ahmed      | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
