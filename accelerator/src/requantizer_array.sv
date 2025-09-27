`timescale 1ns / 1ps

`include "data_types.svh"

module requantizer_array#(
    parameter int N = 16,  // Number of PEs per row
    parameter int M = 16   // Number of rows
)(
    //system parameters
    input  logic clk,
    input  logic resetn,          
    input  logic start,      
    //input data     
    input  int32_t  inp_acc[M][N],
    input  int9_t   oup_zero,
    input  uint32_t inp_quant[N],
    output int8_t   oup_acc[M][N],
    output logic    oup_valid           
);
    // Wires to connect to the N requantizer instances
    logic           req_valid_in;
    int32_t         req_acc_in[N];
    int8_t          req_accd_out[N];
    logic [N-1:0]   req_valid_out;
    
    // Control logic
    enum {IDLE, PROCESSING} state, next_state;
    logic [$clog2(M+1)-1:0] m_counter, write_counter;
    
    // State machine logic
    always_ff @(posedge clk) begin
        if (~resetn) state <= IDLE;
        else         state <= next_state;
    end
    
    always_comb begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = PROCESSING;
            PROCESSING: if (m_counter == M - 1) next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    always_ff @(posedge clk) begin
        if (~resetn) begin
            m_counter <= 0;
        end else if (state == IDLE && next_state == PROCESSING) begin
            m_counter <= 0; 
        end else if (state == PROCESSING && m_counter < M - 1) begin
            m_counter <= m_counter + 1;
        end else if (state == PROCESSING && m_counter == M - 1) begin
            m_counter <= 0;  
        end
    end
    
    always_ff @(posedge clk) begin
        if (~resetn) begin
            write_counter <= 0;
        end else if (state == IDLE && next_state == PROCESSING) begin
            write_counter <= 0;
        end else if (req_valid_out[0]) begin
            if (write_counter < M-1) begin
                write_counter <= write_counter + 1;
            end else begin
                write_counter <= 0;  
            end
        end
    end
    
    assign req_valid_in = (state == PROCESSING);
    
    generate
        for (genvar i = 0; i < N; i++) begin
            assign req_acc_in[i]   = inp_acc[m_counter][i];
        end
    endgenerate
    
    always @(posedge clk) begin
        if (req_valid_out[0]) begin
            for (integer i = 0; i < N; i++) begin
                oup_acc[write_counter][i] <= req_accd_out[i];
            end
        end
    end
    
    generate
        for (genvar i = 0; i < N; i = i + 1) begin : requantizer_gen_block
            requantizer requantizer_inst (
                .clk          (clk),
                .resetn       (resetn),
                .valid_in     (req_valid_in),
                .acc_in       (req_acc_in[i]),
                .out_offs     (oup_zero),
                .quant        (inp_quant[i]),
                .accd         (req_accd_out[i]),
                .valid_out    (req_valid_out[i])
            );
        end
    endgenerate
    
    logic done_condition;
    assign done_condition = req_valid_out[0] && (write_counter == M-1);
    // Register the done pulse
    logic done_reg;
    always @(posedge clk) begin
        if (~resetn) done_reg <= 1'b0;
        else         done_reg <= done_condition;
    end
    
    assign oup_valid = done_reg;
    
endmodule