`timescale 1ns / 1ps

`include "data_types.svh"

module accelartor_core#(
    parameter NPE  = 16
)(
    //system parameters
    input logic clk,
    input logic resetn,
    
    //configuration bus
    input  uint32_t cfg_addr,
    input  uint4_t  cfg_we,
    input  logic    cfg_ren,
    input  uint32_t cfg_wdata,
    output logic    cfg_rdy,
    output uint32_t cfg_rdata,
    output logic    cfg_irq,
    
    //output cache bus
    input  logic     oup_wvalid[NPE],
    output logic     oup_wreq[NPE],
    output uint32_t  oup_waddr[NPE],
    output uint128_t oup_wdata[NPE],
    output uint16_t  oup_wstb[NPE],
    output uint8_t   oup_wlen[NPE],
    output uint32_t  oup_baddr,
    
    //input cache bus
    input  logic     inp_rvalid[NPE],
    input  uint128_t inp_rdata[NPE],
    output logic     inp_rreq[NPE],
    output uint24_t  inp_raddr[NPE],
    output uint32_t  inp_baddr,
    
    //weight cache bus
    input  logic     wei_rdy,
    input  uint128_t wei_rdata,
    output uint32_t  wei_raddr,
    output logic     wei_ren,
    output uint32_t  wei_baddr,
    
    //bias cache bus
    input  logic     bias_rdy,
    input  uint128_t bias_rdata,
    output uint32_t  bias_raddr,
    output logic     bias_ren,
    output uint32_t  bias_baddr,
    
    //quant cache bus
    input  logic     quant_rdy,
    input  uint128_t quant_rdata,
    output uint32_t  quant_raddr,
    output logic     quant_ren,
    output uint32_t  quant_baddr,
    
    //cache clear request
    output uint4_t creq
);

    function and_reduction (input logic x_arr[NPE]);
        logic res;
        res = 1'b1;
        for(int i = 0; i < NPE; i++) begin
            res = res & x_arr[i];
        end 
        return res;
    endfunction
    
    //control unit parameters
    logic ctrl_start, ctrl_wen, ctrl_ren;
    logic ctrl_inp_rdy, ctrl_wei_rdy, ctrl_oup_rdy, ctrl_bias_rdy, ctrl_quant_rdy, ctrl_run, ctrl_run_r;
    logic ctrl_acc_en, ctrl_acc_clr, ctrl_acc_valid, requant_start, requant_done, mac_rdy_s0, mac_rdy_s1, oup_cmpl;
    logic aen_d, acl_d;
    logic inp_valid[NPE], inp_valid_r[NPE], acv[NPE/2];
    uint8_t  ctrl_addr;
    uint32_t ctrl_wdata, ctrl_rdata;
    uint24_t ctrl_inp_addr[NPE], ctrl_oup_addr[NPE], ctrl_wei_addr;
    uint18_t ctrl_bias_addr, ctrl_quant_addr;
    uint4_t  ch_offs_s0, ch_offs_s1;
    
    //mac units parameters
    int32_t  inp_acc[NPE][16]; 
    int8_t   oup_acc[NPE][16];
    int8_t   inp_w[16]; 
    int32_t  inp_bias[16];
    uint32_t inp_quant[16];
    int9_t   inp_zero;
    int9_t   oup_zero;
    
    //cache cluster parameters
    
    //input cache
    //input cache
    uint32_t  baddr[5];  //base addresses of five caches
    logic     ic_ren[NPE];
    uint128_t ic_rdata[NPE];
    int8_t    ic_rdata_unpacked[NPE][16];
    uint24_t  ic_raddr[NPE];
    logic     cinv;
    
    logic ic_rdy[NPE];
    
    //output cache
    logic     oc_rdy[NPE], oc_cmpl[NPE];
    uint128_t oc_rdata[NPE];
    uint24_t  oc_addr[NPE];
    logic     oen[NPE];  //output enable
    logic     chen[NPE]; //channel enable
    uint5_t   oup_res;
    
    //flush request
    uint4_t flreq;
    logic [NPE-1 : 0]  flbusy;
    
    assign oup_baddr = baddr[0];
    assign inp_baddr = baddr[1];
    
    assign wei_baddr    = baddr[2];
    assign wei_raddr    = ctrl_wei_addr;
    assign wei_ren      = ctrl_acc_en;
    assign ctrl_wei_rdy = wei_rdy;
    
    generate
        for(genvar i = 0; i < 16; i++)
            assign inp_w[i] =  wei_rdata[(i*8+7)-:8];
    endgenerate
            
    assign bias_baddr    = baddr[3];
    assign bias_raddr    = {(ctrl_bias_addr>>2)+ch_offs_s0, 4'b0};
    assign bias_ren      = ctrl_run_r;
    assign ctrl_bias_rdy = bias_rdy;
    
    assign ctrl_quant_addr = ctrl_bias_addr;
    assign quant_baddr     = baddr[4];
    assign quant_raddr     = {(ctrl_quant_addr>>2)+ch_offs_s0, 4'b0};
    assign quant_ren       = ctrl_run_r;
    assign ctrl_quant_rdy  = quant_rdy;
    
    logic t_rdy;  //ready signal for bias, filter, quant caches
    logic dwen;
    
    assign mac_rdy_s0 = ctrl_inp_rdy & t_rdy;
    
    assign requant_start  = acv[0];
    assign ctrl_acc_valid = requant_done;
    assign ctrl_oup_rdy   = and_reduction(oc_rdy);
    assign oup_cmpl       = and_reduction(oc_cmpl);
    assign ctrl_inp_rdy   = and_reduction(ic_rdy);
    
    enum {Idle, Bfetch, Beval, Bterm, Bwait} state;
        
    always_ff@(posedge clk) begin
        if(~resetn) begin
            state             <= Idle;
            ch_offs_s0        <= 'd0;
            ch_offs_s1        <= 'd0;
            inp_bias          <= '{16{'d0}};
            inp_quant         <= '{16{'d0}};
        end
        else begin            
            if(~aen_d) begin
                state      <= Idle;
                ch_offs_s0 <= 'd0;
                ch_offs_s1 <= 'd0;
            end else if(ctrl_bias_rdy && ctrl_quant_rdy) begin 
                case(state)
                    Idle: begin
                        ch_offs_s0 <= 'd0;
                        ch_offs_s1 <= 'd0;
                        state      <= Beval;
                    end
                    Beval: begin
                        state      <= Bfetch;
                    end
                    Bfetch: begin
                        ch_offs_s0 <= ch_offs_s0 + 'd1;
                        ch_offs_s1 <= ch_offs_s0;
                        
                        inp_bias[4*ch_offs_s1]   <= bias_rdata[31:0];
                        inp_bias[4*ch_offs_s1+1] <= bias_rdata[63:32];
                        inp_bias[4*ch_offs_s1+2] <= bias_rdata[95:64];
                        inp_bias[4*ch_offs_s1+3] <= bias_rdata[127:96];
                        
                        inp_quant[4*ch_offs_s1]   <= quant_rdata[31:0];
                        inp_quant[4*ch_offs_s1+1] <= quant_rdata[63:32];
                        inp_quant[4*ch_offs_s1+2] <= quant_rdata[95:64];
                        inp_quant[4*ch_offs_s1+3] <= quant_rdata[127:96];
                        
                        if(ch_offs_s0 >= 3) begin  // Changed from > 2 to >= 3
                            state <= Bterm;
                        end
                    end
                    Bterm: begin
                        inp_bias[4*ch_offs_s1]   <= bias_rdata[31:0];
                        inp_bias[4*ch_offs_s1+1] <= bias_rdata[63:32];
                        inp_bias[4*ch_offs_s1+2] <= bias_rdata[95:64];
                        inp_bias[4*ch_offs_s1+3] <= bias_rdata[127:96];
                        
                        inp_quant[4*ch_offs_s1]   <= quant_rdata[31:0];
                        inp_quant[4*ch_offs_s1+1] <= quant_rdata[63:32];
                        inp_quant[4*ch_offs_s1+2] <= quant_rdata[95:64];
                        inp_quant[4*ch_offs_s1+3] <= quant_rdata[127:96];
                        
                        state <= Bwait;
                    end
                    Bwait: begin
                    end
                endcase
            end 
        end
        
        for(int i = 0; i < NPE; i++) begin
            inp_valid_r[i] <= inp_valid[i];
        end
        
        aen_d <= ctrl_acc_en;
        acl_d <= ctrl_acc_clr;
        
        mac_rdy_s1 <= mac_rdy_s0;
        t_rdy      <= ctrl_wei_rdy & ctrl_bias_rdy & ctrl_quant_rdy;
    end


    generate
        requantizer_array  #(.N(16), .M(NPE)) requant_arr
        (
            .clk(clk),
            .resetn(resetn),
            .start(requant_start),
            .inp_acc(inp_acc),
            .oup_zero(oup_zero),
            .inp_quant(inp_quant),
            .oup_acc(oup_acc),
            .oup_valid(requant_done)     
        );
        for(genvar i = 0; i < NPE; i++) begin
            assign ic_ren[i]   = chen[i] & ctrl_acc_en & inp_valid[i];
            assign ic_raddr[i] = ctrl_inp_addr[i];
            assign oc_addr[i]  = ctrl_oup_addr[i];
            for(genvar j = 0; j < 16; j++) begin
                assign oc_rdata[i][(j*8+7)-:8] = oup_acc[i][j];
                assign ic_rdata_unpacked[i][j] = ic_rdata[i][(j*8+7)-:8];
            end
           
            inp_cache_16n inp_cache_inst(
            //system parameters
                .clk(clk),
                .resetn(resetn & chen[i]),
                .cinv(cinv),
                
                //PE interface
                .inp_dwen(dwen),
                .inp_ren(ic_ren[i]),
                .inp_raddr(ic_raddr[i]),
                .oup_rdata(ic_rdata[i]),   
                .oup_rdy(ic_rdy[i]),
                
                //Main memory interface
                .oup_rreq(inp_rreq[i]),
                .inp_rvalid(inp_rvalid[i]),
                .oup_raddr(inp_raddr[i]),
                .inp_rdata(inp_rdata[i])    
            );
            
            oup_cache_16n oup_cache_inst(
                //system parameters
                .clk(clk),
                .resetn(resetn & chen[i]),
                .cinv(cinv),     
                .freq(flreq[0]),     
                .busy(flbusy[i]),     
                
                //PE interface
                .inp_addr(oc_addr[i]),
                .inp_we(ctrl_acc_valid & oen[i]),
                .inp_pch(oup_res),   
                .inp_wdata(oc_rdata[i]),
                .oup_rdy(oc_rdy[i]),
                .oup_cmpl(oc_cmpl[i]),
                
                //Memory interface
                .oup_wreq(oup_wreq[i]),
                .inp_wack(oup_wvalid[i]),
                .oup_waddr(oup_waddr[i]),
                .oup_wdata(oup_wdata[i]),
                .oup_wstb(oup_wstb[i]),
                .oup_wlen(oup_wlen[i])
            );                      
            
        end
        
         for(genvar i = 0; i < 8; i++) begin
            mac_arr_2xn #(
                .N(16)
            ) mac_arr (
                .clk(clk),
                .resetn(resetn),
                .inp_en(aen_d),
                .inp_clr(acl_d),
                .inp_rdy(mac_rdy_s0 & mac_rdy_s1),
                .inp_valid1(inp_valid_r[2*i]),
                .inp_valid2(inp_valid_r[2*i+1]),
                .inp_d1(ic_rdata_unpacked[2*i]),
                .inp_d2(ic_rdata_unpacked[2*i+1]),
                .inp_w(inp_w),
                .inp_bias(inp_bias),
                .inp_zero(inp_zero),
                .oup_acc1(inp_acc[2*i]),
                .oup_acc2(inp_acc[2*i+1]),
                .oup_valid(acv[i])
            );
        end
        
    endgenerate
    
    //user configuration
    logic cfg_param;     //accelartor configuration parameters
    logic cfg_flag;      //accelartor flags
    logic cfg_flush;     //cache flush control
    logic flg_busy;
    logic inten, cmpl;
    
    uint2_t  run_d;
    uint32_t flag_data;
    
    assign inten     = 1'b1;
    assign cfg_irq   = inten & cmpl;
    assign cfg_flush = (cfg_addr & 32'hfffffffc) ==  32'hffff0180 ? 1'b1 : 1'b0;
    assign cfg_flag  = (cfg_addr[31:8] == 24'hffff03); 
    assign cfg_param = ({cfg_addr[31:9], 1'b0} == 24'hffff04); 
    assign flreq     = (cfg_flush && cfg_we[0]) ? cfg_wdata[7:4] : 4'd0;
    
    uint4_t clreq;
    assign clreq   = (cfg_flush && cfg_we[0]) ? cfg_wdata[3:0] : 4'd0;
    assign cinv    = clreq[0];
    assign creq    = clreq;
    
    assign ctrl_wen   = cfg_param & (cfg_we != 4'd0);
    assign ctrl_ren   = cfg_param & cfg_ren;
    assign ctrl_start = cfg_flag & cfg_we[0] & cfg_wdata[0] & (cfg_addr[7:2] == 0);
    assign ctrl_addr  = cfg_addr[9:2];
    assign ctrl_wdata = cfg_wdata;
    assign cfg_rdata  = ctrl_rdata | flag_data;
    assign cfg_rdy    = 1'b1;
    assign flg_busy   = flbusy != 0;
    
    always_ff@(posedge clk) begin
        if(cfg_flag && (cfg_we != 0)) begin
            case(cfg_addr[7:2])
                6'd1: baddr[0] <= cfg_wdata;
                6'd2: baddr[1] <= cfg_wdata;
                6'd3: baddr[2] <= cfg_wdata;
                6'd4: baddr[3] <= cfg_wdata;
                6'd5: baddr[4] <= cfg_wdata;
            endcase
        end
        
        run_d <= {run_d[0], ctrl_run};
        if(~resetn) begin
            //inten     <= 1'b0;  
            flag_data <= 'd0;
        end else if(cfg_flag && cfg_we[1] && (cfg_addr[7:2] == 0)) begin
            //inten <= cfg_wdata[9];
            cmpl  <= cfg_wdata[8];
        end else if(run_d == 'd2) begin
            cmpl  <= inten;
        end
        
        if(cfg_flag && cfg_ren) begin
            case(cfg_addr[7:2])
                6'd0: flag_data <= {22'h0, inten, cmpl, 7'h0, ctrl_run};
                6'd1: flag_data <= baddr[0];
                6'd2: flag_data <= baddr[1];
                6'd3: flag_data <= baddr[2];
                6'd4: flag_data <= baddr[3];
                6'd5: flag_data <= baddr[4];
                6'd7: flag_data <= NPE;
                6'd8: flag_data <= cmpl;
                default: flag_data <= 32'h0;
            endcase
        end else if(cfg_flush & cfg_ren) begin
            flag_data <= {flg_busy, oup_cmpl, 6'h0};
        end else begin
            flag_data <= 'd0;
        end
    end
    
    ctrl_logic#(
        .CHP(16),    
        .NPE(NPE)    
    )ctrl_unit_inst(
        //system parameters
        .clk(clk),
        .resetn(resetn),
        
        //configuration bus
        .ctrl_start(ctrl_start),
        .ctrl_wen(ctrl_wen),
        .ctrl_ren(ctrl_ren),
        .ctrl_addr(ctrl_addr),
        .ctrl_wdata(ctrl_wdata),
        .ctrl_rdata(ctrl_rdata),
            
        //IFMAP Addresses
        .ctrl_inp_rdy(ctrl_inp_rdy),
        .ctrl_inp_addr(ctrl_inp_addr),
        .ctrl_inp_valid(inp_valid),
         
        //Weight Addresses
        .ctrl_wei_rdy(ctrl_wei_rdy),
        .ctrl_wei_addr(ctrl_wei_addr),
         
        //OFMAP Addresses
        .ctrl_oup_rdy(ctrl_oup_rdy),
        .ctrl_oup_addr(ctrl_oup_addr),
        .ctrl_oup_res(oup_res),
        .ctrl_oup_en(oen),
        .ctrl_oup_chen(chen),
         
        //Bias Addresses
        .ctrl_bias_rdy(ctrl_bias_rdy),
        .ctrl_bias_addr(ctrl_bias_addr),
         
        //Run Flags
        .ctrl_run(ctrl_run),
        .ctrl_run_r(ctrl_run_r),
         
        //PE cluster control
        .ctrl_acc_valid(ctrl_acc_valid),
        .ctrl_acc_en(ctrl_acc_en),
        .ctrl_acc_clr(ctrl_acc_clr),
        .ctrl_dwen(dwen),
        
        //Quantize parameters
        .ctrl_inp_zero(inp_zero),
        .ctrl_oup_zero(oup_zero)
    );

endmodule
