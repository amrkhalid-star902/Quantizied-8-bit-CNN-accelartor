`timescale 1ns / 1ps

`include "data_types.svh"

module inp_cache_16n(
    //system parameters
    input logic clk,
    input logic resetn,
    input logic cinv,
    
    //PE interface
    input  logic     inp_dwen,
    input  logic     inp_ren,
    input  uint24_t  inp_raddr,
    output uint128_t oup_rdata,   
    output logic     oup_rdy,
    
    //Main memory interface
    output logic     oup_rreq,
    input  logic     inp_rvalid,
    output uint24_t  oup_raddr,
    input  uint128_t inp_rdata    
);

    // Cache Configuration
    localparam CACHE_NUM_BANKS        = 8;      // Number of independent cache banks
    localparam CACHE_BANK_ADDR_BITS   = $clog2(CACHE_NUM_BANKS); // Bits to address
    
    // Burst Configuration
    localparam BURST_NUM_TRANSFERS    = 128;    // Number of transfers per burst
    localparam TRANSFER_BYTES         = 16;     // Bytes per transfer (128 bits = 16 bytes)
    localparam BURST_BYTE_ADDR_BITS   = $clog2(BURST_NUM_TRANSFERS * TRANSFER_BYTES); // Bits to address bytes in a burst
    
    //Tag Store Configuration
    localparam ADDRW_BITS = 24;
    localparam TAGW_BITS  = ADDRW_BITS - BURST_BYTE_ADDR_BITS + 1; // Pluse 1 for valid 
    
    logic [TAGW_BITS-1 : 0] tag_store [CACHE_NUM_BANKS];
    logic [9 : 0]  addra;
    logic [9 : 0]  addrb; 
    uint128_t      doutb;
    logic [3 : 0]  byte_sel;
    
    logic [BURST_BYTE_ADDR_BITS : 0]   write_ptr;
    logic [ADDRW_BITS-1 :0 ]           read_ptr;
    logic [CACHE_NUM_BANKS-1 : 0]      pre_hits, hits, misses;
    logic [CACHE_BANK_ADDR_BITS-1 : 0] read_bank, write_bank, evicted_bank;
    
    dp_128x1024_ram main_buffer (
      .clka(clk),                // input wire clka
      .wea({16{inp_rvalid}}),    // input wire [15 : 0] wea
      .addra(addra),             // input wire [9 : 0] addra
      .dina(inp_rdata),          // input wire [127 : 0] dina
      .clkb(clk),                // input wire clkb
      .addrb(addrb),             // input wire [9 : 0] addrb
      .doutb(doutb)              // output wire [127 : 0] doutb
    );

    
    assign read_ptr    = inp_raddr;
    
    //Hit detection
    generate
        for(genvar i = 0; i < CACHE_NUM_BANKS; i++) begin
            assign pre_hits[i] = tag_store[i] == {1'b0, read_ptr[ADDRW_BITS-1:BURST_BYTE_ADDR_BITS]};
            assign hits[i]     = inp_ren && pre_hits[i];
            assign misses[i]   = inp_ren && !pre_hits[i];
        end
    endgenerate
        
    assign addra = {write_bank, write_ptr[BURST_BYTE_ADDR_BITS-1:4]};
    assign addrb = {read_bank,  read_ptr[BURST_BYTE_ADDR_BITS-1:4]};
    
    logic [7:0] selected_byte;
    assign selected_byte = doutb[(byte_sel*8) +: 8]; 
    assign oup_rdata     = inp_dwen ? doutb : {16{selected_byte}};
    
    logic rdy_r;
    assign rdy_r = (!inp_ren) || ((|hits) && (write_ptr > read_ptr[BURST_BYTE_ADDR_BITS-1:0]));

    logic [31:0] curr_read;
    assign curr_read = read_ptr[BURST_BYTE_ADDR_BITS-1:0];
    
    //Detect read bank 
    always_comb begin   
        read_bank = 'd0;
        for(int i = 0; i < CACHE_NUM_BANKS; i++) begin
            if(hits[i]) begin
                read_bank = i;
                break;
            end
        end
    end
    
    enum {Idle, WaitAck, Readcyc} main_state;
    
    //Main FSM
    always_ff@(posedge clk) begin
        byte_sel  <= inp_raddr[3:0];
        oup_rdy   <= rdy_r;
        
        if(~resetn || cinv) begin
            for(int i = 0; i < CACHE_NUM_BANKS; i++) begin
                tag_store[i] <= {1'b1, (TAGW_BITS-1)'(0)};
            end
            
            main_state   <= Idle;
            oup_raddr    <= 'd0;
            evicted_bank <= 'd0;
            write_bank   <= 'd0;
            oup_rreq     <= 1'b0;
            write_ptr    <= 'd0;
        end else begin
            case(main_state)
                Idle: begin
                    if((misses == ~CACHE_NUM_BANKS'(0))) begin
                       evicted_bank  <= evicted_bank + 1; 
                       write_ptr     <= 'd0;
                       write_bank    <= evicted_bank;
                       oup_rreq      <= 1'b1;
                       oup_raddr     <= {read_ptr[ADDRW_BITS-1:BURST_BYTE_ADDR_BITS], (BURST_BYTE_ADDR_BITS)'(0)};
                       main_state    <= WaitAck;
                       tag_store[evicted_bank] <= {1'b0, read_ptr[ADDRW_BITS-1:BURST_BYTE_ADDR_BITS]};
                    end else begin
                        main_state <= Idle;
                    end
                end
                WaitAck: begin
                    if(inp_rvalid) begin
                        write_ptr  <= write_ptr + TRANSFER_BYTES;
                        oup_rreq   <= 1'b0;
                        main_state <= Readcyc;
                    end else begin
                        main_state <= WaitAck;
                    end
                end
                Readcyc: begin
                    if(inp_rvalid) begin
                        write_ptr  <= write_ptr + TRANSFER_BYTES;
                        oup_rreq   <= 1'b0;
                    end 
                    
                    
                    if(write_ptr[BURST_BYTE_ADDR_BITS-1:4] == BURST_NUM_TRANSFERS-1) begin
                        main_state <= Idle;
                    end    
                end
            endcase
        end
    end

endmodule