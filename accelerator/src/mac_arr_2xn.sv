`timescale 1ns / 1ps

`include "data_types.svh"

module mac_arr_2xn#(
    parameter N = 16
)(
    //system parameters
    input logic clk,
    input logic resetn,
    
    //control signals
    input logic inp_en,
    input logic inp_clr,
    input logic inp_rdy,
    input logic inp_valid1,
    input logic inp_valid2,
    
    //data signals
    input int8_t   inp_d1[N],
    input int8_t   inp_d2[N],
    input int8_t   inp_w[N],
    input int32_t  inp_bias[N],
    input int9_t   inp_zero,
    
    //output
    output int32_t  oup_acc1[N],
    output int32_t  oup_acc2[N],
    output logic    oup_valid
);

    int9_t   inp_d1_r[N];
    int9_t   inp_d2_r[N];
    int9_t   inp_w_r[N];
    int32_t  oup_acc[2][N];
    int32_t  acc1_r[N];
    int32_t  acc2_r[N];
    logic    inp_valid[2];
    logic    valid_r; 
    int8_t   i_d1[N];
    int8_t   i_d2[N];
    int8_t   i_w[N];
    
    always_ff@(posedge clk) begin
        if(~resetn) begin
            for(int i = 0; i < N; i++) begin
                inp_d1_r[i] <= 'd0;
                inp_d2_r[i] <= 'd0;    
                inp_w_r[i]  <= 'd0;
                i_d1[i]     <= 'd0;
                i_d2[i]     <= 'd0;
                i_w[i]      <= 'd0;
                oup_acc1[i] <= 'd0;
                oup_acc2[i] <= 'd0;    
            end
            oup_valid <= 1'b0;
        end else begin
            for(int i = 0; i < N; i++) begin
                i_d1[i]     <= inp_d1[i];
                i_d2[i]     <= inp_d2[i];
                i_w[i]      <= inp_w[i];
                inp_d1_r[i] <= int9_t'(i_d1[i]) + inp_zero;
                inp_d2_r[i] <= int9_t'(i_d2[i]) + inp_zero;    
                inp_w_r[i]  <= int9_t'(i_w[i]);
                oup_acc1[i] <= acc1_r[i];
                oup_acc2[i] <= acc2_r[i];    
            end    
            oup_valid <= valid_r;        
        end
    end
    
    int18_t mul_d[2][N];
    logic   valid[2];
    
    generate
        for(genvar i = 0; i < N; i++) begin
            int9_mul dual_multiplier (
                .clk(clk),
                .io_a(inp_w_r[i]),
                .io_b(inp_d1_r[i]),
                .io_c(inp_d2_r[i]),
                .io_ab(mul_d[0][i]),
                .io_ac(mul_d[1][i])  
            );
        end
        for(genvar i = 0; i < 2; i++) begin
            accumulator #(.N(N)) acc (
                .clk(clk),
                .resetn(resetn),
                .inp_en(inp_en),
                .inp_clr(inp_clr),
                .inp_rdy(inp_rdy),
                .inp_valid(inp_valid[i]),
                .inp_mul(mul_d[i]),
                .inp_bias(inp_bias),
                .oup_accd(oup_acc[i]),    
                .oup_mvalid(valid[i])    
            );
        end
    endgenerate

    always_comb begin
        for(int i = 0; i < N; i++) begin
            acc1_r[i] = oup_acc[0][i]; 
            acc2_r[i] = oup_acc[1][i];  
        end
        inp_valid[0] = inp_valid1;
        inp_valid[1] = inp_valid2;
        valid_r      = valid[0] & valid[1]; 
    end

endmodule
