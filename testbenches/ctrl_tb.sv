`timescale 1ns/1ps

module tb_ctrl;

  localparam int VEC_ADDRW = 4;
  localparam int MAT_ADDRW = 5;
  localparam int VEC_SIZEW = VEC_ADDRW + 1;
  localparam int MAT_SIZEW = MAT_ADDRW + 1;

  logic clk, rst, start;
  logic [VEC_ADDRW-1:0] vec_start_addr;
  logic [VEC_SIZEW-1:0] vec_num_words;
  logic [MAT_ADDRW-1:0] mat_start_addr;
  logic [MAT_SIZEW-1:0] mat_num_rows_per_olane;

  logic [VEC_ADDRW-1:0] vec_raddr;
  logic [MAT_ADDRW-1:0] mat_raddr;
  logic accum_first, accum_last, ovalid, busy;

  ctrl #(
    .VEC_ADDRW(VEC_ADDRW),
    .MAT_ADDRW(MAT_ADDRW)
  ) dut (
    .clk(clk),
    .rst(rst),
    .start(start),
    .vec_start_addr(vec_start_addr),
    .vec_num_words(vec_num_words),
    .mat_start_addr(mat_start_addr),
    .mat_num_rows_per_olane(mat_num_rows_per_olane),
    .vec_raddr(vec_raddr),
    .mat_raddr(mat_raddr),
    .accum_first(accum_first),
    .accum_last(accum_last),
    .ovalid(ovalid),
    .busy(busy)
  );

  // clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    start = 0;
    vec_start_addr = '0;
    vec_num_words = '0;
    mat_start_addr = '0;
    mat_num_rows_per_olane = '0;

    rst = 1;
    repeat (4) @(posedge clk);
    rst = 0;

    // Configure: vec words = 3, rows = 2, start addrs = 0
    @(negedge clk);
    vec_start_addr = 0;
    vec_num_words  = 3;
    mat_start_addr = 0;
    mat_num_rows_per_olane = 2;

    // Pulse start
    @(negedge clk);
    start = 1;
    @(posedge clk);
    @(negedge clk);
    start = 0;

    // Wait for busy to go high
    wait (busy === 1'b1);

    int total_cycles = int'(vec_num_words) * int'(mat_num_rows_per_olane);
    int cyc;

    // Check behavior while busy (expect total_cycles cycles of activity)
    for (cyc = 0; cyc < total_cycles; cyc++) begin
      @(posedge clk); #1;

      // busy and ovalid should generally be 1 during compute until the last internal cycle
      if (busy !== 1'b1) begin
        $display("[CTRL][FAIL] busy dropped early at cyc=%0d", cyc);
        $fatal(1);
      end

      // mat address monotonic increments starting at mat_start_addr
      if (mat_raddr !== (mat_start_addr + cyc)) begin
        $display("[CTRL][FAIL] mat_raddr exp=%0d got=%0d cyc=%0d", (mat_start_addr+cyc), mat_raddr, cyc);
        $fatal(1);
      end

      // vec address cycles over vec_num_words
      int exp_vec = int'(vec_start_addr) + (cyc % int'(vec_num_words));
      if (vec_raddr !== exp_vec[VEC_ADDRW-1:0]) begin
        $display("[CTRL][FAIL] vec_raddr exp=%0d got=%0d cyc=%0d", exp_vec, vec_raddr, cyc);
        $fatal(1);
      end

      // accum_first should pulse at start of each row (cyc % vec_num_words == 0)
      logic exp_first = ((cyc % int'(vec_num_words)) == 0);
      if (accum_first !== exp_first) begin
        $display("[CTRL][FAIL] accum_first exp=%0b got=%0b cyc=%0d", exp_first, accum_first, cyc);
        $fatal(1);
      end

      // accum_last (per your logic) pulses when vec_raddr == start + num_words - 2
      logic exp_last = ((cyc % int'(vec_num_words)) == (int'(vec_num_words)-2));
      if (accum_last !== exp_last) begin
        $display("[CTRL][FAIL] accum_last exp=%0b got=%0b cyc=%0d", exp_last, accum_last, cyc);
        $fatal(1);
      end
    end

    // After total_cycles, controller should soon deassert busy + ovalid
    repeat (3) @(posedge clk);
    if (busy !== 1'b0) begin
      $display("[CTRL][FAIL] busy did not deassert after done");
      $fatal(1);
    end

    $display("[CTRL] PASS");
    $finish;
  end

endmodule
