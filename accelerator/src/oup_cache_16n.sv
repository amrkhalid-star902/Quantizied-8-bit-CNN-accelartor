`timescale 1ns / 1ps

`include "data_types.svh"

module oup_cache_16n(
    //system parameters
    input  logic clk,
    input  logic resetn,
    input  logic cinv,     //cache invalidate
    input  logic freq,     //flush request
    output logic busy,     //busy flag
    
    //PE interface
    input  uint24_t  inp_addr,
    input  logic     inp_we,
    input  uint5_t   inp_pch,   //amount of data written from parallel channel
    input  uint128_t inp_wdata, 
    output logic     oup_rdy,
    output logic     oup_cmpl,
    
    //Memory interface
    output logic      oup_wreq,
    input  logic      inp_wack,
    output uint32_t   oup_waddr,
    output uint128_t  oup_wdata, 
    output uint16_t   oup_wstb,  
    output uint8_t    oup_wlen
);

    logic cvalid;       

    logic [15 : 0] wea;  
    logic [6 : 0] addra; 
    logic [6 : 0] addrb; 

    logic [31:0] write_ptr, read_ptr;	
    logic wen;
    uint8_t data_byte; 
    uint5_t oup_ch;     
    
    function uint16_t byte_mask(input logic [3:0] addr, input logic wen); 
        uint16_t mask;
        if(wen) begin
            case(addr)
                4'd0:  mask = 16'h0001;
                4'd1:  mask = 16'h0002;
                4'd2:  mask = 16'h0004;
                4'd3:  mask = 16'h0008;
                4'd4:  mask = 16'h0010;
                4'd5:  mask = 16'h0020;
                4'd6:  mask = 16'h0040;
                4'd7:  mask = 16'h0080;
                4'd8:  mask = 16'h0100;
                4'd9:  mask = 16'h0200;
                4'd10: mask = 16'h0400;
                4'd11: mask = 16'h0800;
                4'd12: mask = 16'h1000;
                4'd13: mask = 16'h2000;
                4'd14: mask = 16'h4000;
                default: mask = 16'h8000;
            endcase
        end else begin
            mask = 16'h0000;
        end
        return mask;
    endfunction

    function uint16_t wstrobe(input logic [3:0] byte_len); 
        uint16_t stb;
        case(byte_len)
            4'd0:  stb = 16'h0001;
            4'd1:  stb = 16'h0003;
            4'd2:  stb = 16'h0007;
            4'd3:  stb = 16'h000f;
            4'd4:  stb = 16'h001f;
            4'd5:  stb = 16'h003f;
            4'd6:  stb = 16'h007f;
            4'd7:  stb = 16'h00ff;
            4'd8:  stb = 16'h01ff;
            4'd9:  stb = 16'h03ff;
            4'd10: stb = 16'h07ff;
            4'd11: stb = 16'h0fff;
            4'd12: stb = 16'h1fff;
            4'd13: stb = 16'h3fff;
            4'd14: stb = 16'h7fff;
            default: stb = 16'hffff;
        endcase
        return stb;
    endfunction
    
    assign data_byte = inp_wdata[(oup_ch*8)+7-:8]; 
    
    
    //porta is used for writing
    //portb is used for reading
    dp_128x128_ram buffer2k ( 
      .clka(clk),                    // input wire clka
      .wea(wea),                     // input wire [15 : 0] wea
      .addra(addra),                 // input wire [6 : 0] addra
      .dina({16{data_byte}}),        // input wire [127 : 0] dina 
      .clkb(clk),                    // input wire clkb
      .addrb(addrb),                 // input wire [6 : 0] addrb
      .doutb(oup_wdata)              // output wire [127 : 0] doutb
    );
    
    enum {SWait, SWrite} seq_state;
    
    //Write sequencer FSM
    always_ff@(posedge clk) begin
        if(~resetn) begin
            seq_state <= SWait;
            oup_ch    <= 'd0;
            wen       <= 1'b0;
            write_ptr <= inp_addr;
        end else begin
            case(seq_state)
                SWait: begin
                    oup_ch <= 'd0;
                    if(inp_we) begin
                        write_ptr <= inp_addr;
                        seq_state <= SWrite;
                        wen       <= 1'b1;   
                    end else begin  
                        write_ptr <= inp_addr + inp_pch;
                    end
                end
                SWrite: begin
                    oup_ch    <= oup_ch + 'd1;
                    write_ptr <= write_ptr + 'd1;
                    if(oup_ch == inp_pch) begin
                        seq_state <= SWait; 
                        wen       <= 1'b0;    
                    end else begin
                        wen       <= 1'b1;
                    end
                end
            endcase
        end
    end
    
    assign wea   = byte_mask(write_ptr[3:0], wen); 
    assign addra = write_ptr[10:4];                
    assign addrb = inp_wack ? read_ptr[10:4] + 'd1 : read_ptr[10:4]; 
    
    logic eq;
    assign eq = read_ptr[31:4] == write_ptr[31:4]; 
    
    int wlen_wd, wlen_b;
    assign wlen_b   = write_ptr - read_ptr;
    assign wlen_wd  = wlen_b >> 4;                 
    assign oup_wstb = eq ? wstrobe(wlen_b[3:0]) : 16'hffff; 
    
    logic [6 : 0] wd_cnt;
    enum {Idle, Flush, WaitAck, Post} write_state;
    
    assign oup_cmpl = write_state == Idle;
    assign oup_rdy  = !cvalid || (write_ptr < (read_ptr + 1536));
    
    always_ff@(posedge clk) begin
        if(~resetn || cinv) begin
            write_state <= Idle;
            read_ptr    <= 'd0;
            cvalid      <= 1'b0;
            busy        <= 1'b0;
            oup_wreq    <= 1'b0;
            oup_wlen    <= 'd0;
            wd_cnt      <= 'd0;
            oup_waddr   <= 'd0;
        end else begin
            case(write_state)
                Idle: begin
                    if(!cvalid && inp_we) begin
                        cvalid <= 1'b1;
                    end
                    
                    if(!cvalid) read_ptr <= {write_ptr[31:9], 9'd0};
                    if(freq) begin
                        oup_waddr <= {read_ptr[31:9], 9'd0};
                        oup_wlen  <= wlen_wd;
                        wd_cnt      <= 'd0;
                        write_state <= Flush;
                        busy        <= 1'b1;
                    end else begin
                        if(cvalid && (write_ptr > (read_ptr+512+16))) begin
                           oup_waddr   <= {read_ptr[31:9], 9'd0}; 
                           oup_wreq    <= 1'b1;
                           oup_wlen    <= 8'd31;              
                           wd_cnt      <= 'd0;
                           write_state <= WaitAck;
                        end
                        busy <= 1'b0;
                    end
                end//Idle
                Flush: begin
                    if(write_ptr > read_ptr) begin
                        oup_wreq    <= 1'b1;
                        write_state <= WaitAck; 
                    end else begin
                        write_state <= Idle;
                        busy        <= 1'b0;
                    end
                end//Flush
                WaitAck: begin
                    if(inp_wack) begin
                        oup_wreq   <= 1'b0;
                        read_ptr   <= read_ptr + 'd16;     
                        wd_cnt     <= wd_cnt + 'd1;
                        
                        if(wd_cnt == oup_wlen) begin
                            write_state <= Post;    
                        end
                    end  
                end//WaitAck
                Post: begin
                    write_state <= busy ? Flush : Idle;
                end//Post
                default: write_state <= Idle;
            endcase
        end
    end
    
endmodule