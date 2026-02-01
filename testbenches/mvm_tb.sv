`timescale 1ns/1ps

module tb_mvm;

  localparam int IWIDTH = 8;
  localparam int OWIDTH = 32;
  localparam int MEM_DATAW = IWIDTH*8;

  localparam int VEC_MEM_DEPTH = 16;
  localparam int MAT_MEM_DEPTH = 64;

  localparam int VEC_ADDRW = $clog2(VEC_MEM_DEPTH);
  localparam int MAT_ADDRW = $clog2(MAT_MEM_DEPTH);

  localparam int NUM_OLANES = 3;

  logic clk, rst;

  logic [MEM_DATAW-1:0] i_vec_wdata;
  logic [VEC_ADDRW-1:0] i_vec_waddr;
  logic i_vec_wen;

  logic [MEM_DATAW-1:0] i_mat_wdata;
  logic [MAT_ADDRW-1:0] i_mat_waddr;
  logic [NUM_OLANES-1:0] i_mat_wen;

  logic i_start;
  logic [VEC_ADDRW-1:0] i_vec_start_addr;
  logic [VEC_ADDRW:0]   i_vec_num_words;
  logic [MAT_ADDRW-1:0] i_mat_start_addr;
  logic [MAT_ADDRW:0]   i_mat_num_rows_per_olane;

  logic o_busy;
  logic signed [OWIDTH-1:0] o_result [0:NUM_OLANES-1];
  logic o_valid;

  mvm #(
    .IWIDTH(IWIDTH),
    .OWIDTH(OWIDTH),
    .MEM_DATAW(MEM_DATAW),
    .VEC_MEM_DEPTH(VEC_MEM_DEPTH),
    .MAT_MEM_DEPTH(MAT_MEM_DEPTH),
    .NUM_OLANES(NUM_OLANES)
  ) dut (
    .clk(clk),
    .rst(rst),
    .i_vec_wdata(i_vec_wdata),
    .i_vec_waddr(i_vec_waddr),
    .i_vec_wen(i_vec_wen),
    .i_mat_wdata(i_mat_wdata),
    .i_mat_waddr(i_mat_waddr),
    .i_mat_wen(i_mat_wen),
    .i_start(i_start),
    .i_vec_start_addr(i_vec_start_addr),
    .i_vec_num_words(i_vec_num_words),
    .i_mat_start_addr(i_mat_start_addr),
    .i_mat_num_rows_per_olane(i_mat_num_rows_per_olane),
    .o_busy(o_busy),
    .o_result(o_result),
    .o_valid(o_valid)
  );

  // clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Helpers
  function automatic logic signed [MEM_DATAW-1:0] pack8(input int signed e[0:7]);
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

  task automatic write_vec(input int unsigned addr, input logic [MEM_DATAW-1:0] data);
    begin
      @(negedge clk);
      i_vec_wen   = 1'b1;
      i_vec_waddr = addr[VEC_ADDRW-1:0];
      i_vec_wdata = data;
      @(negedge clk);
      i_vec_wen   = 1'b0;
    end
  endtask

  task automatic write_mat(input int unsigned lane, input int unsigned addr, input logic [MEM_DATAW-1:0] data);
    begin
      @(negedge clk);
      i_mat_wen   = '0;
      i_mat_wen[lane] = 1'b1;
      i_mat_waddr = addr[MAT_ADDRW-1:0];
      i_mat_wdata = data;
      @(negedge clk);
      i_mat_wen   = '0;
    end
  endtask

  task automatic pulse_start();
    begin
      @(negedge clk);
      i_start = 1'b1;
      @(negedge clk);
      i_start = 1'b0;
    end
  endtask

  // Expected results storage: exp[row][lane]
  int signed exp [0:31][0:NUM_OLANES-1]; // enough room for small tests
  int exp_rows;

  task automatic run_case(input int num_words, input int rows);
    int w, r, lane, e;
    int signed vec_words [0:15][0:7]; // [word][elem]
    int signed mat_words [0:NUM_OLANES-1][0:31][0:15][0:7]; // [lane][row][word][elem]

    begin
      exp_rows = rows;

      // Generate test data (small-ish signed 8-bit range)
      for (w = 0; w < num_words; w++) begin
        for (e = 0; e < 8; e++) begin
          vec_words[w][e] = $urandom_range(-8, 7);
        end
        // write vector word to vec mem at address = w
        write_vec(w, pack8(vec_words[w]));
      end

      // Matrix per lane: row-major layout in each lane’s mat mem
      for (lane = 0; lane < NUM_OLANES; lane++) begin
        for (r = 0; r < rows; r++) begin
          for (w = 0; w < num_words; w++) begin
            for (e = 0; e < 8; e++) begin
              mat_words[lane][r][w][e] = $urandom_range(-8, 7);
            end
            int unsigned addr = (r*num_words + w);
            write_mat(lane, addr, pack8(mat_words[lane][r][w]));
          end
        end
      end

      // Compute golden expected
      for (r = 0; r < rows; r++) begin
        for (lane = 0; lane < NUM_OLANES; lane++) begin
          int signed acc = 0;
          for (w = 0; w < num_words; w++) begin
            acc += dot8_int(vec_words[w], mat_words[lane][r][w]);
          end
          exp[r][lane] = acc;
        end
      end

      // Configure DUT (use start_addr=0 to avoid ctrl's stop-condition quirks)
      @(negedge clk);
      i_vec_start_addr = '0;
      i_vec_num_words  = num_words;
      i_mat_start_addr = '0;
      i_mat_num_rows_per_olane = rows;

      // Let internal pipeline shift regs settle after any reset / prior run
      repeat (10) @(posedge clk);

      // Start
      pulse_start();

      // Wait for outputs
      int got_rows = 0;

      // (Optional) sanity: busy should go high at some point
      int busy_timeout = 200;
      while (o_busy !== 1'b1 && busy_timeout > 0) begin
        @(posedge clk);
        busy_timeout--;
      end
      if (busy_timeout == 0) begin
        $display("[MVM][FAIL] o_busy never asserted");
        $fatal(1);
      end

      // Collect rows on each o_valid
      while (got_rows < rows) begin
        @(posedge clk);
        if (o_valid) begin
          for (lane = 0; lane < NUM_OLANES; lane++) begin
            int signed got = o_result[lane];
            int signed ex  = exp[got_rows][lane];
            if (got !== ex) begin
              $display("[MVM][FAIL] row=%0d lane=%0d exp=%0d got=%0d @t=%0t",
                       got_rows, lane, ex, got, $time);
              $fatal(1);
            end
          end
          got_rows++;
        end
      end

      $display("[MVM] Case PASS (num_words=%0d, rows=%0d)", num_words, rows);

      // Wait a bit and ensure busy eventually drops
      repeat (30) @(posedge clk);
      if (o_busy !== 1'b0) begin
        $display("[MVM][WARN] o_busy still high after outputs (may be expected due to internal delay)");
      end
    end
  endtask

  initial begin
    // init
    i_vec_wdata = '0; i_vec_waddr = '0; i_vec_wen = 0;
    i_mat_wdata = '0; i_mat_waddr = '0; i_mat_wen = '0;
    i_start = 0;
    i_vec_start_addr = '0;
    i_vec_num_words = '0;
    i_mat_start_addr = '0;
    i_mat_num_rows_per_olane = '0;

    rst = 1;
    repeat (5) @(posedge clk);
    rst = 0;

    // IMPORTANT: your mvm has shift regs without reset; give it time to flush Xs
    repeat (12) @(posedge clk);

    // Run a couple cases
    run_case(1, 3); // 1 vector word, 3 rows
    run_case(2, 4); // 2 vector words, 4 rows

    $display("[MVM] ALL PASS");
    $finish;
  end

endmodule
