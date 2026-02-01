`timescale 1ns/1ps

module tb_accum;

  localparam int DATAW  = 32;
  localparam int ACCUMW = 32;

  logic clk, rst;
  logic signed [DATAW-1:0] data;
  logic ivalid, first, last;
  logic signed [ACCUMW-1:0] result;
  logic ovalid;

  accum #(
    .DATAW(DATAW),
    .ACCUMW(ACCUMW)
  ) dut (
    .clk(clk),
    .rst(rst),
    .data(data),
    .ivalid(ivalid),
    .first(first),
    .last(last),
    .result(result),
    .ovalid(ovalid)
  );

  // clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  task automatic apply(
    input logic signed [DATAW-1:0] d,
    input logic v,
    input logic f,
    input logic l
  );
    begin
      @(negedge clk);
      data   = d;
      ivalid = v;
      first  = f;
      last   = l;
      @(posedge clk);
      #1;
    end
  endtask

  task automatic expect(
    input logic signed [ACCUMW-1:0] exp_result,
    input logic exp_ovalid
  );
    begin
      if (result !== exp_result) begin
        $display("[ACCUM][FAIL] exp result=%0d got=%0d @t=%0t", exp_result, result, $time);
        $fatal(1);
      end
      if (ovalid !== exp_ovalid) begin
        $display("[ACCUM][FAIL] exp ovalid=%0b got=%0b @t=%0t", exp_ovalid, ovalid, $time);
        $fatal(1);
      end
    end
  endtask

  initial begin
    // init
    data = '0; ivalid = 0; first = 0; last = 0;
    rst = 1;
    repeat (3) @(posedge clk);
    rst = 0;

    // NOTE: accum only updates outputs when ivalid=1.
    // ovalid is set to "last" on valid beats and otherwise holds its value.

    // Sequence: 5, -2, 10 (last on 10)
    apply(32'sd5,  1, 1, 0);  expect(32'sd5,  1'b0);
    apply(-32'sd2, 1, 0, 0);  expect(32'sd3,  1'b0);
    apply(32'sd10, 1, 0, 1);  expect(32'sd13, 1'b1);

    // Clear ovalid by sending another valid beat with last=0
    apply(32'sd7,  1, 1, 0);  expect(32'sd7,  1'b0);

    // Bubble (ivalid=0) -> outputs should HOLD
    apply(32'sd0,  0, 0, 0);  expect(32'sd7,  1'b0);

    $display("[ACCUM] PASS");
    $finish;
  end

endmodule
