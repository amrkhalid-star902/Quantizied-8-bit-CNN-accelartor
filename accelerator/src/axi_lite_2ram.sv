`timescale 1ns / 1ps

module axi_lite_2ram (
    // Clock and Reset
    input  logic        aclk,
    input  logic        aresetn,

    // AXI Lite Write Address Channel
    input  logic        awvalid,
    output logic        awready,
    input  logic [31:0] awaddr,
    input  logic [2:0]  awprot,

    // AXI Lite Write Data Channel
    input  logic        wvalid,
    output logic        wready,
    input  logic [31:0] wdata,
    input  logic [3:0]  wstrb,

    // AXI Lite Write Response Channel
    output logic        bvalid,
    input  logic        bready,
    output logic [1:0]  bresp,

    // AXI Lite Read Address Channel
    input  logic        arvalid,
    output logic        arready,
    input  logic [31:0] araddr,
    input  logic [2:0]  arprot,

    // AXI Lite Read Data Channel
    output logic        rvalid,
    input  logic        rready,
    output logic [31:0] rdata,
    output logic [1:0]  rresp,

    // RAM Interface
    output logic [31:0] cfg_addr,
    output logic [3:0]  cfg_we,
    output logic        cfg_ren,
    output logic [31:0] cfg_wdata,
    input  logic        cfg_rdy,
    input  logic [31:0] cfg_rdata
);

    typedef enum logic [2:0] {
        IDLE,
        WRITE_PROCESSING,
        WRITE_RESPONSE,
        READ_PROCESSING,
        READ_RESPONSE
    } state_t;

    state_t current_state, next_state;

    logic [31:0] write_addr_reg;
    logic [31:0] write_data_reg;
    logic [3:0]  write_strb_reg;
    logic [31:0] read_addr_reg;

    // State register update
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            current_state <= IDLE;
            write_addr_reg <= '0;
            write_data_reg <= '0;
            write_strb_reg <= '0;
            read_addr_reg <= '0;
        end else begin
            current_state <= next_state;

            // Capture write address and data
            if (current_state == IDLE && next_state == WRITE_PROCESSING) begin
                write_addr_reg <= awaddr;
                write_data_reg <= wdata;
                write_strb_reg <= wstrb;
            end

            // Capture read address
            if (current_state == IDLE && next_state == READ_PROCESSING) begin
                read_addr_reg <= araddr;
            end
        end
    end

    // Next state logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (awvalid && wvalid) begin
                    next_state = WRITE_PROCESSING;
                end else if (arvalid) begin
                    next_state = READ_PROCESSING;
                end
            end

            WRITE_PROCESSING: begin
                if (cfg_rdy) begin
                    next_state = WRITE_RESPONSE;
                end
            end

            WRITE_RESPONSE: begin
                if (bready) begin
                    next_state = IDLE;
                end
            end

            READ_PROCESSING: begin
                if (cfg_rdy) begin
                    next_state = READ_RESPONSE;
                end
            end

            READ_RESPONSE: begin
                if (rready) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always_comb begin
        awready = 1'b0;
        wready = 1'b0;
        arready = 1'b0;
        bvalid = 1'b0;
        rvalid = 1'b0;
        bresp = 2'b00;
        rresp = 2'b00;
        cfg_addr = 32'b0;
        cfg_we = 4'b0;
        cfg_ren = 1'b0;
        cfg_wdata = 32'b0;
        rdata = 32'b0;

        case (current_state)
            IDLE: begin
                if (awvalid && wvalid) begin
                    awready = 1'b1;
                    wready = 1'b1;
                end else if (arvalid) begin
                    arready = 1'b1;
                end
            end

            WRITE_PROCESSING: begin
                cfg_addr = write_addr_reg;
                cfg_we = write_strb_reg;
                cfg_wdata = write_data_reg;
            end

            WRITE_RESPONSE: begin
                bvalid = 1'b1;
            end

            READ_PROCESSING: begin
                cfg_addr = read_addr_reg;
                cfg_ren = 1'b1;
            end

            READ_RESPONSE: begin
                rvalid = 1'b1;
                rdata = cfg_rdata;
            end

            default: begin
                // Default outputs
            end
        endcase
    end

endmodule