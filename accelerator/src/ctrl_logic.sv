`timescale 1ns / 1ps

`include "data_types.svh"

module ctrl_logic#(
    parameter CHP  = 32,   
    parameter NPE  = 16    
)(
    //system parameters
    input logic clk,
    input logic resetn,
    
    //configuration bus
    input  logic    ctrl_start,
    input  logic    ctrl_wen,
    input  logic    ctrl_ren,
    input  uint8_t  ctrl_addr,
    input  uint32_t ctrl_wdata,
    output uint32_t ctrl_rdata,
        
    //IFMAP Addresses
    input  logic    ctrl_inp_rdy,
    output uint24_t ctrl_inp_addr[NPE],
    output logic    ctrl_inp_valid[NPE],
     
    //Weight Addresses
    input  logic    ctrl_wei_rdy,
    output uint24_t ctrl_wei_addr,
     
    //OFMAP Addresses
    input  logic    ctrl_oup_rdy,
    output uint24_t ctrl_oup_addr[NPE],
    output uint5_t  ctrl_oup_res,
    output logic    ctrl_oup_en[NPE],
    output logic    ctrl_oup_chen[NPE],
     
    //Bias Addresses
    input  logic    ctrl_bias_rdy,
    output uint18_t ctrl_bias_addr,
     
    //Run Flags
    output logic ctrl_run,
    output logic ctrl_run_r,
     
    //PE cluster control
    input  logic ctrl_acc_valid,
    output logic ctrl_acc_en,
    output logic ctrl_acc_clr,
    output logic ctrl_dwen,
    
    //Quantize parameters
    output int9_t ctrl_inp_zero,
    output int9_t ctrl_oup_zero
);

    localparam OUT_ADDR_OFF   = 20+NPE;
    localparam IN_ADDR_OFF_X  = OUT_ADDR_OFF+NPE;
    localparam IN_ADDR_OFF_Y  = IN_ADDR_OFF_X+NPE;
    
    // Internal signals for address generation logic
    uint24_t inp_addr_r[NPE], inp_addr_n[NPE];
    uint24_t wei_addr_r, wei_addr_n;
    logic valid_r[NPE], valid_n[NPE];
    logic rdy_s0, rdy_s1;
    logic acc_en_r, acc_en_n;
    
    // Combinational logic for address and valid signals
    always_comb begin
        for (int i = 0; i < NPE; i++) begin
            ctrl_inp_addr[i]  = rdy_s1 ? inp_addr_r[i] : inp_addr_n[i];
            ctrl_inp_valid[i] = rdy_s1 ? valid_r[i]    : valid_n[i];
        end
        ctrl_wei_addr = rdy_s1 ? wei_addr_r : wei_addr_n;
        ctrl_acc_en   = rdy_s1 ? acc_en_r   : acc_en_n;
    end
    
    // Sequential logic for address and enable registers
    always_ff @(posedge clk) begin
        rdy_s1 <= rdy_s0;
        if (~resetn) begin
            acc_en_n <= 1'b0;
        end else begin
            for (int i = 0; i < NPE; i++) begin
                inp_addr_n[i] <= (rdy_s0 ? inp_addr_r[i] : inp_addr_n[i]);
                valid_n[i]    <= (rdy_s0 ? valid_r[i]    : valid_n[i]);
            end
            wei_addr_n <= rdy_s0 ? wei_addr_r : wei_addr_n;
            acc_en_n   <= rdy_s0 ? acc_en_r   : acc_en_n;
        end
    end
    // Convolution and quantization parameters
    uint11_t inp_height, inp_width, inp_ch, inp_ch_r, fil_ch;
    uint4_t  fil_height, fil_width;
    uint11_t oup_height, oup_width, oup_ch, oup_ch_r;
    uint20_t tile_num, oup_wh;
    uint16_t fil_size;    //fil_h * fil_w * fil_ch
    uint3_t  str_height, str_width, pad_height , pad_width;
    logic    dwc_en, dwc_en_r1, dwc_en_r2, calc, oup_addr_inc;
    uint8_t  chen;
    uint24_t jump_inc;
    uint11_t oupx_init[NPE], oupy_init[NPE];
    uint24_t oup_addr_init[NPE];
    int24_t  inpx_init[NPE], inpy_init[NPE];
    
    assign ctrl_dwen = dwc_en;    
    
    //Convolution Channels Count
    uint11_t chOup, chInp, chStr;
    assign chOup = dwc_en ? inp_ch : oup_ch;
    assign chInp = dwc_en ? 'd1 : inp_ch;
    assign chStr = dwc_en ? oup_ch : inp_ch;    
    
    //Filter Stride
    uint11_t fil_ch_inc;
    assign fil_ch_inc = CHP;
    
    uint11_t ch_ptr, inp_ch_ptr, oup_ch_ptr;
    assign ch_ptr = dwc_en ? oup_ch_ptr : inp_ch_ptr;  
    
    //Depbug Counters
    uint24_t runCounter, rdyCounter;

    //FSM Controll Params
    logic kick_s0, kick_s1, run_s1;
    assign rdy_s0 = ctrl_inp_rdy && ctrl_wei_rdy && ctrl_bias_rdy;
    
    always_ff @(posedge clk) begin
        run_s1 <= ctrl_run_r;
        if (!resetn) begin
            kick_s0  <= 1'b0;
        end else if (ctrl_start) begin
            kick_s0    <= 1'b1; 
            runCounter <= 'd0;
            rdyCounter <= 'd0;
        end else begin
            if (run_s1) begin
                runCounter <= runCounter + 1;
                kick_s0 <= 1'b0;
            end
            if (run_s1 && !rdy_s1) rdyCounter <= rdyCounter + 1;
        end
        ctrl_run <= kick_s0 | run_s1;

        // Parameter read logic
        if (ctrl_ren) begin
            case (ctrl_addr)
                0: ctrl_rdata <= runCounter;
                1: ctrl_rdata <= rdyCounter;
                default ctrl_rdata <= 'd0;
            endcase
        end else begin
            ctrl_rdata <= 'd0;
        end
    end
    
    enum {Idle, Init, Acc, AccPost, ConvEnd} fsm_state;
    uint11_t oup_x[NPE], oup_y[NPE];
    int24_t  inp_x[NPE], inp_y[NPE];
    int12_t  inp_xo[NPE], inp_yo[NPE], inp_xl[NPE], inp_yl[NPE];
    uint4_t  fil_x, fil_y;
    uint5_t  oup_res;
    int28_t  inp_addr_xy[NPE];
    uint20_t oup_a;
    int9_t inp_zero;
    int9_t oup_zero;
    
    // Calculate input offset addresses
    always_ff@(posedge clk) begin
        for(int i = 0; i < NPE; i++) begin
            inp_xo[i]      <= signed'((oup_x[i] * str_width)  - pad_width);
            inp_yo[i]      <= signed'((oup_y[i] * str_height) - pad_height);
            inp_addr_xy[i] <= inp_x[i] + inp_y[i];
        end
        ctrl_inp_zero <= inp_zero;
        ctrl_oup_zero <= oup_zero;
        dwc_en_r2     <= dwc_en_r1;
        dwc_en        <= dwc_en_r2; 
        inp_ch        <= inp_ch_r;
        oup_ch        <= oup_ch_r;
    end
    
    //Limit check
    always_comb begin
        for(int i = 0; i < NPE; i++) begin
            inp_xl[i] <= inp_xo[i] + signed'(fil_x);
            inp_yl[i] <= inp_yo[i] + signed'(fil_y);
        end
    end
    
    
    // Parameter write logic
    always_ff @(posedge clk) begin
        if (ctrl_wen) begin
            case (ctrl_addr)
                0: inp_height <= ctrl_wdata;
                1: inp_width  <= ctrl_wdata;
                2: inp_ch_r   <= ctrl_wdata;
                3: fil_height <= ctrl_wdata;
                4: fil_width  <= ctrl_wdata;
                5: fil_ch     <= ctrl_wdata;
                6: oup_height <= ctrl_wdata;
                7: oup_width  <= ctrl_wdata;
                8: oup_ch_r   <= ctrl_wdata;
                9: tile_num   <= ctrl_wdata;
                10: {str_height, pad_height} <= ctrl_wdata;
                11: {str_width,  pad_width}  <= ctrl_wdata;
                12: dwc_en_r1      <= ctrl_wdata;
                13: inp_zero       <= ctrl_wdata;
                14: oup_zero       <= ctrl_wdata;
                15: oup_wh         <= ctrl_wdata;
                16: fil_size       <= ctrl_wdata;
                17: chen           <= ctrl_wdata;
                18: jump_inc       <= ctrl_wdata;
                default: ;
            endcase
            for (int i = 0; i < NPE; i++) begin
                if (ctrl_addr == i + 20) begin
                    oupy_init[i] <= ctrl_wdata[26:16];
                    oupx_init[i] <= ctrl_wdata[10:0];
                end
            end
            for (int i = 0; i < NPE; i++) begin
                if (ctrl_addr == i + OUT_ADDR_OFF) begin
                    oup_addr_init[i] <= ctrl_wdata;
                end
            end
            for (int i = 0; i < NPE; i++) begin
                if (ctrl_addr == i + IN_ADDR_OFF_X) begin
                    inpx_init[i] <= ctrl_wdata;
                end
            end
            for (int i = 0; i < NPE; i++) begin
                if (ctrl_addr == i + IN_ADDR_OFF_Y) begin
                    inpy_init[i] <= ctrl_wdata;
                end
            end
        end
    end
    
    logic[2:0] ncalc;
    always_ff@(posedge clk) begin
        kick_s1     <= kick_s0;
        if(~resetn) begin
            fsm_state <= Idle;
            
            inp_addr_r     <= '{NPE{'d0}};
            valid_r        <= '{NPE{1'b0}};
            ctrl_oup_addr  <= '{NPE{'d0}};
            ctrl_oup_en    <= '{NPE{1'b0}};
            ctrl_oup_chen  <= '{NPE{1'b0}};
            oup_x          <= '{NPE{'d0}};
            oup_y          <= '{NPE{'d0}};
            inp_x          <= '{NPE{'d0}};
            inp_y          <= '{NPE{'d0}};
            
            ctrl_bias_addr   <= 'd0;
            wei_addr_r       <= 'd0;
            oup_res          <= 'd0;
            acc_en_r         <= 'd0;
            ctrl_acc_clr     <= 'd0;
            calc             <= 1'd0;
            ncalc            <= 1'd0;
            oup_addr_inc     <= 1'd0;
            inp_ch_ptr       <= 'd0;
            oup_ch_ptr       <= 'd0;
            ctrl_run_r       <= 1'd0;
            fil_x            <= 'd0;
            fil_y            <= 'd0;
            oup_a            <= 'd0;
        end else begin
            if((ncalc > 0) && rdy_s0) begin
                wei_addr_r <= fil_size * oup_ch_ptr;
            end
            case(fsm_state)
                Idle: begin
                    if(kick_s1) begin
                        fsm_state <= Init;
                        calc      <= 1'b1;
                    end else begin
                        calc      <= 1'b0;
                    end
                    ctrl_run_r     <= 1'b0;
                    oup_a          <= 0;
                    oup_ch_ptr     <= 0;
                    fil_y          <= 0;
                    fil_x          <= 0;
                    inp_ch_ptr     <= 0;
                    valid_r        <= '{NPE{'b0}};
                    ctrl_oup_en    <= '{NPE{'b0}};
                    acc_en_r       <= 1'b0;
                    ctrl_acc_clr   <= 1'b0;
                    oup_addr_inc   <= 1'b0;
                    oup_res        <= chOup >= CHP ? CHP-1 : chOup - 1;	
                    ncalc          <= 'd0;
                    inp_addr_r     <= '{NPE{'d0}};
                    wei_addr_r     <= 'd0;
                    ctrl_bias_addr <= 'd0;
                end//Idle
                Init: begin
                    valid_r       <= '{NPE{'b0}};
                    acc_en_r      <= 1'b0;
                    ctrl_acc_clr  <= 1'b1;
                    calc          <= 1'b0;
                    ncalc         <= ncalc + 1;
                    if(ncalc > 1) fsm_state  <= Acc;
                    
                    if(kick_s1) begin
                        for(int i = 0; i < NPE; i++) begin
                            oup_x[i]         <= oupx_init[i];
                            oup_y[i]         <= oupy_init[i];
                            inp_x[i]         <= inpx_init[i];
                            inp_y[i]         <= inpy_init[i];
                            ctrl_oup_addr[i] <= oup_addr_init[i];
                        end
                        ctrl_oup_res <= chOup >= CHP ? CHP-1 : chOup - 1;	
                    end
                    for(int i = 0; i < NPE; i++) begin
                        ctrl_oup_en[i]   <= i < chen;
                        ctrl_oup_chen[i] <= i < chen;
                    end
                end//Init
                Acc: begin
                    acc_en_r      <= 1'b1;
                    ctrl_acc_clr  <= 1'b0;
                    oup_addr_inc  <= 1'b0;
                    ncalc         <= 'd0;
                    ctrl_run_r    <= 1'd1;
                    
                    if(rdy_s0 & rdy_s1) begin  
                        if(inp_ch_ptr < chInp-1) begin
                            inp_ch_ptr <= inp_ch_ptr + 1;
                        end else begin
                            inp_ch_ptr <= 0;
                            if(fil_x < fil_width-1) begin
                                fil_x <= fil_x + 1;
                            end else begin
                                fil_x <= 0;
                                if(fil_y < fil_height-1) begin
                                    fil_y <= fil_y + 1;
                                end else begin
                                    fil_y     <= 0;
                                    fsm_state <= AccPost;
                                    calc <= 1'b1;
                                    if(oup_ch_ptr + CHP < chOup) begin  
                                        oup_ch_ptr <= oup_ch_ptr + CHP; 
                                    end else begin
                                        oup_ch_ptr <= 0;
                                        if(oup_a < tile_num-1) begin
                                            oup_a <= oup_a + 1;
                                        end else begin
                                            oup_a <= 0;
                                            fsm_state <= ConvEnd;
                                        end
                                    end // oup_ch_ptr
                                end // fil_y
                            end // fil_x
                        end // inp_ch_ptr
                
                      if(acc_en_r) wei_addr_r <= wei_addr_r + fil_ch_inc;
                
                      ctrl_bias_addr <= oup_ch_ptr;
                      for(int i = 0; i < NPE; i++) begin
                            inp_addr_r[i]  <= inp_addr_xy[i] + signed'((jump_inc * fil_y) + (chStr * fil_x) + ch_ptr);
                
                            if(oup_addr_inc) begin
                                ctrl_oup_addr[i] <= ctrl_oup_addr[i] + (ctrl_oup_en[i]?oup_res+1 : 0);
                                ctrl_oup_en[i]   <= oup_y[i] < oup_height;
                            end
                            valid_r[i]  <= ((inp_xl[i] >= 0) && (inp_xl[i] < inp_width) && (inp_yl[i] >= 0) && (inp_yl[i] < inp_height));
                      end // for
                    end
                end//Acc
                AccPost: begin
                    if(calc && rdy_s0 && rdy_s1) begin
                        if(oup_ch_ptr == 0) begin
                            for(int i = 0; i < NPE; i++) begin
                                if(ctrl_oup_en[i]) begin
                                    if(oup_x[i] == oup_width-1) begin
                                        oup_x[i] <= 'd0;
                                        inp_x[i] <= -pad_width*chStr;
                                        oup_y[i] <= oup_y[i] + 1;
                                        inp_y[i] <= inp_y[i] + str_height*jump_inc;
                                    end else begin
                                        oup_x[i] <= oup_x[i] + 1;
                                        inp_x[i] <= inp_x[i] + str_width*chStr;
                                    end
                                end
                            end
                        end
                    end//calc
                  
                    if(rdy_s0 && rdy_s1) begin
                        ncalc  <= ncalc < 7 ? ncalc + 1 : 'd7;
                        if(rdy_s0) begin
                            acc_en_r <= 1'b0;
                            calc    <= 1'b0;
                        end
                        if(ctrl_acc_valid && ctrl_oup_rdy) begin 
                            ctrl_acc_clr  <= 1'b1;
                            fsm_state     <= Acc;
                            oup_res       <= chOup - oup_ch_ptr > CHP-1 ? CHP-1 : chOup - oup_ch_ptr - 1; 
                            ctrl_oup_res  <= oup_res;
                            oup_addr_inc  <= 1'b1;
                        end
                    end
                end//AccPost
                ConvEnd: begin
                    if(rdy_s0 && rdy_s1) begin
                        if(rdy_s0) begin
                            acc_en_r  <= 1'b0;
                            calc      <= 1'b0;
                        end
                        if(ctrl_acc_valid && ctrl_oup_rdy) begin // output write last 1 data
                            ctrl_acc_clr     <= 1'b1;
                            ctrl_run_r   <= 1'b0;
                            oup_addr_inc <= 1'b1;  
                            fsm_state    <= Idle;
                        end
                    end
                end//ConvEnd
            endcase
        end
    end

endmodule