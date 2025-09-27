`timescale 1ns / 1ps

`include "data_types.svh"

module accelartor_top(
    //System parameters
    input logic clk,
    input logic resetn,
    
    //Configuration axi lite interface
    // AXI Lite Write Address Channel
    input  logic        cfg_awvalid,
    output logic        cfg_awready,
    input  logic [31:0] cfg_awaddr,
    input  logic [2:0]  cfg_awprot,
    // AXI Lite Write Data Channel
    input  logic        cfg_wvalid,
    output logic        cfg_wready,
    input  logic [31:0] cfg_wdata,
    input  logic [3:0]  cfg_wstrb,
    // AXI Lite Write Response Channel
    output logic        cfg_bvalid,
    input  logic        cfg_bready,
    output logic [1:0]  cfg_bresp,
    // AXI Lite Read Address Channel
    input  logic        cfg_arvalid,
    output logic        cfg_arready,
    input  logic [31:0] cfg_araddr,
    input  logic [2:0]  cfg_arprot,
    // AXI Lite Read Data Channel
    output logic        cfg_rvalid,
    input  logic        cfg_rready,
    output logic [31:0] cfg_rdata,
    output logic [1:0]  cfg_rresp,
    
    //Memory data axi lite interface
	output logic [4 : 0]   dat_awid,
    output logic [31 : 0]  dat_awaddr,
    output logic [7 : 0]   dat_awlen,
    output logic [2 : 0]   dat_awsize,
    output logic [1 : 0]   dat_awburst,
    output logic           dat_awlock,
    output logic [3 : 0]   dat_awcache,
    output logic [2 : 0]   dat_awprot,
    output logic [3 : 0]   dat_awqos,
    output logic           dat_awvalid,
    input  logic           dat_awready,
    output logic [127 : 0] dat_wdata,
    output logic [15 : 0]  dat_wstrb,
    output logic           dat_wlast,
    output logic           dat_wvalid,
    input  logic           dat_wready,
    input  logic [4 : 0]   dat_bid,
    input  logic [1 : 0]   dat_bresp,
    input  logic           dat_bvalid,
    output logic           dat_bready,
    output logic [4 : 0]   dat_arid,
    output logic [31 : 0]  dat_araddr,
    output logic [7 : 0]   dat_arlen,
    output logic [2 : 0]   dat_arsize,
    output logic [1 : 0]   dat_arburst,
    output logic           dat_arlock,
    output logic [3 : 0]   dat_arcache,
    output logic [2 : 0]   dat_arprot,
    output logic [3 : 0]   dat_arqos,
    output logic           dat_arvalid,
    input  logic           dat_arready,
    input  logic [4 : 0]   dat_rid,
    input  logic [127 : 0] dat_rdata,
    input  logic [1 : 0]   dat_rresp,
    input  logic           dat_rlast,
    input  logic           dat_rvalid,
    output logic           dat_rready,
    
    //compl interrupt
    output logic    cfg_irq    
);

	localparam NPE  = 16;
	
    //configuration bus
    uint32_t c_addr;
    uint4_t  c_we;
    logic    c_ren;
    uint32_t c_wdata;
    logic    c_rdy;
    uint32_t c_rdata;
    
    axi_lite_2ram axilite_2ram(
        // Clock and Reset
        .aclk(clk),
        .aresetn(resetn),
    
        // AXI Lite Write Address Channel
        .awvalid(cfg_awvalid),
        .awready(cfg_awready),
        .awaddr(cfg_awaddr),
        .awprot(cfg_awprot),
    
        // AXI Lite Write Data Channel
        .wvalid(cfg_wvalid),
        .wready(cfg_wready),
        .wdata(cfg_wdata),
        .wstrb(cfg_wstrb),
    
        // AXI Lite Write Response Channel
        .bvalid(cfg_bvalid),
        .bready(cfg_bready),
        .bresp(cfg_bresp),
    
        // AXI Lite Read Address Channel
        .arvalid(cfg_arvalid),
        .arready(cfg_arready),
        .araddr(cfg_araddr),
        .arprot(cfg_arprot),
    
        // AXI Lite Read Data Channel
        .rvalid(cfg_rvalid),
        .rready(cfg_rready),
        .rdata(cfg_rdata),
        .rresp(cfg_rresp),
    
        // RAM Interface
        .cfg_addr(c_addr),
        .cfg_we(c_we),
        .cfg_ren(c_ren),
        .cfg_wdata(c_wdata),
        .cfg_rdy(c_rdy),
        .cfg_rdata(c_rdata)
    );
	
    logic           S00_AXI_AWID,    S01_AXI_AWID,     S02_AXI_AWID,    S03_AXI_AWID,    S04_AXI_AWID;
    logic [31 : 0]  S00_AXI_AWADDR, S01_AXI_AWADDR,   S02_AXI_AWADDR,  S03_AXI_AWADDR,  S04_AXI_AWADDR;
    logic [7 : 0]   S00_AXI_AWLEN,   S01_AXI_AWLEN,    S02_AXI_AWLEN,   S03_AXI_AWLEN,   S04_AXI_AWLEN;
    logic [2 : 0]   S_AXI_AWSIZE;
    logic [1 : 0]   S_AXI_AWBURST;
    logic           S_AXI_AWLOCK;
    logic [3 : 0]   S_AXI_AWCACHE;
    logic [2 : 0]   S_AXI_AWPROT;
    logic [3 : 0]   S_AXI_AWQOS;
	
    logic            S00_AXI_AWVALID, S01_AXI_AWVALID,  S02_AXI_AWVALID,S03_AXI_AWVALID,  S04_AXI_AWVALID;
    logic            S00_AXI_AWREADY, S01_AXI_AWREADY,  S02_AXI_AWREADY,S03_AXI_AWREADY,  S04_AXI_AWREADY;
    logic [127 : 0]  S00_AXI_WDATA;
    logic [127 : 0]  S02_AXI_WDATA, S03_AXI_WDATA,    S04_AXI_WDATA;
    logic [127 : 0]  S01_AXI_WDATA;
    logic [15 : 0]   S00_AXI_WSTRB;
    logic [15 : 0]   S02_AXI_WSTRB, S03_AXI_WSTRB, S04_AXI_WSTRB;
    logic [15 : 0]   S01_AXI_WSTRB;
	
    logic           S00_AXI_WLAST,   S01_AXI_WLAST,    S02_AXI_WLAST,  S03_AXI_WLAST,    S04_AXI_WLAST;
    logic           S00_AXI_WVALID,  S01_AXI_WVALID,   S02_AXI_WVALID, S03_AXI_WVALID,   S04_AXI_WVALID;
    logic           S00_AXI_WREADY,  S01_AXI_WREADY,   S02_AXI_WREADY, S03_AXI_WREADY,   S04_AXI_WREADY;
	
    logic           S00_AXI_BID,     S01_AXI_BID,      S02_AXI_BID,    S03_AXI_BID,      S04_AXI_BID;
    logic [1 : 0]   S00_AXI_BRESP,   S01_AXI_BRESP,    S02_AXI_BRESP,  S03_AXI_BRESP,    S04_AXI_BRESP;
    logic           S00_AXI_BVALID,  S01_AXI_BVALID,   S02_AXI_BVALID, S03_AXI_BVALID,   S04_AXI_BVALID;
    logic           S00_AXI_BREADY,  S01_AXI_BREADY,   S02_AXI_BREADY, S03_AXI_BREADY,   S04_AXI_BREADY;
    logic           S00_AXI_ARID,    S01_AXI_ARID,     S02_AXI_ARID,   S03_AXI_ARID,     S04_AXI_ARID;
    logic [31 : 0]  S00_AXI_ARADDR,  S01_AXI_ARADDR,   S02_AXI_ARADDR, S03_AXI_ARADDR,   S04_AXI_ARADDR;
    logic [7 : 0]   S00_AXI_ARLEN,   S01_AXI_ARLEN,    S02_AXI_ARLEN,  S03_AXI_ARLEN,    S04_AXI_ARLEN;
    logic [2 : 0]   S_AXI_ARSIZE;
    logic [1 : 0]   S_AXI_ARBURST;
    logic           S_AXI_ARLOCK;
    logic [3 : 0]   S_AXI_ARCACHE;
    logic [2 : 0]   S_AXI_ARPROT;
    logic [3 : 0]   S_AXI_ARQOS;
    logic           S00_AXI_ARVALID, S01_AXI_ARVALID,  S02_AXI_ARVALID,S03_AXI_ARVALID,  S04_AXI_ARVALID;
    logic           S00_AXI_ARREADY, S01_AXI_ARREADY,  S02_AXI_ARREADY,S03_AXI_ARREADY,  S04_AXI_ARREADY;
    logic           S00_AXI_RID,     S01_AXI_RID,      S02_AXI_RID,    S03_AXI_RID,      S04_AXI_RID;
    logic [127 : 0] S01_AXI_RDATA;
    logic [127 : 0] S00_AXI_RDATA,   S02_AXI_RDATA,    S03_AXI_RDATA,  S04_AXI_RDATA;
    logic [1 : 0]   S00_AXI_RRESP,   S01_AXI_RRESP,    S02_AXI_RRESP,  S03_AXI_RRESP,    S04_AXI_RRESP;
    logic           S00_AXI_RLAST,   S01_AXI_RLAST,    S02_AXI_RLAST,  S03_AXI_RLAST,    S04_AXI_RLAST;
    logic           S00_AXI_RVALID,  S01_AXI_RVALID,   S02_AXI_RVALID, S03_AXI_RVALID,   S04_AXI_RVALID;
    logic           S00_AXI_RREADY,  S01_AXI_RREADY,   S02_AXI_RREADY, S03_AXI_RREADY,   S04_AXI_RREADY;
	
    logic [2 : 0]   S00_AXI_AWSIZE;
    logic [1 : 0]   S00_AXI_AWBURST;
    logic           S00_AXI_AWLOCK;
    logic [3 : 0]   S00_AXI_AWCACHE;
    logic [2 : 0]   S00_AXI_AWPROT;
    logic [3 : 0]   S00_AXI_AWQOS;
    logic [2 : 0]   S00_AXI_ARSIZE;
    logic [1 : 0]   S00_AXI_ARBURST;
    logic           S00_AXI_ARLOCK;
    logic [3 : 0]   S00_AXI_ARCACHE;
    logic [2 : 0]   S00_AXI_ARPROT;
    logic [3 : 0]   S00_AXI_ARQOS;
	
    logic [2 : 0]   S01_AXI_AWSIZE,   S02_AXI_AWSIZE,   S03_AXI_AWSIZE,   S04_AXI_AWSIZE;
    logic [1 : 0]   S01_AXI_AWBURST,  S02_AXI_AWBURST,  S03_AXI_AWBURST,  S04_AXI_AWBURST;
    logic           S01_AXI_AWLOCK,   S02_AXI_AWLOCK,   S03_AXI_AWLOCK,   S04_AXI_AWLOCK;
    logic [3 : 0]   S01_AXI_AWCACHE,  S02_AXI_AWCACHE,  S03_AXI_AWCACHE,  S04_AXI_AWCACHE;
    logic [2 : 0]   S01_AXI_AWPROT,   S02_AXI_AWPROT,   S03_AXI_AWPROT,   S04_AXI_AWPROT;
    logic [3 : 0]   S01_AXI_AWQOS,    S02_AXI_AWQOS,    S03_AXI_AWQOS,    S04_AXI_AWQOS;
    logic [2 : 0]   S01_AXI_ARSIZE,   S02_AXI_ARSIZE,   S03_AXI_ARSIZE,   S04_AXI_ARSIZE;
    logic [1 : 0]   S01_AXI_ARBURST,  S02_AXI_ARBURST,  S03_AXI_ARBURST,  S04_AXI_ARBURST;
    logic           S01_AXI_ARLOCK,   S02_AXI_ARLOCK,   S03_AXI_ARLOCK,   S04_AXI_ARLOCK;
    logic [3 : 0]   S01_AXI_ARCACHE,  S02_AXI_ARCACHE,  S03_AXI_ARCACHE,  S04_AXI_ARCACHE;
    logic [2 : 0]   S01_AXI_ARPROT,   S02_AXI_ARPROT,   S03_AXI_ARPROT,   S04_AXI_ARPROT;
    logic [3 : 0]   S01_AXI_ARQOS,    S02_AXI_ARQOS,    S03_AXI_ARQOS,    S04_AXI_ARQOS;
	
    assign S00_AXI_AWSIZE  = 3'b100;	// The maximum number of bytes to transfer in each data transfer, or beat, in a burst.  2^4 = 16 byte
    assign S00_AXI_AWBURST = 2'b01;	
    assign S00_AXI_AWLOCK  = 1'b0;	 
    assign S00_AXI_AWCACHE = 4'b0011;  
    assign S00_AXI_AWPROT  = 3'b000;	
    assign S00_AXI_AWQOS   = 4'b0;	
    
    assign S00_AXI_ARSIZE  = 3'b100;	// The maximum number of bytes to transfer in each data transfer, or beat, in a burst.  2^4 = 16 byte
    assign S00_AXI_ARBURST = 2'b01;	
    assign S00_AXI_ARLOCK  = 1'b0;	
    assign S00_AXI_ARCACHE = 4'b0011; 
    assign S00_AXI_ARPROT  = 3'b000;	
    assign S00_AXI_ARQOS   = 4'b0;		
    
    assign S01_AXI_AWSIZE  = 3'b011;	// The maximum number of bytes to transfer in each data transfer, or beat, in a burst.  2^3 = 8 byte
    assign S01_AXI_AWBURST = 2'b01;	
    assign S01_AXI_AWLOCK  = 1'b0;	 
    assign S01_AXI_AWCACHE = 4'b0011;  
    assign S01_AXI_AWPROT  = 3'b000;	
    assign S01_AXI_AWQOS   = 4'b0;	
    
    assign S01_AXI_ARSIZE  = 3'b100;	// The maximum number of bytes to transfer in each data transfer, or beat, in a burst.  2^4 = 16 byte
    assign S01_AXI_ARBURST = 2'b01;	
    assign S01_AXI_ARLOCK  = 1'b0;	
    assign S01_AXI_ARCACHE = 4'b0011; 
    assign S01_AXI_ARPROT  = 3'b000;	
    assign S01_AXI_ARQOS   = 4'b0;

    assign S_AXI_AWSIZE  = 3'b100;	   // The maximum number of bytes to transfer in each data transfer, or beat, in a burst.  2^4 = 16 byte
    assign S_AXI_AWBURST = 2'b01;	
    assign S_AXI_AWLOCK  = 1'b0;	 
    assign S_AXI_AWCACHE = 4'b0011;	
    assign S_AXI_AWPROT  = 3'b000;	
    assign S_AXI_AWQOS   = 4'b0;	
    
    assign S_AXI_ARSIZE  = 3'b100;	   // The maximum number of bytes to transfer in each data transfer, or beat, in a burst.  2^4 = 16 byte
    assign S_AXI_ARBURST = 2'b01;	
    assign S_AXI_ARLOCK  = 1'b0;	
    assign S_AXI_ARCACHE = 4'b0011;	
    assign S_AXI_ARPROT  = 3'b000;	
    assign S_AXI_ARQOS   = 4'b0;	
    
    assign S02_AXI_AWSIZE  = S_AXI_AWSIZE;	   
    assign S02_AXI_AWBURST = S_AXI_AWBURST;	
    assign S02_AXI_AWLOCK  = S_AXI_AWLOCK;	 
    assign S02_AXI_AWCACHE = S_AXI_AWCACHE;	
    assign S02_AXI_AWPROT  = S_AXI_AWPROT;	
    assign S02_AXI_AWQOS   = S_AXI_AWQOS;	
    
    assign S02_AXI_ARSIZE  = S_AXI_ARSIZE;	   
    assign S02_AXI_ARBURST = S_AXI_ARBURST;	
    assign S02_AXI_ARLOCK  = S_AXI_ARLOCK;	
    assign S02_AXI_ARCACHE = S_AXI_ARCACHE;	
    assign S02_AXI_ARPROT  = S_AXI_ARPROT;	
    assign S02_AXI_ARQOS   = S_AXI_ARQOS;
    
    assign S03_AXI_AWSIZE  = S_AXI_AWSIZE;	   
    assign S03_AXI_AWBURST = S_AXI_AWBURST;	
    assign S03_AXI_AWLOCK  = S_AXI_AWLOCK;	 
    assign S03_AXI_AWCACHE = S_AXI_AWCACHE;	
    assign S03_AXI_AWPROT  = S_AXI_AWPROT;	
    assign S03_AXI_AWQOS   = S_AXI_AWQOS;	
    
    assign S03_AXI_ARSIZE  = S_AXI_ARSIZE;	   
    assign S03_AXI_ARBURST = S_AXI_ARBURST;	
    assign S03_AXI_ARLOCK  = S_AXI_ARLOCK;	
    assign S03_AXI_ARCACHE = S_AXI_ARCACHE;	
    assign S03_AXI_ARPROT  = S_AXI_ARPROT;	
    assign S03_AXI_ARQOS   = S_AXI_ARQOS;
    
    assign S04_AXI_AWSIZE  = S_AXI_AWSIZE;	   
    assign S04_AXI_AWBURST = S_AXI_AWBURST;	
    assign S04_AXI_AWLOCK  = S_AXI_AWLOCK;	 
    assign S04_AXI_AWCACHE = S_AXI_AWCACHE;	
    assign S04_AXI_AWPROT  = S_AXI_AWPROT;	
    assign S04_AXI_AWQOS   = S_AXI_AWQOS;	
    
    assign S04_AXI_ARSIZE  = S_AXI_ARSIZE;	   
    assign S04_AXI_ARBURST = S_AXI_ARBURST;	
    assign S04_AXI_ARLOCK  = S_AXI_ARLOCK;	
    assign S04_AXI_ARCACHE = S_AXI_ARCACHE;	
    assign S04_AXI_ARPROT  = S_AXI_ARPROT;	
    assign S04_AXI_ARQOS   = S_AXI_ARQOS;
    
    assign S00_AXI_AWID = {1'b1};
    assign S01_AXI_AWID = {1'b1};
    assign S02_AXI_AWID = {1'b1};
    assign S03_AXI_AWID = {1'b1};
    assign S04_AXI_AWID = {1'b1};
    
    assign S00_AXI_ARID = {1'b1};
    assign S01_AXI_ARID = {1'b1};
    assign S02_AXI_ARID = {1'b1};
    assign S03_AXI_ARID = {1'b1};
    assign S04_AXI_ARID = {1'b1};
    
    assign S01_AXI_WSTRB = 16'h00;	// read only
    assign S02_AXI_WSTRB = 16'h00;
    assign S03_AXI_WSTRB = 16'h00;
    assign S04_AXI_WSTRB = 16'h00;
    
    assign S00_AXI_BREADY  = 1'b1;
    assign S01_AXI_BREADY  = 1'b1;
    assign S02_AXI_BREADY  = 1'b1;
    assign S03_AXI_BREADY  = 1'b1;
    assign S04_AXI_BREADY  = 1'b1;
	
    axi_interconnect axi_ic (
      .INTERCONNECT_ACLK(clk),                      // input wire INTERCONNECT_ACLK
      .INTERCONNECT_ARESETN(resetn),                // input wire INTERCONNECT_ARESETN
      .S00_AXI_ARESET_OUT_N(),                      // output wire S00_AXI_ARESET_OUT_N
      .S00_AXI_ACLK(clk),                           // input wire S00_AXI_ACLK
      .S00_AXI_AWID(S00_AXI_AWID),                  // input wire [0 : 0] S00_AXI_AWID
      .S00_AXI_AWADDR(S00_AXI_AWADDR),              // input wire [31 : 0] S00_AXI_AWADDR
      .S00_AXI_AWLEN(S00_AXI_AWLEN),                // input wire [7 : 0] S00_AXI_AWLEN
      .S00_AXI_AWSIZE(S00_AXI_AWSIZE),              // input wire [2 : 0] S00_AXI_AWSIZE
      .S00_AXI_AWBURST(S00_AXI_AWBURST),            // input wire [1 : 0] S00_AXI_AWBURST
      .S00_AXI_AWLOCK(S00_AXI_AWLOCK),              // input wire S00_AXI_AWLOCK
      .S00_AXI_AWCACHE(S00_AXI_AWCACHE),            // input wire [3 : 0] S00_AXI_AWCACHE
      .S00_AXI_AWPROT(S00_AXI_AWPROT),              // input wire [2 : 0] S00_AXI_AWPROT
      .S00_AXI_AWQOS(S00_AXI_AWQOS),                // input wire [3 : 0] S00_AXI_AWQOS
      .S00_AXI_AWVALID(S00_AXI_AWVALID),            // input wire S00_AXI_AWVALID
      .S00_AXI_AWREADY(S00_AXI_AWREADY),            // output wire S00_AXI_AWREADY
      .S00_AXI_WDATA(S00_AXI_WDATA),                // input wire [127 : 0] S00_AXI_WDATA
      .S00_AXI_WSTRB(S00_AXI_WSTRB),                // input wire [15 : 0] S00_AXI_WSTRB
      .S00_AXI_WLAST(S00_AXI_WLAST),                // input wire S00_AXI_WLAST
      .S00_AXI_WVALID(S00_AXI_WVALID),              // input wire S00_AXI_WVALID
      .S00_AXI_WREADY(S00_AXI_WREADY),              // output wire S00_AXI_WREADY
      .S00_AXI_BID(S00_AXI_BID),                    // output wire [0 : 0] S00_AXI_BID
      .S00_AXI_BRESP(S00_AXI_BRESP),                // output wire [1 : 0] S00_AXI_BRESP
      .S00_AXI_BVALID(S00_AXI_BVALID),              // output wire S00_AXI_BVALID
      .S00_AXI_BREADY(S00_AXI_BREADY),              // input wire S00_AXI_BREADY
      .S00_AXI_ARID(S00_AXI_ARID),                  // input wire [0 : 0] S00_AXI_ARID
      .S00_AXI_ARADDR(S00_AXI_ARADDR),              // input wire [31 : 0] S00_AXI_ARADDR
      .S00_AXI_ARLEN(S00_AXI_ARLEN),                // input wire [7 : 0] S00_AXI_ARLEN
      .S00_AXI_ARSIZE(S00_AXI_ARSIZE),              // input wire [2 : 0] S00_AXI_ARSIZE
      .S00_AXI_ARBURST(S00_AXI_ARBURST),            // input wire [1 : 0] S00_AXI_ARBURST
      .S00_AXI_ARLOCK(S00_AXI_ARLOCK),              // input wire S00_AXI_ARLOCK
      .S00_AXI_ARCACHE(S00_AXI_ARCACHE),            // input wire [3 : 0] S00_AXI_ARCACHE
      .S00_AXI_ARPROT(S00_AXI_ARPROT),              // input wire [2 : 0] S00_AXI_ARPROT
      .S00_AXI_ARQOS(S00_AXI_ARQOS),                // input wire [3 : 0] S00_AXI_ARQOS
      .S00_AXI_ARVALID(S00_AXI_ARVALID),            // input wire S00_AXI_ARVALID
      .S00_AXI_ARREADY(S00_AXI_ARREADY),            // output wire S00_AXI_ARREADY
      .S00_AXI_RID(S00_AXI_RID),                    // output wire [0 : 0] S00_AXI_RID
      .S00_AXI_RDATA(S00_AXI_RDATA),                // output wire [127 : 0] S00_AXI_RDATA
      .S00_AXI_RRESP(S00_AXI_RRESP),                // output wire [1 : 0] S00_AXI_RRESP
      .S00_AXI_RLAST(S00_AXI_RLAST),                // output wire S00_AXI_RLAST
      .S00_AXI_RVALID(S00_AXI_RVALID),              // output wire S00_AXI_RVALID
      .S00_AXI_RREADY(S00_AXI_RREADY),              // input wire S00_AXI_RREADY
      .S01_AXI_ARESET_OUT_N(),                      // output wire S01_AXI_ARESET_OUT_N
      .S01_AXI_ACLK(clk),                           // input wire S01_AXI_ACLK
      .S01_AXI_AWID(S01_AXI_AWID),                  // input wire [0 : 0] S01_AXI_AWID
      .S01_AXI_AWADDR(S01_AXI_AWADDR),              // input wire [31 : 0] S01_AXI_AWADDR
      .S01_AXI_AWLEN(S01_AXI_AWLEN),                // input wire [7 : 0] S01_AXI_AWLEN
      .S01_AXI_AWSIZE(S01_AXI_AWSIZE),              // input wire [2 : 0] S01_AXI_AWSIZE
      .S01_AXI_AWBURST(S01_AXI_AWBURST),            // input wire [1 : 0] S01_AXI_AWBURST
      .S01_AXI_AWLOCK(S01_AXI_AWLOCK),              // input wire S01_AXI_AWLOCK
      .S01_AXI_AWCACHE(S01_AXI_AWCACHE),            // input wire [3 : 0] S01_AXI_AWCACHE
      .S01_AXI_AWPROT(S01_AXI_AWPROT),              // input wire [2 : 0] S01_AXI_AWPROT
      .S01_AXI_AWQOS(S01_AXI_AWQOS),                // input wire [3 : 0] S01_AXI_AWQOS
      .S01_AXI_AWVALID(S01_AXI_AWVALID),            // input wire S01_AXI_AWVALID
      .S01_AXI_AWREADY(S01_AXI_AWREADY),            // output wire S01_AXI_AWREADY
      .S01_AXI_WDATA(S01_AXI_WDATA),                // input wire [127 : 0] S01_AXI_WDATA
      .S01_AXI_WSTRB(S01_AXI_WSTRB),                // input wire [15 : 0] S01_AXI_WSTRB
      .S01_AXI_WLAST(S01_AXI_WLAST),                // input wire S01_AXI_WLAST
      .S01_AXI_WVALID(S01_AXI_WVALID),              // input wire S01_AXI_WVALID
      .S01_AXI_WREADY(S01_AXI_WREADY),              // output wire S01_AXI_WREADY
      .S01_AXI_BID(S01_AXI_BID),                    // output wire [0 : 0] S01_AXI_BID
      .S01_AXI_BRESP(S01_AXI_BRESP),                // output wire [1 : 0] S01_AXI_BRESP
      .S01_AXI_BVALID(S01_AXI_BVALID),              // output wire S01_AXI_BVALID
      .S01_AXI_BREADY(S01_AXI_BREADY),              // input wire S01_AXI_BREADY
      .S01_AXI_ARID(S01_AXI_ARID),                  // input wire [0 : 0] S01_AXI_ARID
      .S01_AXI_ARADDR(S01_AXI_ARADDR),              // input wire [31 : 0] S01_AXI_ARADDR
      .S01_AXI_ARLEN(S01_AXI_ARLEN),                // input wire [7 : 0] S01_AXI_ARLEN
      .S01_AXI_ARSIZE(S01_AXI_ARSIZE),              // input wire [2 : 0] S01_AXI_ARSIZE
      .S01_AXI_ARBURST(S01_AXI_ARBURST),            // input wire [1 : 0] S01_AXI_ARBURST
      .S01_AXI_ARLOCK(S01_AXI_ARLOCK),              // input wire S01_AXI_ARLOCK
      .S01_AXI_ARCACHE(S01_AXI_ARCACHE),            // input wire [3 : 0] S01_AXI_ARCACHE
      .S01_AXI_ARPROT(S01_AXI_ARPROT),              // input wire [2 : 0] S01_AXI_ARPROT
      .S01_AXI_ARQOS(S01_AXI_ARQOS),                // input wire [3 : 0] S01_AXI_ARQOS
      .S01_AXI_ARVALID(S01_AXI_ARVALID),            // input wire S01_AXI_ARVALID
      .S01_AXI_ARREADY(S01_AXI_ARREADY),            // output wire S01_AXI_ARREADY
      .S01_AXI_RID(S01_AXI_RID),                    // output wire [0 : 0] S01_AXI_RID
      .S01_AXI_RDATA(S01_AXI_RDATA),                // output wire [127 : 0] S01_AXI_RDATA
      .S01_AXI_RRESP(S01_AXI_RRESP),                // output wire [1 : 0] S01_AXI_RRESP
      .S01_AXI_RLAST(S01_AXI_RLAST),                // output wire S01_AXI_RLAST
      .S01_AXI_RVALID(S01_AXI_RVALID),              // output wire S01_AXI_RVALID
      .S01_AXI_RREADY(S01_AXI_RREADY),              // input wire S01_AXI_RREADY
      .S02_AXI_ARESET_OUT_N(),                      // output wire S02_AXI_ARESET_OUT_N
      .S02_AXI_ACLK(clk),                           // input wire S02_AXI_ACLK
      .S02_AXI_AWID(S02_AXI_AWID),                  // input wire [0 : 0] S02_AXI_AWID
      .S02_AXI_AWADDR(S02_AXI_AWADDR),              // input wire [31 : 0] S02_AXI_AWADDR
      .S02_AXI_AWLEN(S02_AXI_AWLEN),                // input wire [7 : 0] S02_AXI_AWLEN
      .S02_AXI_AWSIZE(S02_AXI_AWSIZE),              // input wire [2 : 0] S02_AXI_AWSIZE
      .S02_AXI_AWBURST(S02_AXI_AWBURST),            // input wire [1 : 0] S02_AXI_AWBURST
      .S02_AXI_AWLOCK(S02_AXI_AWLOCK),              // input wire S02_AXI_AWLOCK
      .S02_AXI_AWCACHE(S02_AXI_AWCACHE),            // input wire [3 : 0] S02_AXI_AWCACHE
      .S02_AXI_AWPROT(S02_AXI_AWPROT),              // input wire [2 : 0] S02_AXI_AWPROT
      .S02_AXI_AWQOS(S02_AXI_AWQOS),                // input wire [3 : 0] S02_AXI_AWQOS
      .S02_AXI_AWVALID(S02_AXI_AWVALID),            // input wire S02_AXI_AWVALID
      .S02_AXI_AWREADY(S02_AXI_AWREADY),            // output wire S02_AXI_AWREADY
      .S02_AXI_WDATA(S02_AXI_WDATA),                // input wire [127 : 0] S02_AXI_WDATA
      .S02_AXI_WSTRB(S02_AXI_WSTRB),                // input wire [15 : 0] S02_AXI_WSTRB
      .S02_AXI_WLAST(S02_AXI_WLAST),                // input wire S02_AXI_WLAST
      .S02_AXI_WVALID(S02_AXI_WVALID),              // input wire S02_AXI_WVALID
      .S02_AXI_WREADY(S02_AXI_WREADY),              // output wire S02_AXI_WREADY
      .S02_AXI_BID(S02_AXI_BID),                    // output wire [0 : 0] S02_AXI_BID
      .S02_AXI_BRESP(S02_AXI_BRESP),                // output wire [1 : 0] S02_AXI_BRESP
      .S02_AXI_BVALID(S02_AXI_BVALID),              // output wire S02_AXI_BVALID
      .S02_AXI_BREADY(S02_AXI_BREADY),              // input wire S02_AXI_BREADY
      .S02_AXI_ARID(S02_AXI_ARID),                  // input wire [0 : 0] S02_AXI_ARID
      .S02_AXI_ARADDR(S02_AXI_ARADDR),              // input wire [31 : 0] S02_AXI_ARADDR
      .S02_AXI_ARLEN(S02_AXI_ARLEN),                // input wire [7 : 0] S02_AXI_ARLEN
      .S02_AXI_ARSIZE(S02_AXI_ARSIZE),              // input wire [2 : 0] S02_AXI_ARSIZE
      .S02_AXI_ARBURST(S02_AXI_ARBURST),            // input wire [1 : 0] S02_AXI_ARBURST
      .S02_AXI_ARLOCK(S02_AXI_ARLOCK),              // input wire S02_AXI_ARLOCK
      .S02_AXI_ARCACHE(S02_AXI_ARCACHE),            // input wire [3 : 0] S02_AXI_ARCACHE
      .S02_AXI_ARPROT(S02_AXI_ARPROT),              // input wire [2 : 0] S02_AXI_ARPROT
      .S02_AXI_ARQOS(S02_AXI_ARQOS),                // input wire [3 : 0] S02_AXI_ARQOS
      .S02_AXI_ARVALID(S02_AXI_ARVALID),            // input wire S02_AXI_ARVALID
      .S02_AXI_ARREADY(S02_AXI_ARREADY),            // output wire S02_AXI_ARREADY
      .S02_AXI_RID(S02_AXI_RID),                    // output wire [0 : 0] S02_AXI_RID
      .S02_AXI_RDATA(S02_AXI_RDATA),                // output wire [127 : 0] S02_AXI_RDATA
      .S02_AXI_RRESP(S02_AXI_RRESP),                // output wire [1 : 0] S02_AXI_RRESP
      .S02_AXI_RLAST(S02_AXI_RLAST),                // output wire S02_AXI_RLAST
      .S02_AXI_RVALID(S02_AXI_RVALID),              // output wire S02_AXI_RVALID
      .S02_AXI_RREADY(S02_AXI_RREADY),              // input wire S02_AXI_RREADY
      .S03_AXI_ARESET_OUT_N(),                      // output wire S03_AXI_ARESET_OUT_N
      .S03_AXI_ACLK(clk),                           // input wire S03_AXI_ACLK
      .S03_AXI_AWID(S03_AXI_AWID),                  // input wire [0 : 0] S03_AXI_AWID
      .S03_AXI_AWADDR(S03_AXI_AWADDR),              // input wire [31 : 0] S03_AXI_AWADDR
      .S03_AXI_AWLEN(S03_AXI_AWLEN),                // input wire [7 : 0] S03_AXI_AWLEN
      .S03_AXI_AWSIZE(S03_AXI_AWSIZE),              // input wire [2 : 0] S03_AXI_AWSIZE
      .S03_AXI_AWBURST(S03_AXI_AWBURST),            // input wire [1 : 0] S03_AXI_AWBURST
      .S03_AXI_AWLOCK(S03_AXI_AWLOCK),              // input wire S03_AXI_AWLOCK
      .S03_AXI_AWCACHE(S03_AXI_AWCACHE),            // input wire [3 : 0] S03_AXI_AWCACHE
      .S03_AXI_AWPROT(S03_AXI_AWPROT),              // input wire [2 : 0] S03_AXI_AWPROT
      .S03_AXI_AWQOS(S03_AXI_AWQOS),                // input wire [3 : 0] S03_AXI_AWQOS
      .S03_AXI_AWVALID(S03_AXI_AWVALID),            // input wire S03_AXI_AWVALID
      .S03_AXI_AWREADY(S03_AXI_AWREADY),            // output wire S03_AXI_AWREADY
      .S03_AXI_WDATA(S03_AXI_WDATA),                // input wire [127 : 0] S03_AXI_WDATA
      .S03_AXI_WSTRB(S03_AXI_WSTRB),                // input wire [15 : 0] S03_AXI_WSTRB
      .S03_AXI_WLAST(S03_AXI_WLAST),                // input wire S03_AXI_WLAST
      .S03_AXI_WVALID(S03_AXI_WVALID),              // input wire S03_AXI_WVALID
      .S03_AXI_WREADY(S03_AXI_WREADY),              // output wire S03_AXI_WREADY
      .S03_AXI_BID(S03_AXI_BID),                    // output wire [0 : 0] S03_AXI_BID
      .S03_AXI_BRESP(S03_AXI_BRESP),                // output wire [1 : 0] S03_AXI_BRESP
      .S03_AXI_BVALID(S03_AXI_BVALID),              // output wire S03_AXI_BVALID
      .S03_AXI_BREADY(S03_AXI_BREADY),              // input wire S03_AXI_BREADY
      .S03_AXI_ARID(S03_AXI_ARID),                  // input wire [0 : 0] S03_AXI_ARID
      .S03_AXI_ARADDR(S03_AXI_ARADDR),              // input wire [31 : 0] S03_AXI_ARADDR
      .S03_AXI_ARLEN(S03_AXI_ARLEN),                // input wire [7 : 0] S03_AXI_ARLEN
      .S03_AXI_ARSIZE(S03_AXI_ARSIZE),              // input wire [2 : 0] S03_AXI_ARSIZE
      .S03_AXI_ARBURST(S03_AXI_ARBURST),            // input wire [1 : 0] S03_AXI_ARBURST
      .S03_AXI_ARLOCK(S03_AXI_ARLOCK),              // input wire S03_AXI_ARLOCK
      .S03_AXI_ARCACHE(S03_AXI_ARCACHE),            // input wire [3 : 0] S03_AXI_ARCACHE
      .S03_AXI_ARPROT(S03_AXI_ARPROT),              // input wire [2 : 0] S03_AXI_ARPROT
      .S03_AXI_ARQOS(S03_AXI_ARQOS),                // input wire [3 : 0] S03_AXI_ARQOS
      .S03_AXI_ARVALID(S03_AXI_ARVALID),            // input wire S03_AXI_ARVALID
      .S03_AXI_ARREADY(S03_AXI_ARREADY),            // output wire S03_AXI_ARREADY
      .S03_AXI_RID(S03_AXI_RID),                    // output wire [0 : 0] S03_AXI_RID
      .S03_AXI_RDATA(S03_AXI_RDATA),                // output wire [127 : 0] S03_AXI_RDATA
      .S03_AXI_RRESP(S03_AXI_RRESP),                // output wire [1 : 0] S03_AXI_RRESP
      .S03_AXI_RLAST(S03_AXI_RLAST),                // output wire S03_AXI_RLAST
      .S03_AXI_RVALID(S03_AXI_RVALID),              // output wire S03_AXI_RVALID
      .S03_AXI_RREADY(S03_AXI_RREADY),              // input wire S03_AXI_RREADY
      .S04_AXI_ARESET_OUT_N(),                      // output wire S04_AXI_ARESET_OUT_N
      .S04_AXI_ACLK(clk),                           // input wire S04_AXI_ACLK
      .S04_AXI_AWID(S04_AXI_AWID),                  // input wire [0 : 0] S04_AXI_AWID
      .S04_AXI_AWADDR(S04_AXI_AWADDR),              // input wire [31 : 0] S04_AXI_AWADDR
      .S04_AXI_AWLEN(S04_AXI_AWLEN),                // input wire [7 : 0] S04_AXI_AWLEN
      .S04_AXI_AWSIZE(S04_AXI_AWSIZE),              // input wire [2 : 0] S04_AXI_AWSIZE
      .S04_AXI_AWBURST(S04_AXI_AWBURST),            // input wire [1 : 0] S04_AXI_AWBURST
      .S04_AXI_AWLOCK(S04_AXI_AWLOCK),              // input wire S04_AXI_AWLOCK
      .S04_AXI_AWCACHE(S04_AXI_AWCACHE),            // input wire [3 : 0] S04_AXI_AWCACHE
      .S04_AXI_AWPROT(S04_AXI_AWPROT),              // input wire [2 : 0] S04_AXI_AWPROT
      .S04_AXI_AWQOS(S04_AXI_AWQOS),                // input wire [3 : 0] S04_AXI_AWQOS
      .S04_AXI_AWVALID(S04_AXI_AWVALID),            // input wire S04_AXI_AWVALID
      .S04_AXI_AWREADY(S04_AXI_AWREADY),            // output wire S04_AXI_AWREADY
      .S04_AXI_WDATA(S04_AXI_WDATA),                // input wire [127 : 0] S04_AXI_WDATA
      .S04_AXI_WSTRB(S04_AXI_WSTRB),                // input wire [15 : 0] S04_AXI_WSTRB
      .S04_AXI_WLAST(S04_AXI_WLAST),                // input wire S04_AXI_WLAST
      .S04_AXI_WVALID(S04_AXI_WVALID),              // input wire S04_AXI_WVALID
      .S04_AXI_WREADY(S04_AXI_WREADY),              // output wire S04_AXI_WREADY
      .S04_AXI_BID(S04_AXI_BID),                    // output wire [0 : 0] S04_AXI_BID
      .S04_AXI_BRESP(S04_AXI_BRESP),                // output wire [1 : 0] S04_AXI_BRESP
      .S04_AXI_BVALID(S04_AXI_BVALID),              // output wire S04_AXI_BVALID
      .S04_AXI_BREADY(S04_AXI_BREADY),              // input wire S04_AXI_BREADY
      .S04_AXI_ARID(S04_AXI_ARID),                  // input wire [0 : 0] S04_AXI_ARID
      .S04_AXI_ARADDR(S04_AXI_ARADDR),              // input wire [31 : 0] S04_AXI_ARADDR
      .S04_AXI_ARLEN(S04_AXI_ARLEN),                // input wire [7 : 0] S04_AXI_ARLEN
      .S04_AXI_ARSIZE(S04_AXI_ARSIZE),              // input wire [2 : 0] S04_AXI_ARSIZE
      .S04_AXI_ARBURST(S04_AXI_ARBURST),            // input wire [1 : 0] S04_AXI_ARBURST
      .S04_AXI_ARLOCK(S04_AXI_ARLOCK),              // input wire S04_AXI_ARLOCK
      .S04_AXI_ARCACHE(S04_AXI_ARCACHE),            // input wire [3 : 0] S04_AXI_ARCACHE
      .S04_AXI_ARPROT(S04_AXI_ARPROT),              // input wire [2 : 0] S04_AXI_ARPROT
      .S04_AXI_ARQOS(S04_AXI_ARQOS),                // input wire [3 : 0] S04_AXI_ARQOS
      .S04_AXI_ARVALID(S04_AXI_ARVALID),            // input wire S04_AXI_ARVALID
      .S04_AXI_ARREADY(S04_AXI_ARREADY),            // output wire S04_AXI_ARREADY
      .S04_AXI_RID(S04_AXI_RID),                    // output wire [0 : 0] S04_AXI_RID
      .S04_AXI_RDATA(S04_AXI_RDATA),                // output wire [127 : 0] S04_AXI_RDATA
      .S04_AXI_RRESP(S04_AXI_RRESP),                // output wire [1 : 0] S04_AXI_RRESP
      .S04_AXI_RLAST(S04_AXI_RLAST),                // output wire S04_AXI_RLAST
      .S04_AXI_RVALID(S04_AXI_RVALID),              // output wire S04_AXI_RVALID
      .S04_AXI_RREADY(S04_AXI_RREADY),              // input wire S04_AXI_RREADY
      .M00_AXI_ARESET_OUT_N(),                      // output wire M00_AXI_ARESET_OUT_N
      .M00_AXI_ACLK(clk)         ,                  // input wire M00_AXI_ACLK
      .M00_AXI_AWID(dat_awid),                      // output wire [4 : 0] M00_AXI_AWID
      .M00_AXI_AWADDR(dat_awaddr),                  // output wire [31 : 0] M00_AXI_AWADDR
      .M00_AXI_AWLEN(dat_awlen),                    // output wire [7 : 0] M00_AXI_AWLEN
      .M00_AXI_AWSIZE(dat_awsize),                  // output wire [2 : 0] M00_AXI_AWSIZE
      .M00_AXI_AWBURST(dat_awburst),                // output wire [1 : 0] M00_AXI_AWBURST
      .M00_AXI_AWLOCK(dat_awlock),                  // output wire M00_AXI_AWLOCK
      .M00_AXI_AWCACHE(dat_awcache),                // output wire [3 : 0] M00_AXI_AWCACHE
      .M00_AXI_AWPROT(dat_awprot),                  // output wire [2 : 0] M00_AXI_AWPROT
      .M00_AXI_AWQOS(dat_awqos),                    // output wire [3 : 0] M00_AXI_AWQOS
      .M00_AXI_AWVALID(dat_awvalid),                // output wire M00_AXI_AWVALID
      .M00_AXI_AWREADY(dat_awready),                // input wire M00_AXI_AWREADY
      .M00_AXI_WDATA(dat_wdata),                    // output wire [127 : 0] M00_AXI_WDATA
      .M00_AXI_WSTRB(dat_wstrb),                    // output wire [15 : 0] M00_AXI_WSTRB
      .M00_AXI_WLAST(dat_wlast),                    // output wire M00_AXI_WLAST
      .M00_AXI_WVALID(dat_wvalid),                  // output wire M00_AXI_WVALID
      .M00_AXI_WREADY(dat_wready),                  // input wire M00_AXI_WREADY
      .M00_AXI_BID(dat_bid),                        // input wire [4 : 0] M00_AXI_BID
      .M00_AXI_BRESP(dat_bresp),                    // input wire [1 : 0] M00_AXI_BRESP
      .M00_AXI_BVALID(dat_bvalid),                  // input wire M00_AXI_BVALID
      .M00_AXI_BREADY(dat_bready),                  // output wire M00_AXI_BREADY
      .M00_AXI_ARID(dat_arid),                      // output wire [4 : 0] M00_AXI_ARID
      .M00_AXI_ARADDR(dat_araddr),                  // output wire [31 : 0] M00_AXI_ARADDR
      .M00_AXI_ARLEN(dat_arlen),                    // output wire [7 : 0] M00_AXI_ARLEN
      .M00_AXI_ARSIZE(dat_arsize),                  // output wire [2 : 0] M00_AXI_ARSIZE
      .M00_AXI_ARBURST(dat_arburst),                // output wire [1 : 0] M00_AXI_ARBURST
      .M00_AXI_ARLOCK(dat_arlock),                  // output wire M00_AXI_ARLOCK
      .M00_AXI_ARCACHE(dat_arcache),                // output wire [3 : 0] M00_AXI_ARCACHE
      .M00_AXI_ARPROT(dat_arprot),                  // output wire [2 : 0] M00_AXI_ARPROT
      .M00_AXI_ARQOS(dat_arqos),                    // output wire [3 : 0] M00_AXI_ARQOS
      .M00_AXI_ARVALID(dat_arvalid),                // output wire M00_AXI_ARVALID
      .M00_AXI_ARREADY(dat_arready),                // input wire M00_AXI_ARREADY
      .M00_AXI_RID(dat_rid),                        // input wire [4 : 0] M00_AXI_RID
      .M00_AXI_RDATA(dat_rdata),                    // input wire [127 : 0] M00_AXI_RDATA
      .M00_AXI_RRESP(dat_rresp),                    // input wire [1 : 0] M00_AXI_RRESP
      .M00_AXI_RLAST(dat_rlast),                    // input wire M00_AXI_RLAST
      .M00_AXI_RVALID(dat_rvalid),                  // input wire M00_AXI_RVALID
      .M00_AXI_RREADY(dat_rready)                   // output wire M00_AXI_RREADY
    );
	
    logic     oup_wvalid[NPE];
    logic     oup_wreq[NPE];
    uint32_t  oup_waddr[NPE];
    uint128_t oup_wdata[NPE];
    uint16_t  oup_wstb[NPE];
    uint8_t   oup_wlen[NPE];
    uint32_t  oup_baddr;
    
    logic     inp_rvalid[NPE];
    uint128_t inp_rdata[NPE];
    logic     inp_rreq[NPE];
    uint24_t  inp_raddr[NPE];
    uint32_t  inp_baddr;
    
    logic     wei_rdy;
    uint128_t wei_rdata;
    uint32_t  wei_raddr;
    logic     wei_ren;
    uint32_t  wei_baddr;
    
    logic     bias_rdy;
    uint128_t bias_rdata;
    uint32_t  bias_raddr;
    logic     bias_ren;
    uint32_t  bias_baddr;
    
    logic     quant_rdy;
    uint128_t quant_rdata;
    uint32_t  quant_raddr;
    logic     quant_ren;
    uint32_t  quant_baddr;
    
    uint4_t creq;
	
    accelartor_core#(
        .NPE(NPE)
    )acc_core(
        //system parameters
        .clk(clk),
        .resetn(resetn),
        
        //configuration bus
        .cfg_addr(c_addr),
        .cfg_we(c_we),
        .cfg_ren(c_ren),
        .cfg_wdata(c_wdata),
        .cfg_rdy(c_rdy),
        .cfg_rdata(c_rdata),
        .cfg_irq(cfg_irq),
        
        //output cache bus
        .oup_wvalid(oup_wvalid),
        .oup_wreq(oup_wreq),
        .oup_waddr(oup_waddr),
        .oup_wdata(oup_wdata),
        .oup_wstb(oup_wstb),
        .oup_wlen(oup_wlen),
        .oup_baddr(oup_baddr),
        
        
        //input cache bus
        .inp_rvalid(inp_rvalid),
        .inp_rdata(inp_rdata),
        .inp_rreq(inp_rreq),
        .inp_raddr(inp_raddr),
        .inp_baddr(inp_baddr),
        
        //weight cache bus
        .wei_rdy(wei_rdy),
        .wei_rdata(wei_rdata),
        .wei_raddr(wei_raddr),
        .wei_ren(wei_ren),
        .wei_baddr(wei_baddr),
        
        //bias cache bus
        .bias_rdy(bias_rdy),
        .bias_rdata(bias_rdata),
        .bias_raddr(bias_raddr),
        .bias_ren(bias_ren),
        .bias_baddr(bias_baddr),
        
        //quant cache bus
        .quant_rdy(quant_rdy),
        .quant_rdata(quant_rdata),
        .quant_raddr(quant_raddr),
        .quant_ren(quant_ren),
        .quant_baddr(quant_baddr),
        
        //cache clear request
        .creq(creq)
    );
    
    oup_rr_arbiter#(
        .NPE(NPE)
    )oup_arb(
        //system parameters
        .clk(clk),
        .resetn(resetn),
        
        //Cache interface
        .inp_baddr(oup_baddr),
        .inp_wreq(oup_wreq),
        .inp_waddr(oup_waddr),
        .inp_wdata(oup_wdata),
        .inp_wstb(oup_wstb),
        .inp_wlen(oup_wlen),
        .oup_wack(oup_wvalid),
        
        //AXI Interface
        
        //Write address channel
        .inp_awready(S00_AXI_AWREADY),
        .oup_awaddr(S00_AXI_AWADDR),
        .oup_awlen(S00_AXI_AWLEN),
        .oup_awvalid(S00_AXI_AWVALID),
        
        //Write data channel
        .inp_wready(S00_AXI_WREADY),
        .oup_wrdata(S00_AXI_WDATA),
        .oup_wstb(S00_AXI_WSTRB),
        .oup_wvalid(S00_AXI_WVALID),
        .oup_wlast(S00_AXI_WLAST),
        
        //Read address channel
        .inp_arready(S00_AXI_ARREADY),
        .oup_araddr(S00_AXI_ARADDR),
        .oup_arlen(S00_AXI_ARLEN),
        .oup_arvalid(S00_AXI_ARVALID),
        
        //Read data channel
        .inp_rdata(S00_AXI_RDATA),
        .inp_rvalid(S00_AXI_RVALID),
        .inp_rlast(S00_AXI_RLAST),
        .oup_rready(S00_AXI_RREADY)
    );
    
    inp_rr_arbiter#(
        .NPE(NPE)
    )inp_arb(
        //system parameters
        .clk(clk),
        .resetn(resetn),
        
        //Cache interface
        .inp_baddr(inp_baddr),
        .inp_rreq(inp_rreq),
        .inp_raddr(inp_raddr),
        .oup_rvalid(inp_rvalid),
        .oup_rdata(inp_rdata),
        
        //AXI Interface
        
        //Write address channel
        .inp_awready(S01_AXI_AWREADY),
        .oup_awaddr(S01_AXI_AWADDR),
        .oup_awlen(S01_AXI_AWLEN),
        .oup_awvalid(S01_AXI_AWVALID),
        
        //Write data channel
        .inp_wready(S01_AXI_WREADY),
        .oup_wrdata(S01_AXI_WDATA),
        .oup_wvalid(S01_AXI_WVALID),
        .oup_wlast(S01_AXI_WLAST),
        
        //Read address channel
        .inp_arready(S01_AXI_ARREADY),
        .oup_araddr(S01_AXI_ARADDR),
        .oup_arlen(S01_AXI_ARLEN),
        .oup_arvalid(S01_AXI_ARVALID),
        
        //Read data channel
        .inp_rdata(S01_AXI_RDATA),
        .inp_rvalid(S01_AXI_RVALID),
        .inp_rlast(S01_AXI_RLAST),
        .oup_rready(S01_AXI_RREADY)
    );
    
    rd_cache_mem filter_mem(
        //system parameters
        .clk(clk),
        .resetn(resetn),
        
        //Read Data Bus
        .inp_creq(creq[2]),    
        .inp_baddr(wei_baddr),
        .inp_raddr(wei_raddr),
        .inp_ren(wei_ren),
        .oup_rdy(wei_rdy),
        .oup_rdata(wei_rdata),
        
        //AXI Interface
        
        //Write address channel
        .inp_awready(S02_AXI_AWREADY),
        .oup_awaddr(S02_AXI_AWADDR),
        .oup_awlen(S02_AXI_AWLEN),
        .oup_awvalid(S02_AXI_AWVALID),
        
        //Write data channel
        .inp_wready(S02_AXI_WREADY),
        .oup_wrdata(S02_AXI_WDATA),
        .oup_wvalid(S02_AXI_WVALID),
        .oup_wlast(S02_AXI_WLAST),
        
        //Read address channel
        .inp_arready(S02_AXI_ARREADY),
        .oup_araddr(S02_AXI_ARADDR),
        .oup_arlen(S02_AXI_ARLEN),
        .oup_arvalid(S02_AXI_ARVALID),
        
        //Read data channel
        .inp_rdata(S02_AXI_RDATA),
        .inp_rvalid(S02_AXI_RVALID),
        .inp_rlast(S02_AXI_RLAST),
        .oup_rready(S02_AXI_RREADY)
    );
    
    rd_cache_mem bias_mem(
        //system parameters
        .clk(clk),
        .resetn(resetn),
        
        //Read Data Bus
        .inp_creq(creq[3]),    
        .inp_baddr(bias_baddr),
        .inp_raddr(bias_raddr),
        .inp_ren(bias_ren),
        .oup_rdy(bias_rdy),
        .oup_rdata(bias_rdata),
        
        //AXI Interface
        
        //Write address channel
        .inp_awready(S03_AXI_AWREADY),
        .oup_awaddr(S03_AXI_AWADDR),
        .oup_awlen(S03_AXI_AWLEN),
        .oup_awvalid(S03_AXI_AWVALID),
        
        //Write data channel
        .inp_wready(S03_AXI_WREADY),
        .oup_wrdata(S03_AXI_WDATA),
        .oup_wvalid(S03_AXI_WVALID),
        .oup_wlast(S03_AXI_WLAST),
        
        //Read address channel
        .inp_arready(S03_AXI_ARREADY),
        .oup_araddr(S03_AXI_ARADDR),
        .oup_arlen(S03_AXI_ARLEN),
        .oup_arvalid(S03_AXI_ARVALID),
        
        //Read data channel
        .inp_rdata(S03_AXI_RDATA),
        .inp_rvalid(S03_AXI_RVALID),
        .inp_rlast(S03_AXI_RLAST),
        .oup_rready(S03_AXI_RREADY)
    );


    rd_cache_mem quant_mem(
        //system parameters
        .clk(clk),
        .resetn(resetn),
        
        //Read Data Bus
        .inp_creq(creq[3]),    
        .inp_baddr(quant_baddr),
        .inp_raddr(quant_raddr),
        .inp_ren(quant_ren),
        .oup_rdy(quant_rdy),
        .oup_rdata(quant_rdata),
        
        //AXI Interface
        
        //Write address channel
        .inp_awready(S04_AXI_AWREADY),
        .oup_awaddr(S04_AXI_AWADDR),
        .oup_awlen(S04_AXI_AWLEN),
        .oup_awvalid(S04_AXI_AWVALID),
        
        //Write data channel
        .inp_wready(S04_AXI_WREADY),
        .oup_wrdata(S04_AXI_WDATA),
        .oup_wvalid(S04_AXI_WVALID),
        .oup_wlast(S04_AXI_WLAST),
        
        //Read address channel
        .inp_arready(S04_AXI_ARREADY),
        .oup_araddr(S04_AXI_ARADDR),
        .oup_arlen(S04_AXI_ARLEN),
        .oup_arvalid(S04_AXI_ARVALID),
        
        //Read data channel
        .inp_rdata(S04_AXI_RDATA),
        .inp_rvalid(S04_AXI_RVALID),
        .inp_rlast(S04_AXI_RLAST),
        .oup_rready(S04_AXI_RREADY)
    );
	
endmodule
