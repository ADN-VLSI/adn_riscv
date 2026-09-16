# adn_riscv_exe_i64_alu (module)

### Author: Mohiuddin Reyad (mreyad30207@gmail.com)

### Source: adn_riscv_exe_i64_alu.sv

## Top IO

<img src="./adn_riscv_exe_i64_alu_top.svg">

## Parameters

|Name|Type|Dimension|Default|Description|
|-|-|-|-|-|
|XLEN|int||64|Data width of the ALU, default is 64-bit for RV64I|


## Ports

|Name|Direction|Type|Dimension|Description|
|-|-|-|-|-|
|clk_i|input|logic||Clock signal for the pipeline registers|
|arst_ni|input|logic||Asynchronous reset signal, active low|
|alu_op_i|input|rv_op_t|||
|operand_a_i|input|logic [XLEN-1:0]|||
|operand_b_i|input|logic [XLEN-1:0]|||
|rd_addr_i|input|logic [4:0]||index of the destination register|
|valid_i|input|logic||Input handshake|
|ready_o|output|logic|||
|result_o|output|logic [XLEN-1:0]|||
|rd_addr_o|output|logic [ 4:0]|||
|valid_o|output|logic|||
|ready_i|input|logic||Output handshake|


## Description

### Purpose
This module implements the 64-bit Arithmetic Logic Unit (ALU) for the ADN-RISCV core. It performs integer arithmetic, logical operations, and word-level operations as defined by the RV64I instruction set architecture, including support for pipelined execution.

### Use Case
This module serves as the primary execution unit for integer arithmetic and logical operations within the ADN-RISCV processor pipeline. It receives operands from the register file or immediate generator, performs the requested operation based on the decoded instruction, and passes the result through a pipeline stage to ensure timing closure and maintain throughput in the execution stage.

### This module works with the following instrucitons:
#### RV64I register-immediate instructions
```plaintext
ADDI   SLTI   SLTIU   XORI   ORI   ANDI
```

#### RV64I register-register instructions
```plaintext
ADD   SUB   SLL   SLT   SLTU
XOR   SRL   SRA   OR    AND
```

#### RV64I word operations
```plaintext
ADDIW
ADDW   SUBW   SLLW   SRLW   SRAW
```

#### Exceptional instructions: this module assumes immediate values are inside operand_b_i
```plaintext
SLLI  SRLI  SRAI
SLLIW SRLIW SRAIW
```

### Planned Simplified Architecture

```plaintext
operand_a_i ───┐
│
operand_b_i ───┼──> ALU combinational logic ──> pipeline +──> result_o
│                                         │
alu_op_i ──────┤                                         ├──> rd_addr_o
│                                         ├──> valid_o
word_op_i ─────┘                                         └──> ready_o
```


| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-09-01 | Mohiuddin Reyad | Initial version                                        |
| 1.0      | 2026-09-01 | Mohiuddin Reyad | Stable release                                         |

Author : Mohiuddin Reyad (mreyad30207@gmail.com)
