/***************************************************/
/* Matrix Vector Multiplication (MVM) Module       */
/***************************************************/

module mvm # (
    parameter IWIDTH = 8,
    parameter OWIDTH = 32,
    parameter MEM_DATAW = IWIDTH * 8,
    parameter VEC_MEM_DEPTH = 256,
    parameter VEC_ADDRW = $clog2(VEC_MEM_DEPTH),
    parameter MAT_MEM_DEPTH = 512,
    parameter MAT_ADDRW = $clog2(MAT_MEM_DEPTH),
    parameter NUM_OLANES = 8
)(
    input clk,
    input rst,
    input [MEM_DATAW-1:0] i_vec_wdata,
    input [VEC_ADDRW-1:0] i_vec_waddr,
    input i_vec_wen,
    input [MEM_DATAW-1:0] i_mat_wdata,
    input [MAT_ADDRW-1:0] i_mat_waddr,
    input [NUM_OLANES-1:0] i_mat_wen,
    input i_start,
    input [VEC_ADDRW-1:0] i_vec_start_addr,
    input [VEC_ADDRW:0] i_vec_num_words,
    input [MAT_ADDRW-1:0] i_mat_start_addr,
    input [MAT_ADDRW:0] i_mat_num_rows_per_olane,
    output o_busy,
    output [OWIDTH-1:0] o_result [0:NUM_OLANES-1],
    output o_valid
);

logic signed [MEM_DATAW-1:0] vec_rdata;
logic signed [MEM_DATAW-1:0] mem_rdata [0:NUM_OLANES-1];
logic signed [OWIDTH-1:0] dot_result [0:NUM_OLANES-1];
logic dot_ovalid [0:NUM_OLANES-1];
logic signed [OWIDTH-1:0] accum_result [0:NUM_OLANES-1];
logic accum_ovalid [0:NUM_OLANES-1];
logic [VEC_ADDRW-1:0] vec_raddr;
logic [MAT_ADDRW-1:0] mat_raddr;
logic ctrl_valid [0:1];
logic first [0:6];
logic last [0:6];
logic busy [0:6];

ctrl # (
    .VEC_ADDRW(VEC_ADDRW),
    .MAT_ADDRW(MAT_ADDRW)
) control (
    .clk(clk),
    .rst(rst),
    .start(i_start),
    .vec_start_addr(i_vec_start_addr),
    .vec_num_words(i_vec_num_words),
    .mat_start_addr(i_mat_start_addr),
    .mat_num_rows_per_olane(i_mat_num_rows_per_olane),
    .vec_raddr(vec_raddr),
    .mat_raddr(mat_raddr),
    .accum_first(first[0]),
    .accum_last(last[0]),
    .ovalid(ctrl_valid[0]),
    .busy(busy[0])
);

integer k, l;
always_ff @ (posedge clk) begin
    for (k = 1; k < 7; k = k + 1) begin
        first[k] <= first[k-1];
        last[k] <= last[k-1];
        busy[k] <= busy[k-1];
    end
    for (l = 1; l < 2; l = l + 1) begin
        ctrl_valid[l] <= ctrl_valid[l-1];
    end
end

mem # (
    .DATAW(MEM_DATAW),
    .DEPTH(VEC_MEM_DEPTH),
    .ADDRW(VEC_ADDRW)
) vec_mem (
    .clk(clk),
    .wdata(i_vec_wdata),
    .waddr(i_vec_waddr),
    .wen(i_vec_wen),
    .raddr(vec_raddr),
    .rdata(vec_rdata)
);

genvar i;
generate
    for (i = 0; i < NUM_OLANES; i = i + 1) begin: gen_olanes
        mem # (
            .DATAW(MEM_DATAW),
            .DEPTH(MAT_MEM_DEPTH),
            .ADDRW(MAT_ADDRW)
        ) mat_mem (
            .clk(clk),
            .wdata(i_mat_wdata),
            .waddr(i_mat_waddr),
            .wen(i_mat_wen[i]),
            .raddr(mat_raddr),
            .rdata(mem_rdata[i])
        );

        dot8 # (
            .IWIDTH(IWIDTH),
            .OWIDTH(OWIDTH)
        ) dot (
            .clk(clk),
            .rst(rst),
            .vec0(vec_rdata),
            .vec1(mem_rdata[i]),
            .ivalid(ctrl_valid[1]),
            .result(dot_result[i]),
            .ovalid(dot_ovalid[i])
        );

        accum # (
            .DATAW(OWIDTH),
            .ACCUMW(OWIDTH)
        ) accu (
            .clk(clk),
            .rst(rst),
            .data(dot_result[i]),
            .ivalid(dot_ovalid[i]),
            .first(first[6]),
            .last(last[6]),
            .result(accum_result[i]),
            .ovalid(accum_ovalid[i])
        );

        assign o_result[i] = accum_result[i];
    end
endgenerate

assign o_valid = accum_ovalid[0];
assign o_busy = busy[6];

endmodule