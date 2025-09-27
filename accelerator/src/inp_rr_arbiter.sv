`timescale 1ns / 1ps

`include "data_types.svh"

module inp_rr_arbiter#(parameter NPE  = 2)(
    //system parameters
    input logic clk,
    input logic resetn,
    
    //Cache interface
    input  uint32_t  inp_baddr,
    input  logic     inp_rreq[NPE],
    input  uint24_t  inp_raddr[NPE],
    output logic     oup_rvalid[NPE],
    output uint128_t oup_rdata[NPE],
    
    //AXI Interface
    
    //Write address channel
    input  logic          inp_awready,
    output logic [31 : 0] oup_awaddr,
    output logic [7 : 0]  oup_awlen,
    output logic          oup_awvalid,
    
    //Write data channel
    input  logic           inp_wready,
    output logic [127 : 0] oup_wrdata,
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
    
    assign oup_awaddr  = 32'd0;
    assign oup_awlen   = 8'h00;
    assign oup_awvalid = 1'b0;
    assign oup_wrdata  = 128'd0;
    assign oup_wvalid  = 1'b0;
    assign oup_wlast   = 1'b0;
    
    logic [23 : 0] write_ptr;
    
    // Burst Configuration
    localparam BURST_NUM_TRANSFERS    = 128;    // Number of transfers per burst
    localparam TRANSFER_BYTES         = 16;     // Bytes per transfer (128 bits = 16 bytes)
    localparam BURST_BYTE_ADDR_BITS   = $clog2(BURST_NUM_TRANSFERS * TRANSFER_BYTES); // Bits to address bytes in a burst
    
    assign oup_araddr = {8'b0, write_ptr[23:BURST_BYTE_ADDR_BITS], (BURST_BYTE_ADDR_BITS)'(0)}+inp_baddr;
    assign oup_arlen  = 8'(BURST_NUM_TRANSFERS-1);
    
    uint8_t ch;
    
    always_comb begin
        for(int i = 0; i < NPE; i++) begin  
            if(i == ch) begin
                oup_rvalid[i] = inp_rvalid;
                oup_rdata[i]  = inp_rdata;
            end else begin
                oup_rvalid[i] = 1'b0;
                oup_rdata[i]  = 128'd0;           
            end
        end 
    end
    
    logic [7 : 0] wd_cnt;
    
    //AXI Sequencer FSM
    enum {Idle, Ack, Readcyc, Readcmd} read_state;
    wire zeros[NPE] = '{default:0};
    
    always_ff@(posedge clk) begin
        if(~resetn) begin
            read_state  <= Idle;
            oup_arvalid <= 1'b0;
            oup_rready  <= 1'b0;
            wd_cnt      <= 'd0;
            ch          <= 'd0;
        end else begin
            case(read_state)
                Idle: begin
                    oup_arvalid <= 1'b0; 
                    oup_rready  <= 1'b0;
                    wd_cnt      <= 'd0;
                    if(inp_rreq != zeros) begin
                        ch         <= ch_sel(inp_rreq);
                        read_state <= Ack;
                    end
                end
                Ack: begin
                   oup_arvalid <= 1'b1;
                   write_ptr   <= inp_raddr[ch];
                   read_state  <= Readcmd;
                end
                Readcmd: begin
                    if(inp_arready) begin
                        oup_arvalid <= 1'b0;
                        read_state  <= Readcyc;
                        oup_rready  <= 1'b1;  
                    end    
                end
                Readcyc: begin
                    if(inp_rvalid) wd_cnt <= wd_cnt + 'd1;
                    if(inp_rvalid && wd_cnt == oup_arlen) begin
                        read_state <= Idle;    
                    end
                end
                default: read_state <= Idle;
            endcase
        end
    end
    
endmodule
