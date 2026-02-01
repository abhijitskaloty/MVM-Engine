/***************************************************/
/* Simple Memory Module                            */
/*                                                 */
/* - Single clock                                  */
/* - Synchronous write                             */
/* - Asynchronous read                             */
/***************************************************/

module mem #(
    parameter int DATAW = 64,
    parameter int DEPTH = 256,
    parameter int ADDRW = $clog2(DEPTH),
    parameter bit INIT_TO_ZERO = 1
)(
    input logic clk,
    input logic [DATAW-1:0] wdata,
    input logic [ADDRW-1:0] waddr,
    input logic wen,
    input logic [ADDRW-1:0] raddr,
    output logic [DATAW-1:0] rdata
);

    logic [DATAW-1:0] ram [0:DEPTH-1];

`ifndef SYNTHESIS
    initial begin
        if (INIT_TO_ZERO) begin
            for (int i = 0; i < DEPTH; i = i + 1) begin
                ram[i] = '0;
            end
        end
    end
`endif

    always_ff @(posedge clk) begin
        if (wen) begin
            ram[waddr] <= wdata;
        end
    end

    always_comb begin
        rdata = ram[raddr];
    end

endmodule
