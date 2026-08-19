# adn_riscv_instr_decoder (module)

### Author: Foez Ahmed (foez.official@gmail.com)

### Source: adn_riscv_instr_decoder.sv

## Top IO

<img src="./adn_riscv_instr_decoder_top.svg">

## Parameters

|Name|Type|Dimension|Default|Description|
|-|-|-|-|-|
|XLEN|int||64|Data path width|
|EN_ZIFENCE_I|bit||1|Enable Zifencei extension|
|EN_ZICSR|bit||1|Enable Zicsr extension|
|EN_MATH|bit||1|Enable M-extension|
|EN_ATOMICS|bit||1|Enable A-extension|
|EN_FLOAT|bit||1|Enable F-extension|
|EN_DOUBLE|bit||1|Enable D-extension|


## Ports

|Name|Direction|Type|Dimension|Description|
|-|-|-|-|-|
|encoded_instr_i|input|logic [31:0]||Raw 32-bit instruction|
|decoded_instr_o|output|decoded_instr_t||Decoded instruction structure|
|found_o|output|logic||Valid instruction detected|


## Description

### Purpose
This module serves as the instruction decoder for the ADN-RISC-V processor core. It takes a 32-bit encoded instruction as input and decodes it into a structured format (`decoded_instr_t`), identifying the operation type and extracting relevant immediate values and register indices based on the RISC-V ISA specifications.

### Use Case
The `adn_riscv_instr_decoder` is a critical component in the instruction fetch/decode stage of the ADN-RISC-V pipeline. Its primary responsibilities include:
- **Instruction Parsing**: Translating raw 32-bit binary instructions into a machine-readable `decoded_instr_t` struct.
- **Immediate Extraction**: Calculating and sign-extending immediate values for various instruction formats (I, S, B, U, J types).
- **Control Signal Generation**: Identifying the specific operation (e.g., ADD, LW, BEQ) to drive downstream execution units.
- **ISA Flexibility**: Supporting optional RISC-V extensions (Zifencei, Zicsr, Math/M-extension, Atomics/A-extension, and Floating Point/F & D extensions) via parameter-driven logic.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-18 | Foez Ahmed | Initial version                                        |
| 1.0      | 2026-08-18 | Foez Ahmed | Stable release                                         |

Author : Foez Ahmed (foez.official@gmail.com)
