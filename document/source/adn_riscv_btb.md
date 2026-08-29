# adn_riscv_btb (module)

### Author: Foez Ahmed (foez.official@gmail.com)

### Source: adn_riscv_btb.sv

## Top IO

<img src="./adn_riscv_btb_top.svg">

## Parameters

|Name|Type|Dimension|Default|Description|
|-|-|-|-|-|
|NUM_BTB|int||32|Number of entries in the Branch Target Buffer|
|XLEN|int||64|Data width of the processor|


## Ports

|Name|Direction|Type|Dimension|Description|
|-|-|-|-|-|
|clk_i|input|logic||Clock input|
|arst_ni|input|logic||Asynchronous reset input|
|current_addr_i|input|logic [XLEN-1:0]||Current address (EXEC) input|
|next_addr_i|input|logic [XLEN-1:0]||Next address (EXEC) input|
|pc_i|input|logic [XLEN-1:0]||Program counter (IF) input|
|is_jump_i|input|logic||Is jump/branch (IF) input|
|match_found_o|output|logic||Found match in buffer output|
|flush_o|output|logic||Pipeline flush signal output|
|next_pc_o|output|logic [XLEN-1:0]||Next program counter (in case of jump) output|


## Description

### Purpose
The `adn_riscv_btb` module implements a Branch Target Buffer (BTB) designed to predict the outcomes of branch and jump instructions in a RISC-V processor. It caches target addresses for previously executed branches, allowing the pipeline to fetch the correct instruction stream early and minimize performance penalties associated with control flow changes.

### Use Case
This module is utilized in the instruction fetch stage of a RISC-V pipeline. When the processor encounters a branch or jump instruction, the BTB is queried using the current program counter (PC). If a match is found, the module provides the predicted target address, allowing the fetch unit to redirect the instruction stream immediately. If the prediction is incorrect or a new branch is encountered, the module updates its internal buffer using a state-based replacement policy to improve future prediction accuracy.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-29 | Foez Ahmed | Initial version                                        |
| 1.0      | 2026-08-29 | Foez Ahmed | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
