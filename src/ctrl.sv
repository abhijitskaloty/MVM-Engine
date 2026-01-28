/***************************************************/
/* MVM Control FSM                                 */
/***************************************************/

module ctrl # (
    parameter VEC_ADDRW = 8,
    parameter MAT_ADDRW = 9,
    parameter VEC_SIZEW = VEC_ADDRW + 1,
    parameter MAT_SIZEW = MAT_ADDRW + 1
    
)(
    input  clk,
    input  rst,
    input  start,
    input  [VEC_ADDRW-1:0] vec_start_addr,
    input  [VEC_SIZEW-1:0] vec_num_words,
    input  [MAT_ADDRW-1:0] mat_start_addr,
    input  [MAT_SIZEW-1:0] mat_num_rows_per_olane,
    output [VEC_ADDRW-1:0] vec_raddr,
    output [MAT_ADDRW-1:0] mat_raddr,
    output accum_first,
    output accum_last,
    output ovalid,
    output busy
);

enum {IDLE,COMPUTE} state, next_state;
logic [VEC_ADDRW-1:0] r_vec_start_addr;
logic [VEC_SIZEW-1:0] r_vec_num_words;
logic [MAT_ADDRW-1:0] r_mat_start_addr;
logic [MAT_SIZEW-1:0] r_mat_num_rows_per_olane;
logic [VEC_ADDRW-1:0] r_vec_raddr, vec_raddr_val;
logic [MAT_ADDRW-1:0] r_mat_raddr, mat_raddr_val;
logic accum_first_val, accum_last_val, ovalid_val, busy_val;
logic r_accum_first, r_accum_last, r_ovalid, r_busy, r_start;

always_ff @ (posedge clk) begin
    if (rst) begin
        state <= IDLE;
        r_vec_raddr <= 0; r_mat_raddr <= 0;
        r_accum_first <= 0; r_accum_last <= 0;
        r_ovalid <= 0; r_busy <= 0;
    end else begin
        state <= next_state;
        r_start <= start;
        if (state == IDLE) begin
            // Register inputs
            r_vec_start_addr <= vec_start_addr;
            r_vec_num_words <= vec_num_words;
            r_mat_start_addr <= mat_start_addr;
            r_mat_num_rows_per_olane <= mat_num_rows_per_olane;
            // Outputs
            r_vec_raddr <= vec_raddr_val; r_mat_raddr <= mat_raddr_val;
            r_accum_first <= accum_first_val; r_accum_last <= accum_last_val;
            r_ovalid <= ovalid_val; r_busy <= busy_val;
        end else if (state == COMPUTE) begin
            // Outputs
            r_vec_raddr <= vec_raddr_val; r_mat_raddr <= mat_raddr_val;
            r_accum_first <= accum_first_val; r_accum_last <= accum_last_val;
            r_ovalid <= ovalid_val; r_busy <= busy_val;
        end
    end
end

always_comb begin: state_decoder
    case (state)
        IDLE: next_state = (start) ? COMPUTE : IDLE;
        COMPUTE: next_state = (~r_start && ~busy_val) ? IDLE : COMPUTE;
        default: next_state = IDLE;
    endcase
end

always_comb begin: output_decoder
    case (state)
        IDLE: begin
            vec_raddr_val = 0; mat_raddr_val = 0;
            accum_first_val = 0; accum_last_val = 0;
            ovalid_val = 0; busy_val = 0;
        end

        COMPUTE: begin
            accum_last_val = 0;
            if ((r_start && ~r_vec_raddr) || (r_vec_raddr == r_vec_start_addr + r_vec_num_words - 1)) begin
                vec_raddr_val = r_vec_start_addr;
                accum_first_val = 1;
            end else begin
                vec_raddr_val = r_vec_raddr + 1;
                accum_first_val = 0;
                if (r_vec_raddr == r_vec_start_addr + r_vec_num_words - 2) accum_last_val = 1;
            end

            ovalid_val = 1;
            busy_val = 1;
            if (r_start && ~r_mat_raddr) begin
                mat_raddr_val = r_mat_start_addr;
            end else begin
                mat_raddr_val = r_mat_raddr + 1;
                if (r_mat_raddr == r_vec_num_words * r_mat_num_rows_per_olane - 1) begin
                    ovalid_val = 0;
                    busy_val = 0;
                end
            end
        end
    endcase
end

assign vec_raddr = r_vec_raddr;
assign mat_raddr = r_mat_raddr;
assign accum_first = r_accum_first;
assign accum_last = r_accum_last;
assign ovalid = r_ovalid;
assign busy = r_busy;

endmodule