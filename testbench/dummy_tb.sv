module dummy_tb;

  `include "vip/adn_common_tb_headers.sv"

  initial begin
    $display("Hello World");
    note_case(1);
    $finish;
  end

endmodule
