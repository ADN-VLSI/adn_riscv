/*

| TEST CASE | TEST NAME                  | DATE       | AUTHOR                                  | DESCRIPTION                                                                 |
|-----------|----------------------------|------------|-----------------------------------------|-----------------------------------------------------------------------------|
| TC_001    | `reset_idle`               | 2026-09-02 | Annim Jannat & Md. Sakib Hasan Shawon   | Verifies multiplier behavior while idle after reset.                       |
| TC_002    | `mul_basic`                | 2026-09-02 | Annim Jannat & Md. Sakib Hasan Shawon   | Verifies basic signed MUL operations and low 64-bit results.               |
| TC_003    | `mul_sign_cases`           | 2026-09-02 | Annim Jannat & Md. Sakib Hasan Shawon   | Verifies MUL with positive and negative operand combinations.              |
| TC_004    | `mulh_basic`               | 2026-09-02 | Annim Jannat & Md. Sakib Hasan Shawon   | Verifies signed MULH high-64-bit multiplication results.                   |
| TC_005    | `mulhsu_basic`             | 2026-09-02 | Annim Jannat & Md. Sakib Hasan Shawon   | Verifies signed-unsigned MULHSU high-64-bit multiplication results.        |
| TC_006    | `mulhu_basic`              | 2026-09-02 | Annim Jannat & Md. Sakib Hasan Shawon   | Verifies unsigned MULHU high-64-bit multiplication results.                |
| TC_007    | `mulw_basic`               | 2026-09-02 | Annim Jannat & Md. Sakib Hasan Shawon   | Verifies signed 32-bit MULW operations and sign extension.                 |
| TC_008    | `boundary_values`          | 2026-09-02 | Annim Jannat & Md. Sakib Hasan Shawon   | Verifies multiplication using zero, one, maximum and minimum values.      |
| TC_009    | `backpressure`             | 2026-09-02 | Annim Jannat & Md. Sakib Hasan Shawon   | Verifies output holding and pipeline behavior when ready_i is deasserted. |
| TC_010    | `sequential_operations`    | 2026-09-02 | Annim Jannat & Md. Sakib Hasan Shawon   | Verifies multiple multiplication operations issued sequentially.          |
| TC_011    | `randomized`               | 2026-09-02 | Annim Jannat & Md. Sakib Hasan Shawon   | Verifies all multiplication modes using randomized operands.              |
| TC_012    | `mixed_operations`         | 2026-09-02 | Annim Jannat & Md. Sakib Hasan Shawon   | Verifies different multiplication instructions in mixed sequence.         |
| --------- | `all`                      | 2026-09-02 | Annim Jannat & Md. Sakib Hasan Shawon   | Runs the complete directed multiplier test suite.   

| REVISION | DATE       | AUTHOR                                | DESCRIPTION     |
|----------|------------|---------------------------------------|---------------- |
| 0.1      | 2026-09-02 | Annim Jannat & Md. Sakib Hasan Shawon | Initial version |
| 1.0      | 2026-09-02 | Annim Jannat & Md. Sakib Hasan Shawon | Stable release  |

Author : Annim Jannat (jannatannim@gmail.com)
Author : Md. Sakib Hasan Shawon (mdsakibhasanshawon20@gmail.com)
This file is part of ADN-VLSI/adn_riscv
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_riscv_exe_m64_mult_tb;

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  /////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  /////////////////////////////////////////////////////////////////////////////////////////////////

  localparam time CLK_PERIOD = 10ns;

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  /////////////////////////////////////////////////////////////////////////////////////////////////

  logic        clk_i;
  logic        arst_ni;

  logic        MUL_i;
  logic        MULH_i;
  logic        MULHSU_i;
  logic        MULHU_i;
  logic        MULW_i;

  logic [63:0] rs1_i;
  logic [63:0] rs2_i;
  logic [5:0]  rd_i;

  logic        valid_i;
  logic        ready_o;

  logic [63:0] wr_data_o;
  logic [1:0]  wr_size_o;
  logic [5:0]  wr_addr_o;
  logic        valid_o;
  logic        ready_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // DUT
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_riscv_exe_m64_mult dut (
      .clk_i      (clk_i),
      .arst_ni    (arst_ni),

      .MUL_i      (MUL_i),
      .MULH_i     (MULH_i),
      .MULHSU_i   (MULHSU_i),
      .MULHU_i    (MULHU_i),
      .MULW_i     (MULW_i),

      .rs1_i      (rs1_i),
      .rs2_i      (rs2_i),
      .rd_i       (rd_i),
      .valid_i    (valid_i),
      .ready_o    (ready_o),

      .wr_data_o  (wr_data_o),
      .wr_size_o  (wr_size_o),
      .wr_addr_o  (wr_addr_o),
      .valid_o    (valid_o),
      .ready_i    (ready_i)
  );

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // CLOCK
  /////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin
    clk_i = 1'b0;

    forever begin
      #(CLK_PERIOD / 2);
      clk_i = ~clk_i;
    end
  end

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // RESET
  /////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic reset_dut();

    arst_ni = 1'b0;

    MUL_i    = 1'b0;
    MULH_i   = 1'b0;
    MULHSU_i = 1'b0;
    MULHU_i  = 1'b0;
    MULW_i   = 1'b0;

    rs1_i    = '0;
    rs2_i    = '0;
    rd_i     = '0;

    valid_i  = 1'b0;
    ready_i  = 1'b1;

    repeat (3) @(posedge clk_i);

    arst_ni = 1'b1;

    @(posedge clk_i);

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // EXPECTED RESULT
  //////////////////////////////////////////////////////////////////////////////////////////////////

  function automatic logic [63:0] calculate_expected(
      input logic [63:0] rs1,
      input logic [63:0] rs2,
      input logic        is_mul,
      input logic        is_mulh,
      input logic        is_mulhsu,
      input logic        is_mulhu,
      input logic        is_mulw
  );

    logic signed [63:0]  s_rs1;
    logic signed [63:0]  s_rs2;

    logic signed [31:0]  s_rs1_w;
    logic signed [31:0]  s_rs2_w;

    logic        [127:0] unsigned_product;
    logic signed [127:0] signed_product;
    logic signed [127:0] signed_unsigned_product;

    // Explicit 32-bit MULW product.
    logic signed [63:0]  mulw_product;
    logic signed [31:0]  mulw_result32;

    logic [63:0] result;

    begin

      // --------------------------------------------------------------------------
      // 64-bit operands
      // --------------------------------------------------------------------------

      s_rs1 = $signed(rs1);
      s_rs2 = $signed(rs2);

      // --------------------------------------------------------------------------
      // 32-bit operands for MULW
      //
      // IMPORTANT:
      // MULW ignores bits [63:32] and interprets bits [31:0] as signed 32-bit.
      // --------------------------------------------------------------------------

      s_rs1_w = $signed(rs1[31:0]);
      s_rs2_w = $signed(rs2[31:0]);

      // --------------------------------------------------------------------------
      // Full-width products
      // --------------------------------------------------------------------------

      unsigned_product         = $unsigned(rs1) * $unsigned(rs2);
      signed_product           = s_rs1 * s_rs2;
      signed_unsigned_product  = s_rs1 * $signed({1'b0, rs2});

      result = 64'b0;

      // --------------------------------------------------------------------------
      // MUL
      //
      // Return low 64 bits of signed 64x64 multiplication.
      // --------------------------------------------------------------------------

      if (is_mul) begin

        result = signed_product[63:0];

      end

      // --------------------------------------------------------------------------
      // MULH
      //
      // Return high 64 bits of signed 64x64 multiplication.
      // --------------------------------------------------------------------------

      else if (is_mulh) begin

        result = signed_product[127:64];

      end

      // --------------------------------------------------------------------------
      // MULHSU
      //
      // rs1 = signed 64-bit
      // rs2 = unsigned 64-bit
      // Return high 64 bits.
      // --------------------------------------------------------------------------

      else if (is_mulhsu) begin

        result = signed_unsigned_product[127:64];

      end

      // --------------------------------------------------------------------------
      // MULHU
      //
      // Unsigned 64x64 multiplication.
      // Return high 64 bits.
      // --------------------------------------------------------------------------

      else if (is_mulhu) begin

        result = unsigned_product[127:64];

      end

      ///////////////////////////////////////////////////////////////////////////
      // MULW
      //
      // RISC-V RV64 semantics:
      //
      //   1. Take rs1[31:0]
      //   2. Take rs2[31:0]
      //   3. Treat both as signed 32-bit values
      //   4. Multiply
      //   5. Keep the LOW 32 bits
      //   6. Sign-extend those 32 bits to 64 bits
      //
      // Do NOT simply assign the 32-bit multiplication directly to a
      // 64-bit result without making the sign extension explicit.
      ///////////////////////////////////////////////////////////////////////////

      else if (is_mulw) begin

        // Signed 32-bit multiplication.
        mulw_product = s_rs1_w * s_rs2_w;

        // Keep only the low 32 bits.
        mulw_result32 = mulw_product[31:0];

        // Explicit sign extension from bit 31 to bits [63:32].
        result = {{32{mulw_result32[31]}}, mulw_result32};

      end

      calculate_expected = result;

    end

  endfunction


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ISSUE TRANSACTION
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic issue_operation(
      input logic [63:0] rs1,
      input logic [63:0] rs2,
      input logic [5:0]  rd,
      input string       operation
  );

    begin

      @(negedge clk_i);

      rs1_i = rs1;
      rs2_i = rs2;
      rd_i  = rd;

      MUL_i    = 1'b0;
      MULH_i   = 1'b0;
      MULHSU_i = 1'b0;
      MULHU_i  = 1'b0;
      MULW_i   = 1'b0;

      case (operation)

        "MUL": begin
          MUL_i = 1'b1;
        end

        "MULH": begin
          MULH_i = 1'b1;
        end

        "MULHSU": begin
          MULHSU_i = 1'b1;
        end

        "MULHU": begin
          MULHU_i = 1'b1;
        end

        "MULW": begin
          MULW_i = 1'b1;
        end

        default: begin
          $display("ERROR: Unknown operation %s", operation);
        end

      endcase

      valid_i = 1'b1;

      // Wait until the DUT accepts the transaction.
      while (!ready_o) begin
        @(posedge clk_i);
      end

      @(posedge clk_i);

      @(negedge clk_i);

      valid_i = 1'b0;

      MUL_i    = 1'b0;
      MULH_i   = 1'b0;
      MULHSU_i = 1'b0;
      MULHU_i  = 1'b0;
      MULW_i   = 1'b0;

    end

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // WAIT FOR RESULT
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic wait_result(
      input logic [63:0] expected_data,
      input logic [5:0]  expected_rd,
      input logic [1:0]  expected_size,
      input string       case_name
  );
  
    logic result;
    logic [63:0] expected_compare_data;
  
    begin
    
      // Wait for the output transaction.
      while (!valid_o) begin
        @(posedge clk_i);
      end
    
      #1;
    
      ///////////////////////////////////////////////////////////////////////////////////
      // MULW handling
      //
      // The DUT returns the valid 32-bit MULW result in wr_data_o[31:0].
      // The testbench performs RV64 sign extension for comparison.
      ///////////////////////////////////////////////////////////////////////////////////
    
      if (expected_size == 2'b10) begin
      
        expected_compare_data = {
            {32{wr_data_o[31]}},
            wr_data_o[31:0]
        };
      
      end
      else begin
      
        expected_compare_data = wr_data_o;
      
      end
    
      result = (
          (expected_compare_data === expected_data) &&
          (wr_addr_o === expected_rd) &&
          (wr_size_o === expected_size)
      );
    
      if (result) begin
      
        $display(
            "PASS: %-35s | DATA=%h | RD=%0d | SIZE=%b",
            case_name,
            expected_compare_data,
            wr_addr_o,
            wr_size_o
        );
      
      end
    
      else begin
      
        $display(
            "FAIL: %-35s | DATA=%h (exp=%h) | RD=%0d (exp=%0d) | SIZE=%b (exp=%b)",
            case_name,
            expected_compare_data,
            expected_data,
            wr_addr_o,
            expected_rd,
            wr_size_o,
            expected_size
        );
      
      end
    
      note_case(result);
    
      // Consume the output transaction.
      @(posedge clk_i);
    
    end
  
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RUN SINGLE OPERATION
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic run_operation(
      input logic [63:0] rs1,
      input logic [63:0] rs2,
      input logic [5:0]  rd,
      input string       operation,
      input string       case_name
  );

    logic [63:0] expected_data;
    logic [1:0]  expected_size;

    begin

      expected_data = calculate_expected(
          rs1,
          rs2,
          operation == "MUL",
          operation == "MULH",
          operation == "MULHSU",
          operation == "MULHU",
          operation == "MULW"
      );

      if (operation == "MULW")
        expected_size = 2'b10;
      else
        expected_size = 2'b11;

      ready_i = 1'b1;

      issue_operation(
          rs1,
          rs2,
          rd,
          operation
      );

      wait_result(
          expected_data,
          rd,
          expected_size,
          case_name
      );

    end

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 1
  // RESET / IDLE
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_1_reset_idle();

    $display("\n========== TEST 1: RESET / IDLE ==========");

    reset_dut();

    #1;

    if (!valid_o && ready_i) begin
      $display("PASS: TEST 1: RESET / IDLE");
      note_case(1'b1);
    end

    else begin
      $display(
          "FAIL: TEST 1: RESET / IDLE | valid_o=%b ready_i=%b",
          valid_o,
          ready_i
      );
      note_case(1'b0);
    end

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 2
  // MUL BASIC
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_2_mul_basic();

    $display("\n========== TEST 2: MUL BASIC ==========");

    reset_dut();

    run_operation(
        64'd3,
        64'd7,
        6'd1,
        "MUL",
        "TEST 2.1: 3 * 7"
    );

    run_operation(
        64'd10,
        64'd20,
        6'd2,
        "MUL",
        "TEST 2.2: 10 * 20"
    );

    run_operation(
        64'd100,
        64'd1000,
        6'd3,
        "MUL",
        "TEST 2.3: 100 * 1000"
    );

    run_operation(
        64'h0000_0000_FFFF_FFFF,
        64'h0000_0000_0000_0002,
        6'd4,
        "MUL",
        "TEST 2.4: 0xFFFFFFFF * 2"
    );

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 3
  // MUL SIGN CASES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_3_mul_sign_cases();

    $display("\n========== TEST 3: MUL SIGN CASES ==========");

    reset_dut();

    run_operation(
        64'h0000_0000_0000_0005,
        64'h0000_0000_0000_0007,
        6'd1,
        "MUL",
        "TEST 3.1: POS * POS"
    );

    run_operation(
        -64'sd5,
        64'd7,
        6'd2,
        "MUL",
        "TEST 3.2: NEG * POS"
    );

    run_operation(
        64'd5,
        -64'sd7,
        6'd3,
        "MUL",
        "TEST 3.3: POS * NEG"
    );

    run_operation(
        -64'sd5,
        -64'sd7,
        6'd4,
        "MUL",
        "TEST 3.4: NEG * NEG"
    );

    run_operation(
        64'h8000_0000_0000_0000,
        64'd2,
        6'd5,
        "MUL",
        "TEST 3.5: MIN_INT * 2"
    );

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 4
  // MULH
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_4_mulh_basic();

    $display("\n========== TEST 4: MULH BASIC ==========");

    reset_dut();

    run_operation(
        64'd1,
        64'd2,
        6'd1,
        "MULH",
        "TEST 4.1: 1 * 2"
    );

    run_operation(
        64'h7FFF_FFFF_FFFF_FFFF,
        64'h7FFF_FFFF_FFFF_FFFF,
        6'd2,
        "MULH",
        "TEST 4.2: MAX_POS * MAX_POS"
    );

    run_operation(
        64'h8000_0000_0000_0000,
        64'd2,
        6'd3,
        "MULH",
        "TEST 4.3: MIN_INT * 2"
    );

    run_operation(
        -64'sd10,
        64'd20,
        6'd4,
        "MULH",
        "TEST 4.4: NEG * POS"
    );

    run_operation(
        -64'sd10,
        -64'sd20,
        6'd5,
        "MULH",
        "TEST 4.5: NEG * NEG"
    );

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 5
  // MULHSU
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_5_mulhsu_basic();

    $display("\n========== TEST 5: MULHSU BASIC ==========");

    reset_dut();

    run_operation(
        64'd5,
        64'd7,
        6'd1,
        "MULHSU",
        "TEST 5.1: POS * UNSIGNED"
    );

    run_operation(
        -64'sd5,
        64'd7,
        6'd2,
        "MULHSU",
        "TEST 5.2: NEG * UNSIGNED"
    );

    run_operation(
        -64'sd1,
        64'hFFFF_FFFF_FFFF_FFFF,
        6'd3,
        "MULHSU",
        "TEST 5.3: -1 * UINT_MAX"
    );

    run_operation(
        -64'sd10,
        64'h8000_0000_0000_0000,
        6'd4,
        "MULHSU",
        "TEST 5.4: NEG * UINT_MIN"
    );

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 6
  // MULHU
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_6_mulhu_basic();

    $display("\n========== TEST 6: MULHU BASIC ==========");

    reset_dut();

    run_operation(
        64'd1,
        64'd2,
        6'd1,
        "MULHU",
        "TEST 6.1: 1 * 2"
    );

    run_operation(
        64'hFFFF_FFFF_FFFF_FFFF,
        64'd2,
        6'd2,
        "MULHU",
        "TEST 6.2: UINT_MAX * 2"
    );

    run_operation(
        64'hFFFF_FFFF_FFFF_FFFF,
        64'hFFFF_FFFF_FFFF_FFFF,
        6'd3,
        "MULHU",
        "TEST 6.3: UINT_MAX * UINT_MAX"
    );

    run_operation(
        64'h8000_0000_0000_0000,
        64'h8000_0000_0000_0000,
        6'd4,
        "MULHU",
        "TEST 6.4: UINT_MIN * UINT_MIN"
    );

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 7
  // MULW
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_7_mulw_basic();

    $display("\n========== TEST 7: MULW BASIC ==========");

    reset_dut();

    // 32-bit: 3 * 7 = 21
    // Expected: 00000000_00000015
    run_operation(
        64'h0000_0000_0000_0003,
        64'h0000_0000_0000_0007,
        6'd1,
        "MULW",
        "TEST 7.1: 3 * 7"
    );

    // 32-bit: -1 * 2 = -2
    // Expected: FFFFFFFF_FFFFFFFE
    run_operation(
        64'h0000_0000_FFFF_FFFF,
        64'h0000_0000_0000_0002,
        6'd2,
        "MULW",
        "TEST 7.2: -1 * 2"
    );

    // 32-bit: INT_MIN * 2
    //
    // 80000000 = -2147483648
    // -2147483648 * 2 = -4294967296
    // Low 32 bits = 00000000
    // Sign extension = 00000000_00000000
    run_operation(
        64'h0000_0000_8000_0000,
        64'h0000_0000_0000_0002,
        6'd3,
        "MULW",
        "TEST 7.3: INT_MIN * 2"
    );

    // 32-bit: INT_MAX * 2
    //
    // 7FFFFFFF = 2147483647
    // 2147483647 * 2 = 4294967294
    // Low 32 bits = FFFFFFFE
    // Sign extension = FFFFFFFF_FFFFFFFE
    run_operation(
        64'h0000_0000_7FFF_FFFF,
        64'h0000_0000_0000_0002,
        6'd4,
        "MULW",
        "TEST 7.4: INT_MAX * 2"
    );

    // 32-bit: -1 * -1 = +1
    // Expected: 00000000_00000001
    run_operation(
        64'hFFFF_FFFF_FFFF_FFFF,
        64'hFFFF_FFFF_FFFF_FFFF,
        6'd5,
        "MULW",
        "TEST 7.5: -1 * -1"
    );

  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 8
  // BOUNDARY VALUES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_8_boundary_values();

    $display("\n========== TEST 8: BOUNDARY VALUES ==========");

    reset_dut();

    run_operation(
        64'd0,
        64'd0,
        6'd1,
        "MUL",
        "TEST 8.1: ZERO * ZERO"
    );

    run_operation(
        64'd0,
        64'hFFFF_FFFF_FFFF_FFFF,
        6'd2,
        "MUL",
        "TEST 8.2: ZERO * UINT_MAX"
    );

    run_operation(
        64'd1,
        64'hFFFF_FFFF_FFFF_FFFF,
        6'd3,
        "MUL",
        "TEST 8.3: ONE * UINT_MAX"
    );

    run_operation(
        64'hFFFF_FFFF_FFFF_FFFF,
        64'hFFFF_FFFF_FFFF_FFFF,
        6'd4,
        "MULHU",
        "TEST 8.4: UINT_MAX * UINT_MAX"
    );

    run_operation(
        64'h8000_0000_0000_0000,
        64'h8000_0000_0000_0000,
        6'd5,
        "MULH",
        "TEST 8.5: MIN_INT * MIN_INT"
    );

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 9
  // BACKPRESSURE
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_9_backpressure();

    logic [63:0] expected_data;

    $display("\n========== TEST 9: BACKPRESSURE ==========");

    reset_dut();

    expected_data = calculate_expected(
        64'd123,
        64'd456,
        1'b1,
        1'b0,
        1'b0,
        1'b0,
        1'b0
    );

    ready_i = 1'b0;

    issue_operation(
        64'd123,
        64'd456,
        6'd10,
        "MUL"
    );

    // The result must remain valid while downstream is stalled.
    wait (valid_o == 1'b1);

    repeat (5) begin

      @(posedge clk_i);
      #1;

      if (valid_o &&
          wr_data_o === expected_data &&
          wr_addr_o === 6'd10) begin

        $display(
            "PASS: TEST 9: BACKPRESSURE HOLD | DATA=%h | RD=%0d",
            wr_data_o,
            wr_addr_o
        );

      end

      else begin

        $display(
            "FAIL: TEST 9: BACKPRESSURE HOLD | DATA=%h | RD=%0d | VALID=%b",
            wr_data_o,
            wr_addr_o,
            valid_o
        );

      end

    end

    // Release downstream backpressure.
    ready_i = 1'b1;

    @(posedge clk_i);

    #1;

    if (!valid_o || ready_i) begin
      $display("PASS: TEST 9: BACKPRESSURE RELEASE");
      note_case(1'b1);
    end

    else begin
      $display("FAIL: TEST 9: BACKPRESSURE RELEASE");
      note_case(1'b0);
    end

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 10
  // SEQUENTIAL OPERATIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_10_sequential_operations();

    $display("\n========== TEST 10: SEQUENTIAL OPERATIONS ==========");

    reset_dut();

    run_operation(
        64'd2,
        64'd3,
        6'd1,
        "MUL",
        "TEST 10.1: MUL 2 * 3"
    );

    run_operation(
        64'd4,
        64'd5,
        6'd2,
        "MULH",
        "TEST 10.2: MULH 4 * 5"
    );

    run_operation(
        -64'sd6,
        64'd7,
        6'd3,
        "MULHSU",
        "TEST 10.3: MULHSU -6 * 7"
    );

    run_operation(
        64'hFFFF_FFFF_FFFF_FFFF,
        64'd2,
        6'd4,
        "MULHU",
        "TEST 10.4: MULHU UINT_MAX * 2"
    );

    run_operation(
        64'hFFFF_FFFF,
        64'd2,
        6'd5,
        "MULW",
        "TEST 10.5: MULW -1 * 2"
    );

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 11
  // RANDOMIZED
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_11_randomized();

    logic [63:0] random_rs1;
    logic [63:0] random_rs2;

    $display("\n========== TEST 11: RANDOMIZED ==========");

    reset_dut();

    for (int i = 0; i < 20; i++) begin

      random_rs1 = {$urandom(), $urandom()};
      random_rs2 = {$urandom(), $urandom()};

      run_operation(
          random_rs1,
          random_rs2,
          i[5:0],
          "MUL",
          $sformatf("TEST 11.%0d: RANDOM MUL", i + 1)
      );

    end

    for (int i = 0; i < 20; i++) begin

      random_rs1 = {$urandom(), $urandom()};
      random_rs2 = {$urandom(), $urandom()};

      run_operation(
          random_rs1,
          random_rs2,
          i[5:0],
          "MULH",
          $sformatf("TEST 11.%0d: RANDOM MULH", i + 21)
      );

    end

    for (int i = 0; i < 20; i++) begin

      random_rs1 = {$urandom(), $urandom()};
      random_rs2 = {$urandom(), $urandom()};

      run_operation(
          random_rs1,
          random_rs2,
          i[5:0],
          "MULHSU",
          $sformatf("TEST 11.%0d: RANDOM MULHSU", i + 41)
      );

    end

    for (int i = 0; i < 20; i++) begin

      random_rs1 = {$urandom(), $urandom()};
      random_rs2 = {$urandom(), $urandom()};

      run_operation(
          random_rs1,
          random_rs2,
          i[5:0],
          "MULHU",
          $sformatf("TEST 11.%0d: RANDOM MULHU", i + 61)
      );

    end

    for (int i = 0; i < 20; i++) begin

      random_rs1 = {$urandom(), $urandom()};
      random_rs2 = {$urandom(), $urandom()};

      run_operation(
          random_rs1,
          random_rs2,
          i[5:0],
          "MULW",
          $sformatf("TEST 11.%0d: RANDOM MULW", i + 81)
      );

    end

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST 12
  // MIXED OPERATIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic test_12_mixed_operations();

    $display("\n========== TEST 12: MIXED OPERATIONS ==========");

    reset_dut();

    run_operation(
        64'h0000_0000_0000_0003,
        64'h0000_0000_0000_0004,
        6'd1,
        "MUL",
        "TEST 12.1: MUL"
    );

    run_operation(
        64'h7FFF_FFFF_FFFF_FFFF,
        64'h7FFF_FFFF_FFFF_FFFF,
        6'd2,
        "MULH",
        "TEST 12.2: MULH"
    );

    run_operation(
        -64'sd100,
        64'hFFFF_FFFF_FFFF_FFF0,
        6'd3,
        "MULHSU",
        "TEST 12.3: MULHSU"
    );

    run_operation(
        64'hFFFF_FFFF_FFFF_FFFF,
        64'h0000_0000_0000_0010,
        6'd4,
        "MULHU",
        "TEST 12.4: MULHU"
    );

    run_operation(
        64'h0000_0000_0000_0010,
        64'h0000_0000_0000_0020,
        6'd5,
        "MULW",
        "TEST 12.5: MULW"
    );

    run_operation(
        -64'sd123456,
        64'sd789,
        6'd6,
        "MUL",
        "TEST 12.6: NEG MUL"
    );

    run_operation(
        64'h8000_0000_0000_0000,
        64'hFFFF_FFFF_FFFF_FFFF,
        6'd7,
        "MULH",
        "TEST 12.7: MIN_INT MULH"
    );

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // MAIN TEST
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin

    // Initialize DUT inputs.
    clk_i = 1'b0;

    arst_ni = 1'b0;

    MUL_i    = 1'b0;
    MULH_i   = 1'b0;
    MULHSU_i = 1'b0;
    MULHU_i  = 1'b0;
    MULW_i   = 1'b0;

    rs1_i = '0;
    rs2_i = '0;
    rd_i  = '0;

    valid_i = 1'b0;
    ready_i = 1'b1;

    $display("\n");
    $display("============================================================");
    $display("       ADN RISCV M64 MULTIPLIER DIRECTED TESTBENCH");
    $display("============================================================");
    $display("DATA_WIDTH = 64");
    $display("PIPELINE   = MULTI-STAGE");

    // Only the selected test is executed unless TC_ALL is specified.
    case (test_name)

      "TC_001", "reset_idle":
        test_1_reset_idle();

      "TC_002", "mul_basic":
        test_2_mul_basic();

      "TC_003", "mul_sign_cases":
        test_3_mul_sign_cases();

      "TC_004", "mulh_basic":
        test_4_mulh_basic();

      "TC_005", "mulhsu_basic":
        test_5_mulhsu_basic();

      "TC_006", "mulhu_basic":
        test_6_mulhu_basic();

      "TC_007", "mulw_basic":
        test_7_mulw_basic();

      "TC_008", "boundary_values":
        test_8_boundary_values();

      "TC_009", "backpressure":
        test_9_backpressure();

      "TC_010", "sequential_operations":
        test_10_sequential_operations();

      "TC_011", "randomized":
        test_11_randomized();

      "TC_012", "mixed_operations":
        test_12_mixed_operations();

      "TC_ALL", "default": begin

        test_1_reset_idle();
        test_2_mul_basic();
        test_3_mul_sign_cases();
        test_4_mulh_basic();
        test_5_mulhsu_basic();
        test_6_mulhu_basic();
        test_7_mulw_basic();
        test_8_boundary_values();
        test_9_backpressure();
        test_10_sequential_operations();
        test_11_randomized();
        test_12_mixed_operations();

      end

    endcase

    $display("\n============================================================");
    $display("             MULTIPLIER TEST COMPLETE");
    $display("==============================================================");

    $finish;

  end

endmodule
