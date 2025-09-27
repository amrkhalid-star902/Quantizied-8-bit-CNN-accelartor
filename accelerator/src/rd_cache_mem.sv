`timescale 1ns / 1ps

`include "data_types.svh"

module rd_cache_mem(
    //system parameters
    input logic clk,
    input logic resetn,
    
    //Read Data Bus
    input  logic     inp_creq,    //cache clear request
    input  uint32_t  inp_baddr,
    input  uint32_t  inp_raddr,
    input  logic     inp_ren,
    output logic     oup_rdy,
    output uint128_t oup_rdata,
    
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

    localparam MEM_SIZE    = 4; //size of cache memory in KB
    localparam ADDR_BITS   = $clog2(MEM_SIZE*1024);
    
    logic [15 : 0]  wea;          // 16 bytes for 128-bit width
    logic [127 : 0] dina;         // 128-bit input data
    logic [127 : 0] doutb;        // 128-bit output data
    
    logic [ADDR_BITS-4-1 : 0] addra;    // -4 to account for 16 bytes wide porta
    logic [ADDR_BITS-4-1 : 0] addrb;    // -4 to account for 16 bytes wide portb
    
    // Data connections - direct 128-bit interface
    assign dina      = inp_rdata;
    assign oup_rdata = doutb;
    
    blk_mem_4kb buffer4k (
      .clka(clk),     // input wire clka
      .wea(wea),      // input wire [15 : 0] wea
      .addra(addra),  // input wire [7 : 0] addra 
      .dina(dina),    // input wire [127 : 0] dina
      .clkb(clk),     // input wire clkb
      .addrb(addrb),  // input wire [7 : 0] addrb 
      .doutb(doutb)   // output wire [127 : 0] doutb
    );

    assign oup_awaddr  = 32'd0;
    assign oup_awlen   = 8'h00;
    assign oup_awvalid = 1'b0;
    assign oup_wrdata  = 128'd0;
    assign oup_wvalid  = 1'b0;
    assign oup_wlast   = 1'b0;
    
    logic [31 : 0] read_ptr, write_ptr;
    logic is_cached, rdy_r;
    
    assign is_cached  = write_ptr < (read_ptr + MEM_SIZE*1024);
    assign rdy_r      = inp_ren ? (write_ptr > read_ptr) && is_cached: 1'b1;
    assign read_ptr   = inp_raddr;
    assign addra      = write_ptr[ADDR_BITS-1:4];    // Divide by 16 for 128-bit addressing
    assign addrb      = read_ptr[ADDR_BITS-1:4];     // Divide by 16 for 128-bit addressing
    assign oup_araddr = inp_baddr + {write_ptr[31:9], 9'd0};
    assign oup_arlen  = 8'd32 - 8'd1;
    
    logic arreq;
    assign arreq = inp_ren && (write_ptr < (read_ptr + 264));
    
    // Write enable logic - write directly with 128-bit data
    assign wea = {16{inp_rvalid}};
    
    //AXI Sequencer FSM
    enum {Idle, Ack, Readcyc, Readcmd} read_state;
    
    always_ff@(posedge clk) begin
        oup_rdy <= rdy_r;
        
        if(~resetn) begin
            read_state   <= Idle;
            write_ptr    <= 'd0;
            oup_arvalid  <= 1'b0;
            oup_rready   <= 1'b0;
        end  else begin
            case(read_state)
                Idle: begin
                    oup_arvalid <= 1'b0; 
                    oup_rready  <= 1'b0;
                    if(inp_creq) begin
                        write_ptr <= 'd0;
                    end else if(!is_cached) begin
                        write_ptr <= {read_ptr[31:9], 9'd0};
                    end
                    if(arreq) read_state  <= Ack;
                end
                Ack: begin
                   oup_arvalid <= 1'b1;
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
                    if(inp_rvalid) write_ptr <= write_ptr + 'd16;  // Increment by 16 bytes for 128-bit
                    if(inp_rvalid && write_ptr[8:4] == 31) begin   // 32 x 128-bit words = 512 bytes
                        read_state <= Idle;    
                    end
                end
                default: read_state <= Idle;
            endcase
        end  
    end

endmodule