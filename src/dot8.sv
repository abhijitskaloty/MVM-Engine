/***************************************************/
/* 8-Lane Dot Product Module                       */
/***************************************************/

module dot8 # (
    parameter IWIDTH = 8,
    parameter OWIDTH = 32
)(
    input clk,
    input rst,
    input signed [8*IWIDTH-1:0] vec0,
    input signed [8*IWIDTH-1:0] vec1,
    input ivalid,
    output signed [OWIDTH-1:0] result,
    output ovalid
);

logic signed [IWIDTH-1:0] a [0:7];
logic signed [IWIDTH-1:0] b [0:7];
logic signed [2*IWIDTH-1:0] l1 [0:7];
logic signed [2*IWIDTH:0] l2 [0:3];
logic signed [2*IWIDTH+1:0] l3 [0:1];
logic signed [OWIDTH-1:0] l4;
logic valid [0:4];

integer i, j, k, l, m;
always_ff @ (posedge clk) begin
    if (rst) begin
        for (i = 0; i < 8; i = i + 1) begin
            a[i] <= 0;
            b[i] <= 0;
        end

        for (j = 0; j < 8; j = j + 1) begin
            l1[j] <= 0;
        end

        for (k = 0; k < 4; k = k + 1) begin
            l2[k] <= 0;
        end

        for (l = 0; l < 2; l = l + 1) begin
            l3[l] <= 0;
        end

        l4 <= 0;

        for (m = 0; m < 5; m = m + 1) begin
            valid[m] <= 0;
        end
    end else begin
        // Stage 1
        a[0] <= vec0[8*IWIDTH-1:7*IWIDTH];
        a[1] <= vec0[7*IWIDTH-1:6*IWIDTH];
        a[2] <= vec0[6*IWIDTH-1:5*IWIDTH];
        a[3] <= vec0[5*IWIDTH-1:4*IWIDTH];
        a[4] <= vec0[4*IWIDTH-1:3*IWIDTH];
        a[5] <= vec0[3*IWIDTH-1:2*IWIDTH];
        a[6] <= vec0[2*IWIDTH-1:1*IWIDTH];
        a[7] <= vec0[1*IWIDTH-1:0*IWIDTH];
        b[0] <= vec1[8*IWIDTH-1:7*IWIDTH];
        b[1] <= vec1[7*IWIDTH-1:6*IWIDTH];
        b[2] <= vec1[6*IWIDTH-1:5*IWIDTH];
        b[3] <= vec1[5*IWIDTH-1:4*IWIDTH];
        b[4] <= vec1[4*IWIDTH-1:3*IWIDTH];
        b[5] <= vec1[3*IWIDTH-1:2*IWIDTH];
        b[6] <= vec1[2*IWIDTH-1:1*IWIDTH];
        b[7] <= vec1[1*IWIDTH-1:0*IWIDTH];
        valid[0] <= ivalid;

        // Stage 2
        for (j = 0; j < 8; j = j + 1) begin
            l1[j] <= a[j] * b[j];
        end

        // Stage 3
        for (k = 0; k < 4; k = k + 1) begin
            l2[k] <= l1[2*k] + l1[2*k + 1];
        end

        // Stage 4
        for (l = 0; l < 2; l = l + 1) begin
            l3[l] <= l2[2*l] + l2[2*l + 1];
        end

        // Stage 5
        l4 <= l3[0] + l3[1];

        // Valids
        for (m = 1; m < 5; m = m + 1) begin
            valid[m] <= valid[m-1];
        end
    end
end

assign result = l4;
assign ovalid = valid[4];

endmodule