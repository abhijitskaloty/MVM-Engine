/***************************************************/
/* Accumulator Module                              */
/***************************************************/

module accum # (
    parameter DATAW = 32,
    parameter ACCUMW = 32
)(
    input  clk,
    input  rst,
    input  signed [DATAW-1:0] data,
    input  ivalid,
    input  first,
    input  last,
    output signed [ACCUMW-1:0] result,
    output ovalid
);

logic signed [ACCUMW-1:0] r_result;
logic r_ovalid;

always_ff @(posedge clk) begin
    if (rst) begin
        r_result <= 0;
        r_ovalid <= 0;
    end
    else if (ivalid) begin
        r_result <= (first) ? data : r_result + data;
        r_ovalid <= last;
    end
end

assign result = r_result;
assign ovalid = r_ovalid;

endmodule
