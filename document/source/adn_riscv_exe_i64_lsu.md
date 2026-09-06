# adn_riscv_exe_i64_lsu (module)

### Author: Foez Ahmed (foez.official@gmail.com)

### Source: adn_riscv_exe_i64_lsu.sv

## Top IO

<img src="./adn_riscv_exe_i64_lsu_top.svg">

<img src="./adn_riscv_exe_i64_lsu_des.svg">

## Parameters

|Name|Type|Dimension|Default|Description|
|-|-|-|-|-|
|rv_op_t|type||logic|RISC-V operation type definition|
|pmi_req_t|type||logic|PMI request structure type|
|pmi_rsp_t|type||logic|PMI response structure type|


## Ports

|Name|Direction|Type|Dimension|Description|
|-|-|-|-|-|
|clk_i|input|logic||Clock input|
|arst_ni|input|logic||Asynchronous reset, active low|
|op_i|input|rv_op_t||Operation inputs|
|rs1_i|input|logic [63:0]||Source register 1 input (Base address)|
|rs2_i|input|logic [63:0]||Source register 2 input (Store data)|
|imm_i|input|logic [11:0]||Immediate input (Offset)|
|rd_i|input|logic [ 5:0]||Destination register input|
|valid_i|input|logic||Valid input signal|
|ready_o|output|logic||Ready output signal|
|dmem_sideband_o|output|sideband_t||Memory sideband signals|
|dmem_pmi_req_o|output|pmi_req_t||PMI request output|
|dmem_pmi_rsp_i|input|pmi_rsp_t||PMI grant input|
|wr_data_o|output|logic [63:0]||Write data output (to register file)|
|wr_size_o|output|logic [ 1:0]||Write size output|
|wr_addr_o|output|logic [ 5:0]||Write address output|
|valid_o|output|logic||Valid output signal|
|ready_i|input|logic||Ready input signal|
|mem_fault_addr_o|output|logic [63:0]||Memory address output|
|mem_fault_o|output|logic||Memory fault output|


## Description

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
