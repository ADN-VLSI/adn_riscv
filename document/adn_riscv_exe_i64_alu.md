# adn_riscv_exe_i64_alu (module)

### Author: Mohiuddin Reyad (mreyad30207@gmail.com)

### Source: adn_riscv_exe_i64_alu.sv

## Top IO

<img src="./adn_riscv_exe_i64_alu_top.svg">

## Parameters

| Name | Type | Dimension | Default | Description                                     |
| ---- | ---- | --------- | ------- | ----------------------------------------------- |
| XLEN | int  |           | 64      | specifies the length of the operands and result |


## Ports

| Name        | Direction | Type             | Dimension | Description                                                     |
| ----------- | --------- | ---------------- | --------- | --------------------------------------------------------------- |
| clk_i       | input     | logic            |           | clock signal only used for the purpose of using pipeline inside |
| arst_ni     | input     | logic            |           | reset signal only used for the purpose of using pipeline inside |
| alu_op_i    | input     | rv_op_t          |           | ALU operation control: selects the operations for ALU           |
| operand_a_i | input     | logic [XLEN-1:0] |           | ALU operand a value                                             |
| operand_b_i | input     | logic [XLEN-1:0] |           | ALU operand b value                                             |
| rd_addr_i   | input     | logic [4:0]      |           | index of the destination register                               |
| valid_i     | input     | logic            |           | Input handshake                                                 |
| ready_o     | output    | logic            |           | Input handshake                                                 |
| result_o    | output    | logic [XLEN-1:0] |           | ALU result                                                      |
| rd_addr_o   | output    | logic [4:0]      |           | index of the destination register                               |
| valid_o     | output    | logic            |           | Output handshake                                                |
| ready_i     | input     | logic            |           | Output handshake                                                |


## Description

@foez---bhai, write the purpose of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

@foez---bhai, describe the use case of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

### This module works with the following instrucitons:
#### RV64I register-immediate instructions
    ADDI   SLTI   SLTIU   XORI   ORI   ANDI

#### RV64I register-register instructions
    ADD   SUB   SLL   SLT   SLTU
    XOR   SRL   SRA   OR    AND

#### RV64I word operations
    ADDIW
    ADDW   SUBW   SLLW   SRLW   SRAW

#### Exceptional instructions: this module assumes immediate values are inside operand_b_i
    SLLI  SRLI  SRAI
    SLLIW SRLIW SRAIW

### Simplified Architecture:
    operand_a_i ───┐
                   │
    operand_b_i ───┼──> ALU combinational logic ──> pipeline ──> result_o
                   │                                  │
    alu_op_i ──────┤                                  ├──> rd_addr_o
                   │                                  ├──> valid_o
    word_op_i ─────┘                                  └──> ready_o

### Device Schematic after elaboration:
![alt text](exe_i64_alu.png)

| REVISION | DATE       | AUTHOR          | DESCRIPTION     |
| -------- | ---------- | --------------- | --------------- |
| 0.1      | 2026-09-01 | Mohiuddin Reyad | Initial version |
| 1.0      | 2026-09-01 | Mohiuddin Reyad | Stable release  |

Author : Mohiuddin Reyad (mreyad30207@gmail.com)
