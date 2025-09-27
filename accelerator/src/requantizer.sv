`timescale 1ns/1ns

`include "data_types.svh"

module requantizer(
    input  logic    clk,
    input  logic    resetn,
    input  logic    valid_in,     
    input  int32_t  acc_in,       
    input  int9_t   out_offs,     
    input  uint32_t quant,        
    output int8_t   accd,         
    output logic    valid_out     
);

    // Extract quantization parameters
    int18_t  out_mult;
    uint8_t  out_shift;
    assign out_mult  = quant[31:15];
    assign out_shift = quant[7:0];

    // Pipeline stage 1 registers
    int32_t  acc_reg1;
    int9_t   out_offs_reg1;
    uint8_t  out_shift_reg1;
    uint32_t mask_reg1;
    uint32_t th_reg1;
    logic    valid_reg1;

    // Pipeline stage 2 registers
    int32_t  xx_reg2;
    int9_t   out_offs_reg2;
    uint8_t  out_shift_reg2;
    uint32_t mask_reg2;
    uint32_t th_reg2;
    logic    valid_reg2;

    // Combinational logic for stage 1
    uint32_t mask_stage1, th_stage1;
    assign mask_stage1 = (1 << out_shift) - 1;
    assign th_stage1 = (mask_stage1 >> 1) + (acc_in < 0);

    // Pipeline Stage 1: Capture inputs and compute multiplication
    always@(posedge clk) begin
        if(!resetn) begin
            valid_reg1     <= 1'b0;
            acc_reg1       <= 32'd0;
            out_offs_reg1  <= 9'd0;
            out_shift_reg1 <= 8'd0;
            mask_reg1      <= 32'd0;
            th_reg1        <= 32'd0;
        end else begin
            valid_reg1 <= valid_in;
            if(valid_in) begin
                acc_reg1       <= acc_in;
                out_offs_reg1  <= out_offs;
                out_shift_reg1 <= out_shift;
                mask_reg1      <= mask_stage1;
                th_reg1        <= th_stage1;
            end
        end
    end

    // Pipeline Stage 2: Multiplication and preparation for final stage
    always@(posedge clk) begin
        if(!resetn) begin
            valid_reg2     <= 1'b0;
            xx_reg2        <= 32'd0;
            out_offs_reg2  <= 9'd0;
            out_shift_reg2 <= 8'd0;
            mask_reg2      <= 32'd0;
            th_reg2        <= 32'd0;
        end else begin
            valid_reg2 <= valid_reg1;
            if(valid_reg1) begin
                xx_reg2        <= int32_t'(int48_t'(acc_reg1 * out_mult) >>> 16);
                out_offs_reg2  <= out_offs_reg1;
                out_shift_reg2 <= out_shift_reg1;
                mask_reg2      <= mask_reg1;
                th_reg2        <= th_reg1;
            end
        end
    end

    // Pipeline Stage 3: Final quantization and clamping
    uint32_t rem;
    int32_t  accm, accm_r;
    logic    valid_reg3;
    assign rem = xx_reg2 & mask_reg2;
    assign accm = signed'(((xx_reg2 >>> out_shift_reg2) + out_offs_reg2) + ((rem > th_reg2) ? 1 : 0));
    
    always@(posedge clk) begin
        if(!resetn) begin
            valid_reg3 <= 1'b0;
            accm_r     <= 8'd0;
        end else begin
            valid_reg3 <= valid_reg2;
            accm_r     <= accm;
        end
    end

    always@(posedge clk) begin
        if(!resetn) begin
            valid_out <= 1'b0;
            accd      <= 8'd0;
        end else begin
            valid_out <= valid_reg3;
            if(valid_reg3) begin
                accd <= accm_r < -128 ? -128 : accm_r > 127 ? 127 : accm_r[7:0];
            end
        end
    end

endmodule