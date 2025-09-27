`timescale 1ns / 1ps

`include "data_types.svh"

module accumulator#(
    parameter N = 2
)(
    //system parameters
    input logic clk,
    input logic resetn,

    //control signals
    input logic inp_en,
    input logic inp_clr,
    input logic inp_rdy,
    input logic inp_valid,
    
    //data signals
    input int18_t inp_mul[N],
    input int32_t inp_bias[N],
    
    //accumulation output
    output int32_t  oup_accd[N],
    output logic    oup_mvalid
);

    (* MAX_FANOUT = 32 *) logic clr;
    (* MAX_FANOUT = 32 *) logic en, en1, en2, en3, en4, en5, en6; 
    (* MAX_FANOUT = 32 *) logic ben, ben1, ben2, ben3, ben4, ben5, ben6; 
    (* MAX_FANOUT = 32 *) logic en_d, en_d1, en_d2, en_d3, en_d4, en_d5, en_d6, en_d7;
    
    assign clr = inp_rdy && inp_clr;
    assign en  = inp_rdy && inp_en  && inp_valid;
    assign ben = inp_rdy && !inp_en && en_d;
    
    always_ff@(posedge clk) begin
        if(~resetn) begin
            en1       <= 1'b0;
            en2       <= 1'b0;
            en3       <= 1'b0;
            en4       <= 1'b0;
            en5       <= 1'b0;
            en6       <= 1'b0;
            ben1      <= 1'b0;
            ben2      <= 1'b0;
            ben3      <= 1'b0;
            ben4      <= 1'b0;
            ben5      <= 1'b0;
            ben6      <= 1'b0;
        end else begin
            en1       <= en;
            en2       <= en1;
            en3       <= en2;
            en4       <= en3;
            en5       <= en4;
            en6       <= en5;
            ben1      <= ben;
            ben2      <= ben1;
            ben3      <= ben2;
            ben4      <= ben3;
            ben5      <= ben4;
            ben6      <= ben5;
        end
    end
    
    int32_t acc_r1[N];

    always_ff@(posedge clk) begin
        if(~resetn) begin
            for(int i = 0; i < N; i++) begin
                acc_r1[i] <= 'd0;
            end
        end else if(clr) begin
            for(int i = 0; i < N; i++) begin
                acc_r1[i] <= 'd0;
            end
        end else if(en6) begin  
            for(int i = 0; i < N; i++) begin
                acc_r1[i] <= acc_r1[i] + inp_mul[i];
            end
        end else if(ben6) begin  
            for(int i = 0; i < N; i++) begin
                acc_r1[i] <= acc_r1[i] + inp_bias[i];
            end
        end
    end
    
    always_ff@(posedge clk) begin
        if(~resetn) begin
            en_d  <= 1'b0;
            en_d1 <= 1'b0;
            en_d2 <= 1'b0;
            en_d3 <= 1'b0;
            en_d4 <= 1'b0;
            en_d5 <= 1'b0;
            en_d6 <= 1'b0;
            en_d7 <= 1'b0;
        end else begin
            en_d  <= inp_en;
            en_d1 <= en_d;
            en_d2 <= en_d1;
            en_d3 <= en_d2;
            en_d4 <= en_d3;
            en_d5 <= en_d4;
            en_d6 <= en_d5;
            en_d7 <= en_d6;
        end
    end
    
    logic mvalid_r1; 
    
    always_ff@(posedge clk) begin
        if(~resetn) begin
            mvalid_r1  <= 1'b0;
            oup_mvalid <= 1'b0;
            for(int i = 0; i < N; i++) begin
                oup_accd[i] <= 'd0;
            end
        end else if(inp_rdy) begin
            mvalid_r1  <= !en_d6 && en_d7;  
            oup_mvalid <= mvalid_r1;
            for(int i = 0; i < N; i++) begin
                oup_accd[i] <= acc_r1[i];
            end
        end
    end

endmodule
