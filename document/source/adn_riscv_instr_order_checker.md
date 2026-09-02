# adn_riscv_instr_order_checker (module)

### Author: Foez Ahmed (foez.official@gmail.com)

### Source: adn_riscv_instr_order_checker.sv

## Top IO

<img src="./adn_riscv_instr_order_checker_top.svg">

## Parameters

|Name|Type|Dimension|Default|Description|
|-|-|-|-|-|
|NR|int||32|Number of registers to track|


## Ports

|Name|Direction|Type|Dimension|Description|
|-|-|-|-|-|
|pl_valid_i|input|logic|||
|rd_i|input|logic [$clog2(NR)-1:0]||Destination register index|
|blocking_i|input|logic||Signal to force stall all registers|
|reg_req_i|input|logic [ NR-1:0]||Register request mask|
|mem_op_i|input|logic||Memory operation flag|
|locks_i|input|logic [NR-1:0]|||
|locks_o|output|logic [NR-1:0]||Updated register lock status|
|mem_busy_i|input|logic|||
|mem_busy_o|output|logic||Memory busy status output|
|arb_req_o|output|logic||Arbitration request output|


## Description

### Purpose
The `adn_riscv_instr_order_checker` module is designed to manage instruction dependencies and execution ordering within a RISC-V pipeline. It tracks register locks and memory operation status to ensure that instructions are dispatched or stalled correctly, preventing hazards by monitoring register availability and memory busy states.

### Use Case
This module acts as a gatekeeper in the RISC-V pipeline's issue stage. Its primary use case is to prevent Read-After-Write (RAW) hazards and structural hazards related to memory access. By maintaining a scoreboard of register locks (`locks_i`) and monitoring the status of memory operations (`mem_busy_i`), the module determines if an incoming instruction (`pl_valid_i`) can proceed to execution or must be stalled. It is essential for out-of-order execution logic or high-performance in-order pipelines where dependency tracking is required to maintain architectural correctness.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-29 | Foez Ahmed      | Initial version                                        |
| 1.0      | 2026-08-29 | Foez Ahmed      | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
