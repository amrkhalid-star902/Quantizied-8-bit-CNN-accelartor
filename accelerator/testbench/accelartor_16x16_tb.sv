`timescale 1ns / 1ps

parameter NPE   = 16;
parameter inH   = 150;
parameter inW   = 150;
parameter inC   = 32;
parameter filH  = 1;
parameter filW  = 1;
parameter filC  = 32;
parameter outH  = 150;
parameter outW  = 150;
parameter outC  = 16;
parameter outWH = outW*outH;
parameter dwen  = 1'd0;

parameter fil_size = filH*filW*(dwen ? 1 : filC);
parameter strH     = 3'h1;
parameter strW     = 3'h1;
parameter padH     = 3'h0;
parameter padW     = 3'h0;
parameter pH       = (outWH+(NPE-1))/NPE;
parameter N_chen   = (outWH+pH-1)/pH; 
parameter chStr    = dwen ? outC : inC;
parameter row_inc  = chStr * inW;
parameter in_offs  = 9'h80;
parameter out_offs = 9'h1fd;

// Tensor offsets
parameter INPUT_TENSOR_OFFSET  = 32'h00000000;
parameter FILTER_TENSOR_OFFSET = 32'd720000;
parameter BIAS_TENSOR_OFFSET   = 32'd720512;
parameter QUANT_TENSOR_OFFSET  = 32'd720576;
parameter OUTPUT_TENSOR_OFFSET = 32'd720640;

parameter ACC_PARAM_OFF = 32'hffff0400;
parameter BASEADR_OUT   = 32'hffff0304;
parameter BASEADR_IN    = 32'hffff0308;
parameter BASEADR_FILT  = 32'hffff030c;
parameter BASEADR_BIAS  = 32'hffff0310;
parameter BASEADR_QUANT = 32'hffff0314;
parameter TFACCCACHE    = 32'hffff0180;
parameter TFACCFLG      = 32'hffff0300;

//parameter OUT_LIM = OUTPUT_TENSOR_OFFSET + outH*outW*outC;
parameter OUT_LEN = outH*outW*outC;
parameter OUT_LIM = outH*outW*outC;

int out_x[NPE];
int out_y[NPE];
int out_addr[NPE];
int in_x[NPE];
int in_y[NPE];
int ch3C;
int inCW;
int data, err;


function relu6 (input logic signed [7:0] x);
    if (x <= 0)
        return 8'd0;
    else if (x >= 8'd6)
        return 8'd6;
    else
        return x;
endfunction

interface acc_if;
    logic clk;
    logic resetn;
    
    // Write Address Channel
    logic        cfg_awvalid;
    logic        cfg_awready;
    logic [31:0] cfg_awaddr;
    logic [2:0]  cfg_awprot;
    
    // Write Data Channel
    logic        cfg_wvalid;
    logic        cfg_wready;
    logic [31:0] cfg_wdata;
    logic [3:0]  cfg_wstrb;
    
    // Write Response Channel
    logic        cfg_bvalid;
    logic        cfg_bready;
    logic [1:0]  cfg_bresp;
    
    // Read Address Channel
    logic        cfg_arvalid;
    logic        cfg_arready;
    logic [31:0] cfg_araddr;
    logic [2:0]  cfg_arprot;
    
    // Read Data Channel
    logic        cfg_rvalid;
    logic        cfg_rready;
    logic [31:0] cfg_rdata;
    logic [1:0]  cfg_rresp;
    
    // Memory Data AXI Interface Signals
    // Write Address Channel
    logic [4:0]   dat_awid;
    logic [31:0]  dat_awaddr;
    logic [7:0]   dat_awlen;
    logic [2:0]   dat_awsize;
    logic [1:0]   dat_awburst;
    logic         dat_awlock;
    logic [3:0]   dat_awcache;
    logic [2:0]   dat_awprot;
    logic [3:0]   dat_awqos;
    logic         dat_awvalid;
    logic         dat_awready;
    
    // Write Data Channel
    logic [127:0] dat_wdata;
    logic [15:0]  dat_wstrb;
    logic         dat_wlast;
    logic         dat_wvalid;
    logic         dat_wready;
    
    // Write Response Channel
    logic [4:0]   dat_bid;
    logic [1:0]   dat_bresp;
    logic         dat_bvalid;
    logic         dat_bready;
    
    // Read Address Channel
    logic [4:0]   dat_arid;
    logic [31:0]  dat_araddr;
    logic [7:0]   dat_arlen;
    logic [2:0]   dat_arsize;
    logic [1:0]   dat_arburst;
    logic         dat_arlock;
    logic [3:0]   dat_arcache;
    logic [2:0]   dat_arprot;
    logic [3:0]   dat_arqos;
    logic         dat_arvalid;
    logic         dat_arready;
    
    // Read Data Channel
    logic [4:0]   dat_rid;
    logic [127:0] dat_rdata;
    logic [1:0]   dat_rresp;
    logic         dat_rlast;
    logic         dat_rvalid;
    logic         dat_rready;
    
    // Interrupt signal
    logic cfg_irq;    
endinterface

program acc_driver(acc_if dut_if);

    task cfg_write(input [31:0] addr, input [31:0] data, input [3:0] strb = 4'hF);
        @(posedge dut_if.clk);
        // Drive write address and data channels
        dut_if.cfg_awaddr  <= addr;
        dut_if.cfg_awvalid <= 1'b1;
        dut_if.cfg_wdata   <= data;
        dut_if.cfg_wvalid  <= 1'b1;
        dut_if.cfg_wstrb   <= strb;
    
        fork
            begin : aw_handshake
                wait(dut_if.cfg_awready); // Address ready
                @(posedge dut_if.clk);
                dut_if.cfg_awvalid <= 1'b0;
            end
            begin : w_handshake
                wait(dut_if.cfg_wready);  // Data ready
                @(posedge dut_if.clk);
                dut_if.cfg_wvalid <= 1'b0;
            end
        join
    
        // Handle write response
        dut_if.cfg_bready <= 1'b1;
        wait(dut_if.cfg_bvalid); // Response valid
        if (dut_if.cfg_bresp !== 2'b00) begin
            $error("CFG Write Error: Response 0x%h", dut_if.cfg_bresp);
        end
        @(posedge dut_if.clk);
        dut_if.cfg_bready <= 1'b0;
    endtask
    
    task cfg_read(input [31:0] addr, output [31:0] data);
        @(posedge dut_if.clk);
        // Drive read address channel
        dut_if.cfg_araddr  <= addr;
        dut_if.cfg_arvalid <= 1'b1;
    
        // Wait for address handshake
        wait(dut_if.cfg_arready);
        @(posedge dut_if.clk);
        dut_if.cfg_arvalid <= 1'b0;
    
        // Handle read response
        dut_if.cfg_rready <= 1'b1;
        wait(dut_if.cfg_rvalid); // Read data valid
        data = dut_if.cfg_rdata;
        if (dut_if.cfg_rresp !== 2'b00) begin
            $error("CFG Read Error: Response 0x%h", dut_if.cfg_rresp);
        end
        @(posedge dut_if.clk);
        dut_if.cfg_rready <= 1'b0;
    endtask
    
    task write_data();
        //$readmemh("ref_out.mem", ref_mem);
        for(int i = 0; i < OUT_LIM; i++) begin
            //$display(axi_mem_slave_0.mem[i+OUTPUT_TENSOR_OFFSET]);
            if(axi_mem_slave_0.mem[i+OUTPUT_TENSOR_OFFSET] != axi_mem_slave_0.ref_mem[i])
                err++;
        end
    endtask
    
    initial begin
        err = 0;
        dut_if.resetn = 1'b1;
        @(posedge dut_if.clk);
        dut_if.resetn = 1'b0;
        @(posedge dut_if.clk);
        dut_if.resetn = 1'b1;
        @(posedge dut_if.clk);
        cfg_write(32'hffff0300,0);   //kick = 0
         @(posedge dut_if.clk);
        cfg_read(32'hffff031c,data);
        assert(data == NPE);
        $display("NPE NUM");
        $display(data);
        @(posedge dut_if.clk);
        cfg_write(ACC_PARAM_OFF, inH);
        cfg_write(ACC_PARAM_OFF+8'd4, inW);
        cfg_write(ACC_PARAM_OFF+8'd8, inC);
        cfg_write(ACC_PARAM_OFF+8'd12, filH);
        cfg_write(ACC_PARAM_OFF+8'd16, filW);
        cfg_write(ACC_PARAM_OFF+8'd20, filC);
        cfg_write(ACC_PARAM_OFF+8'd24, outH);
        cfg_write(ACC_PARAM_OFF+8'd28, outW);
        cfg_write(ACC_PARAM_OFF+8'd32, outC);
        cfg_write(ACC_PARAM_OFF+8'd36, pH);
        cfg_write(ACC_PARAM_OFF+8'd40, {strH[2:0], padH[2:0]});
        cfg_write(ACC_PARAM_OFF+8'd44, {strW[2:0], padW[2:0]});
        cfg_write(ACC_PARAM_OFF+8'd48, dwen);
        cfg_write(ACC_PARAM_OFF+8'd52, in_offs);  
        cfg_write(ACC_PARAM_OFF+8'd56, out_offs);
        cfg_write(ACC_PARAM_OFF+8'd60, outWH);
        cfg_write(ACC_PARAM_OFF+8'd64, fil_size);
        cfg_write(ACC_PARAM_OFF+8'd68, N_chen);
        cfg_write(ACC_PARAM_OFF+8'd72, row_inc);
        for(int i = 0; i < NPE; i++) begin
            automatic int y = (i*pH) / outW;
            automatic int x = (i*pH) % outW;
            cfg_write(ACC_PARAM_OFF+(i+20)*4, ((y<<16)| x));     
        end
        for(int i = 0; i < NPE; i++) begin
            automatic int y = (i*pH) / outW;
            automatic int x = (i*pH) % outW;
            automatic int addr = y * outW + x;
            addr = addr * outC;
            cfg_write(ACC_PARAM_OFF+(20+NPE+i)*4, addr);     
        end
        ch3C = dwen ? outC : inC;
        inCW = ch3C * inW;
        for(int i = 0; i < NPE; i++) begin
            automatic int y = (i*pH) / outW;
            automatic int x = (i*pH) % outW;
            automatic int inx= x * ch3C * strW  - x*padW;
            cfg_write(ACC_PARAM_OFF+(20+(NPE*2)+i)*4, inx);     
        end
        for(int i = 0; i < NPE; i++) begin
            automatic int y = (i*pH) / outW;
            automatic int x = (i*pH) % outW;
            automatic int iny = y * inCW * strH  - y*padH;
            cfg_write(ACC_PARAM_OFF+(20+(NPE*3)+i)*4, iny);     
        end
      cfg_write(BASEADR_OUT,  OUTPUT_TENSOR_OFFSET);
      cfg_write(BASEADR_IN ,  INPUT_TENSOR_OFFSET);
      cfg_write(BASEADR_FILT, FILTER_TENSOR_OFFSET);
      cfg_write(BASEADR_BIAS, BIAS_TENSOR_OFFSET);
      cfg_write(BASEADR_QUANT, QUANT_TENSOR_OFFSET);
      @(posedge dut_if.clk);
      @(posedge dut_if.clk);
      cfg_write(TFACCCACHE, 32'h0f);
      cfg_write(TFACCFLG, 1);	// kick
      cfg_write(TFACCFLG, 0);	// unkick
      dut_if.cfg_wstrb  = 4'b0;
      @(posedge dut_if.clk);
      @(posedge dut_if.clk);
      @(posedge dut_if.clk);
      wait(dut_if.cfg_irq);
      do begin
        cfg_read(TFACCCACHE, data);
      end while(data != 8'h40);
      //Flush request
      cfg_write(TFACCCACHE, 32'hf0);
      cfg_write(TFACCCACHE, 32'h0);
       do begin
        cfg_read(TFACCCACHE, data);
       end while(data != 8'h40);
       write_data();
       $display(err);
       $finish; 
    end
    
endprogram


module accelartor_16x16_tb();

    acc_if     dut_if();
    acc_driver drv(dut_if);
      
    initial begin
        dut_if.clk = 0;
        forever #1.5 dut_if.clk = ~dut_if.clk;
    end

    accelartor_top dut (
        // System parameters
        .clk(dut_if.clk),
        .resetn(dut_if.resetn),
        
        // Configuration AXI Lite interface
        // AXI Lite Write Address Channel
        .cfg_awvalid(dut_if.cfg_awvalid),
        .cfg_awready(dut_if.cfg_awready),
        .cfg_awaddr(dut_if.cfg_awaddr),
        .cfg_awprot(dut_if.cfg_awprot),
        // AXI Lite Write Data Channel
        .cfg_wvalid(dut_if.cfg_wvalid),
        .cfg_wready(dut_if.cfg_wready),
        .cfg_wdata(dut_if.cfg_wdata),
        .cfg_wstrb(dut_if.cfg_wstrb),
        // AXI Lite Write Response Channel
        .cfg_bvalid(dut_if.cfg_bvalid),
        .cfg_bready(dut_if.cfg_bready),
        .cfg_bresp(dut_if.cfg_bresp),
        // AXI Lite Read Address Channel
        .cfg_arvalid(dut_if.cfg_arvalid),
        .cfg_arready(dut_if.cfg_arready),
        .cfg_araddr(dut_if.cfg_araddr),
        .cfg_arprot(dut_if.cfg_arprot),
        // AXI Lite Read Data Channel
        .cfg_rvalid(dut_if.cfg_rvalid),
        .cfg_rready(dut_if.cfg_rready),
        .cfg_rdata(dut_if.cfg_rdata),
        .cfg_rresp(dut_if.cfg_rresp),
        
        // Memory data AXI interface
        .dat_awid(dut_if.dat_awid),
        .dat_awaddr(dut_if.dat_awaddr),
        .dat_awlen(dut_if.dat_awlen),
        .dat_awsize(dut_if.dat_awsize),
        .dat_awburst(dut_if.dat_awburst),
        .dat_awlock(dut_if.dat_awlock),
        .dat_awcache(dut_if.dat_awcache),
        .dat_awprot(dut_if.dat_awprot),
        .dat_awqos(dut_if.dat_awqos),
        .dat_awvalid(dut_if.dat_awvalid),
        .dat_awready(dut_if.dat_awready),
        .dat_wdata(dut_if.dat_wdata),
        .dat_wstrb(dut_if.dat_wstrb),
        .dat_wlast(dut_if.dat_wlast),
        .dat_wvalid(dut_if.dat_wvalid),
        .dat_wready(dut_if.dat_wready),
        .dat_bid(dut_if.dat_bid),
        .dat_bresp(dut_if.dat_bresp),
        .dat_bvalid(dut_if.dat_bvalid),
        .dat_bready(dut_if.dat_bready),
        .dat_arid(dut_if.dat_arid),
        .dat_araddr(dut_if.dat_araddr),
        .dat_arlen(dut_if.dat_arlen),
        .dat_arsize(dut_if.dat_arsize),
        .dat_arburst(dut_if.dat_arburst),
        .dat_arlock(dut_if.dat_arlock),
        .dat_arcache(dut_if.dat_arcache),
        .dat_arprot(dut_if.dat_arprot),
        .dat_arqos(dut_if.dat_arqos),
        .dat_arvalid(dut_if.dat_arvalid),
        .dat_arready(dut_if.dat_arready),
        .dat_rid(dut_if.dat_rid),
        .dat_rdata(dut_if.dat_rdata),
        .dat_rresp(dut_if.dat_rresp),
        .dat_rlast(dut_if.dat_rlast),
        .dat_rvalid(dut_if.dat_rvalid),
        .dat_rready(dut_if.dat_rready),
        
        // Completion interrupt
        .cfg_irq(dut_if.cfg_irq)
    );
    
    // AXI Memory Slave BFM
    axi_slave_bfm #
    (
        .C_S_AXI_ID_WIDTH      (5),
        .C_S_AXI_ADDR_WIDTH    (32),
        .C_S_AXI_DATA_WIDTH    (128), 
        .INIT("test_vectors.mem"),
        .INIT1("ref_out.mem"),
        .LEN(OUT_LEN),
        .INIT_EN(1)        
    )axi_mem_slave_0(
        .ACLK(dut_if.clk),
        .ARESETN(dut_if.resetn),
    
        // AXI Write Address Channel
        .S_AXI_AWID(dut_if.dat_awid),
        .S_AXI_AWADDR(dut_if.dat_awaddr),
        .S_AXI_AWLEN(dut_if.dat_awlen),
        .S_AXI_AWSIZE(dut_if.dat_awsize),
        .S_AXI_AWBURST(dut_if.dat_awburst),
        .S_AXI_AWLOCK(dut_if.dat_awlock),
        .S_AXI_AWCACHE(dut_if.dat_awcache),
        .S_AXI_AWPROT(dut_if.dat_awprot),
        .S_AXI_AWQOS(dut_if.dat_awqos),
        .S_AXI_AWVALID(dut_if.dat_awvalid),
        .S_AXI_AWREADY(dut_if.dat_awready),
        
        // AXI Write Data Channel
        .S_AXI_WDATA(dut_if.dat_wdata),
        .S_AXI_WSTRB(dut_if.dat_wstrb),
        .S_AXI_WLAST(dut_if.dat_wlast),
        .S_AXI_WVALID(dut_if.dat_wvalid),
        .S_AXI_WREADY(dut_if.dat_wready),
        
        // AXI Write Response Channel
        .S_AXI_BID(dut_if.dat_bid),
        .S_AXI_BRESP(dut_if.dat_bresp),
        .S_AXI_BVALID(dut_if.dat_bvalid),
        .S_AXI_BREADY(dut_if.dat_bready),
        
        // AXI Read Address Channel
        .S_AXI_ARID(dut_if.dat_arid),
        .S_AXI_ARADDR(dut_if.dat_araddr),
        .S_AXI_ARLEN(dut_if.dat_arlen),
        .S_AXI_ARSIZE(dut_if.dat_arsize),
        .S_AXI_ARBURST(dut_if.dat_arburst),
        .S_AXI_ARLOCK(dut_if.dat_arlock),
        .S_AXI_ARCACHE(dut_if.dat_arcache),
        .S_AXI_ARPROT(dut_if.dat_arprot),
        .S_AXI_ARQOS(dut_if.dat_arqos),
        .S_AXI_ARVALID(dut_if.dat_arvalid),
        .S_AXI_ARREADY(dut_if.dat_arready),
        
        // AXI Read Data Channel
        .S_AXI_RID(dut_if.dat_rid),
        .S_AXI_RDATA(dut_if.dat_rdata),
        .S_AXI_RRESP(dut_if.dat_rresp),
        .S_AXI_RLAST(dut_if.dat_rlast),
        .S_AXI_RVALID(dut_if.dat_rvalid),
        .S_AXI_RREADY(dut_if.dat_rready)
    );


endmodule
