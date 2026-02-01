`timescale 1ns/1ps

module tb_dot8;

  localparam int IWIDTH = 8;
  localparam int OWIDTH = 32;
  localparam int MEMW   = 8*IWIDTH;

  logic clk, rst;
  logic signed [MEMW-1:0] vec0, vec1;
  logic ivalid;
  logic signed [OWIDTH-1:0] result;
  logic ovalid;

  dot8 #(
    .IWIDTH(IWIDTH),
    .OWIDTH(OWIDTH)
  ) dut (
    .clk(clk),
    .rst(rst),
    .vec0(vec0),
    .vec1(vec1),
    .ivalid(ivalid),
    .result(result),
    .ovalid(ovalid)
  );

  // clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Pack helper: element[0] is MSB chunk (matches your slicing in dot8)
  function automatic logic signed [MEMW-1:0] pack8(input int signed e[0:7]);
    logic signed [IWIDTH-1:0] t[0:7];
    int i;
    begin
      for (i = 0; i < 8; i++) t[i] = e[i];
      pack8 = {t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7]};
    end
  endfunction

  function automatic int signed dot8_int(input int signed a[0:7], input int signed b[0:7]);
    int signed s;
    int i;
    begin
      s = 0;
      for (i = 0; i < 8; i++) s += a[i]*b[i];
      return s;
    end
  endfunction

  int signed exp_q[$];

  task automatic drive_once(input int signed a[0:7], input int signed b[0:7], input logic v);
    int signed exp;
    begin
      @(negedge clk);
      vec0   = pack8(a);
      vec1   = pack8(b);
      ivalid = v;
      exp    = dot8_int(a,b);
      if (v) exp_q.push_back(exp);
      @(posedge clk);
      #1;
    end
  endtask

  initial begin
    vec0 = '0; vec1 = '0; ivalid = 0;
    rst = 1;
    repeat (4) @(posedge clk);
    rst = 0;

    // Give one cycle after reset for clean pipeline behavior
    @(posedge clk);

    // Test 1: simple known vectors
    int signed a0[0:7] = '{1,2,3,4,5,6,7,8};
    int signed b0[0:7] = '{1,1,1,1,1,1,1,1}; // sum = 36
    drive_once(a0,b0,1);

    // Test 2: negatives
    int signed a1[0:7] = '{-1,-2,-3,-4,-5,-6,-7,-8};
    int signed b1[0:7] = '{ 1, 2, 3, 4, 5, 6, 7, 8};
    drive_once(a1,b1,1);

    // bubbles + back-to-back
    int signed a2[0:7] = '{5,0,-5,1,-1,2,-2,3};
    int signed b2[0:7] = '{2,2, 2,2, 2,2, 2,2};
    drive_once(a2,b2,0); // bubble
    drive_once(a2,b2,1);
    drive_once(a0,b0,1);

    // Run long enough to drain
    repeat (20) @(posedge clk);

    if (exp_q.size() != 0) begin
      $display("[DOT8][FAIL] expected queue not empty (%0d left)", exp_q.size());
      $fatal(1);
    end

    $display("[DOT8] PASS");
    $finish;
  end

  // Scoreboard: check on ovalid
  always_ff @(posedge clk) begin
    if (rst) begin
      exp_q.delete();
    end else begin
      if (ovalid) begin
        if (exp_q.size() == 0) begin
          $display("[DOT8][FAIL] ovalid with empty expected queue");
          $fatal(1);
        end
        int signed exp = exp_q.pop_front();
        int signed got = result;
        if (got !== exp) begin
          $display("[DOT8][FAIL] exp=%0d got=%0d @t=%0t", exp, got, $time);
          $fatal(1);
        end
      end
    end
  end

endmodule
