`timescale 1ns / 1ps

`include "data_types.svh"

module oup_rr_arbiter#(parameter NPE  = 2)(
    //system parameters
    input logic clk,
    input logic resetn,
    
    //Cache interface
    input  uint32_t  inp_baddr,
    input  logic     inp_wreq[NPE],
    input  uint32_t  inp_waddr[NPE],
    input  uint128_t inp_wdata[NPE],    
    input  uint16_t  inp_wstb[NPE],     
    input  uint8_t   inp_wlen[NPE],
    output logic     oup_wack[NPE],
    
    //AXI Interface
    
    //Write address channel
    input  logic          inp_awready,
    output logic [31 : 0] oup_awaddr,
    output logic [7 : 0]  oup_awlen,
    output logic          oup_awvalid,
    
    //Write data channel
    input  logic           inp_wready,
    output logic [127 : 0] oup_wrdata,  
    output logic [15  : 0] oup_wstb,    
    output logic           oup_wvalid,
    output logic           oup_wlast,
    
    //Read address channel
    input  logic          inp_arready,
    output logic [31 : 0] oup_araddr,
    output logic [7 : 0]  oup_arlen,
    output logic          oup_arvalid,
    
    //Read data channel
    input  logic [127 : 0] inp_rdata,   
    input  logic           inp_rvalid,
    input  logic           inp_rlast,
    output logic           oup_rready
);
    function uint8_t ch_sel(input logic rreq[NPE]);
        uint8_t i;
        ch_sel = NPE; 
        for(i = 0; i < NPE; i++) begin
            if(rreq[i]) begin
                ch_sel = i;
                break;
            end
        end
    endfunction
    assign oup_araddr  = 31'd0;
    assign oup_arlen   = 8'h00;
    assign oup_arvalid = 1'b0;
    assign oup_rready  = 1'b0;
    
    uint8_t ch;
    //The address is aligned with 512 bytes data sent (32x16) 
    assign oup_awaddr = inp_baddr + {inp_waddr[ch][31:9], 9'd0}; 
    assign oup_awlen  = inp_wlen[ch];
    assign oup_wrdata = inp_wdata[ch];
    assign oup_wstb   = inp_wstb[ch];
    
    always_comb begin
        for(int i = 0; i < NPE; i++) begin  
            if(i == ch) begin
                oup_wack[i] = inp_wready;
            end else begin
                oup_wack[i] = 1'b0;          
            end
        end 
    end
    
    logic [7 : 0] wd_cnt;
    //AXI Sequencer FSM
    enum {Idle, Ack, Writecyc, Writecmd} write_state;
    wire zeros[NPE]  = '{default:0};
    assign oup_wlast = inp_wready && (wd_cnt == oup_awlen);
    
    always_ff@(posedge clk) begin
        if(~resetn) begin
            write_state <= Idle;
            oup_awvalid <= 1'b0;
            oup_wvalid  <= 1'b0;
            wd_cnt      <= 'd0;
            ch          <= 'd0;
        end else begin
            case(write_state)
                Idle: begin
                    oup_awvalid <= 1'b0; 
                    oup_wvalid  <= 1'b0;
                    wd_cnt      <= 'd0;
                    if(inp_wreq != zeros) begin
                        ch          <= ch_sel(inp_wreq);
                        write_state <= Ack;
                    end
                end
                Ack: begin
                   oup_awvalid <= 1'b1;
                   write_state  <= Writecmd;
                end
                Writecmd: begin
                    if(inp_awready) begin
                        oup_awvalid <= 1'b0;
                        write_state <= Writecyc;
                        oup_wvalid  <= 1'b1;  
                    end    
                end
                Writecyc: begin
                    if(inp_wready) wd_cnt <= wd_cnt + 'd1;
                    if(inp_wready && wd_cnt == oup_awlen) begin
                        write_state <= Idle;    
                    end
                end
                default: write_state <= Idle;
            endcase
        end
    end
      
endmodule