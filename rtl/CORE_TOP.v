`default_nettype none

`include "CORE_REGFILE.vh"

// Global configuration
`define INPUT_SIZE      16
`define HL_NEURONS      8
`define OL_NEURONS      5
`define AXI_BASE_ADDR   32'h3000_0000
`define FP_WIDTH        8
`define FP_FRAC         5

// Top-level Core for Caravel harness
module CORE_TOP
(
    input wire          CLK,
    input wire          RST,
    input wire          CYC,
    input wire          STB,
    input wire          WE,
    input wire [31:0]   ADDR,
    input wire [7:0]    WDATA,
    input wire          SEL,
    output wire         STALL,
    output wire         ACK,
    output wire [7:0]   RDATA,
    output wire         ERR,
    output wire [3:0]   SS_ANODES,
    output wire [7:0]   SS_SEGMENTS,
    output wire [7:0]   LEDS
);

    // Internal connections
    wire signed [`INPUT_SIZE*8-1:0]     values_in;
    wire signed [`OL_NEURONS*8-1:0]     values_out;
    wire                                valid_in;
    wire                                valid_out;
    wire [3:0]                          kit_swing;
    wire                                reset_asserted;
    wire                                config_done;
    wire                                input_valid;
    wire                                output_ready;
    wire [7:0]                          core_ctrl;
    wire [7:0]                          core_debug_info;
    wire                                reset_start;
    wire                                reset_end;
    wire                                config_start;
    wire                                config_end;
    wire                                test_start;
    wire                                test_end;
    wire                                test_err;
    wire [7:0]                          core_status;
    wire [4*8-1:0]                      sevensegs;
    wire [31:0]                         awaddr;
    wire [2:0]                          awprot;
    wire                                awvalid;
    wire                                awready;
    wire [7:0]                          wdata;
    wire                                wstrb;
    wire                                wvalid;
    wire                                wready;
    wire [1:0]                          bresp;
    wire                                bvalid;
    wire                                bready;
    wire [31:0]                         araddr;
    wire [2:0]                          arprot;
    wire                                arvalid;
    wire                                arready;
    wire [7:0]                          rdata;
    wire [1:0]                          rresp;
    wire                                rvalid;
    wire                                rready;
    wire                                rstn;
    reg [3:0]                           ss_anodes;
    reg [7:0]                           ss_segments;
    reg [23:0]                          ss_counter;
    reg                                 ss_overflow;
    wire [`OL_NEURONS+`HL_NEURONS-1:0]  sci_csn;
    wire                                sci_req;
    wire                                sci_resp;
    wire                                sci_ack;
    wire                                wb2axi_cyc;
    wire                                wb2axi_stb;
    wire                                wb2axi_we;
    wire [31:0]                         wb2axi_addr;
    wire [7:0]                          wb2axi_wdata;
    wire [0:0]                          wb2axi_sel;
    wire                                wb2axi_stall;
    wire                                wb2axi_ack;
    wire [7:0]                          wb2axi_rdata;
    wire                                wb2axi_err;
    wire                                wb2sci_cyc;
    wire                                wb2sci_stb;
    wire                                wb2sci_we;
    wire [31:0]                         wb2sci_addr;
    wire [7:0]                          wb2sci_wdata;
    wire [0:0]                          wb2sci_sel;
    wire                                wb2sci_stall;
    wire                                wb2sci_ack;
    wire [7:0]                          wb2sci_rdata;
    wire                                wb2sci_err;

    // Internal modules use active-low reset as well
    assign rstn = ~RST;

    // Simple Wishbone interconnect for 1x Master and 2x Slaves
    WBXBAR WBXBAR (
        .CLK        (CLK),
        .RSTN       (rstn),
        // Slave interface
        .WBM_CYC    (CYC),
        .WBM_STB    (STB),
        .WBM_WE     (WE),
        .WBM_ADDR   (ADDR),
        .WBM_WDATA  (WDATA),
        .WBM_SEL    (SEL),
        .WBM_STALL  (STALL),
        .WBM_ACK    (ACK),
        .WBM_RDATA  (RDATA),
        .WBM_ERR    (ERR),
        // Master interfaces
        .WBS0_CYC   (wb2axi_cyc),
        .WBS0_STB   (wb2axi_stb),
        .WBS0_WE    (wb2axi_we),
        .WBS0_ADDR  (wb2axi_addr),
        .WBS0_WDATA (wb2axi_wdata),
        .WBS0_SEL   (wb2axi_sel),
        .WBS0_STALL (wb2axi_stall),
        .WBS0_ACK   (wb2axi_ack),
        .WBS0_RDATA (wb2axi_rdata),
        .WBS0_ERR   (wb2axi_err),
        .WBS1_CYC   (wb2sci_cyc),
        .WBS1_STB   (wb2sci_stb),
        .WBS1_WE    (wb2sci_we),
        .WBS1_ADDR  (wb2sci_addr),
        .WBS1_WDATA (wb2sci_wdata),
        .WBS1_SEL   (wb2sci_sel),
        .WBS1_STALL (wb2sci_stall),
        .WBS1_ACK   (wb2sci_ack),
        .WBS1_RDATA (wb2sci_rdata),
        .WBS1_ERR   (wb2sci_err)
    );

    // Wishbone-to-AXI4 Lite bridge
    WB2AXI4LITE_BRIDGE #(
        .ADDR_WIDTH     (32),
        .DATA_WIDTH     (8),
        .AXI_BASE_ADDR  (`AXI_BASE_ADDR)
    )
    WB2AXI_BRIDGE (
        .CLK            (CLK),
        .RSTN           (rstn),
        .RST            (RST),
        .WB_CYC         (wb2axi_cyc),
        .WB_STB         (wb2axi_stb),
        .WB_WE          (wb2axi_we),
        .WB_ADDR        (wb2axi_addr),
        .WB_WDATA       (wb2axi_wdata),
        .WB_SEL         (wb2axi_sel),
        .WB_STALL       (wb2axi_stall),
        .WB_ACK         (wb2axi_ack),
        .WB_RDATA       (wb2axi_rdata),
        .WB_ERR         (wb2axi_err),
        .AXI_AWADDR     (awaddr),
        .AXI_AWPROT     (awprot),
        .AXI_AWVALID    (awvalid),
        .AXI_AWREADY    (awready),
        .AXI_WDATA      (wdata),
        .AXI_WSTRB      (wstrb),
        .AXI_WVALID     (wvalid),
        .AXI_WREADY     (wready),
        .AXI_BRESP      (bresp),
        .AXI_BVALID     (bvalid),
        .AXI_BREADY     (bready),
        .AXI_ARADDR     (araddr),
        .AXI_ARPROT     (arprot),
        .AXI_ARVALID    (arvalid),
        .AXI_ARREADY    (arready),
        .AXI_RDATA      (rdata),
        .AXI_RRESP      (rresp),
        .AXI_RVALID     (rvalid),
        .AXI_RREADY     (rready)
    );

    // Core-level regpool
    CORE_REGFILE CORE_REGFILE (
        .ACLK                       (CLK),
        .ARESETN                    (rstn),
        .AWADDR                     (awaddr),
        .AWPROT                     (awprot),
        .AWVALID                    (awvalid),
        .AWREADY                    (awready),
        .WDATA                      (wdata),
        .WSTRB                      (wstrb),
        .WVALID                     (wvalid),
        .WREADY                     (wready),
        .BRESP                      (bresp),
        .BVALID                     (bvalid),
        .BREADY                     (bready),
        .ARADDR                     (araddr),
        .ARPROT                     (arprot),
        .ARVALID                    (arvalid),
        .ARREADY                    (arready),
        .RDATA                      (rdata),
        .RRESP                      (rresp),
        .RVALID                     (rvalid),
        .RREADY                     (rready),
        .HWIF_OUT_DBUG_REG_0        (), // Unused
        .HWIF_OUT_DBUG_REG_1        (), //
        .HWIF_OUT_DBUG_REG_2        (), //
        .HWIF_OUT_DBUG_REG_3        (), //
        .HWIF_OUT_INPUT_GRID_0      (values_in[0*8+:8]),
        .HWIF_OUT_INPUT_GRID_1      (values_in[1*8+:8]),
        .HWIF_OUT_INPUT_GRID_2      (values_in[2*8+:8]),
        .HWIF_OUT_INPUT_GRID_3      (values_in[3*8+:8]),
        .HWIF_OUT_INPUT_GRID_4      (values_in[4*8+:8]),
        .HWIF_OUT_INPUT_GRID_5      (values_in[5*8+:8]),
        .HWIF_OUT_INPUT_GRID_6      (values_in[6*8+:8]),
        .HWIF_OUT_INPUT_GRID_7      (values_in[7*8+:8]),
        .HWIF_OUT_INPUT_GRID_8      (values_in[8*8+:8]),
        .HWIF_OUT_INPUT_GRID_9      (values_in[9*8+:8]),
        .HWIF_OUT_INPUT_GRID_10     (values_in[10*8+:8]),
        .HWIF_OUT_INPUT_GRID_11     (values_in[11*8+:8]),
        .HWIF_OUT_INPUT_GRID_12     (values_in[12*8+:8]),
        .HWIF_OUT_INPUT_GRID_13     (values_in[13*8+:8]),
        .HWIF_OUT_INPUT_GRID_14     (values_in[14*8+:8]),
        .HWIF_OUT_INPUT_GRID_15     (values_in[15*8+:8]),
        .HWIF_IN_OUTPUT_SOLUTION_0  (values_out[0*8+:8]),
        .HWIF_IN_OUTPUT_SOLUTION_1  (values_out[1*8+:8]),
        .HWIF_IN_OUTPUT_SOLUTION_2  (values_out[2*8+:8]),
        .HWIF_IN_OUTPUT_SOLUTION_3  (values_out[3*8+:8]),
        .HWIF_IN_OUTPUT_SOLUTION_4  (values_out[4*8+:8]),
        .HWIF_OUT_CORE_CTRL         (core_ctrl),
        .HWIF_OUT_CORE_DEBUG_INFO   (core_debug_info),
        .HWIF_IN_CORE_STATUS        (core_status),
        .HWIF_OUT_SEVENSEG_0        (sevensegs[0*8+:8]),
        .HWIF_OUT_SEVENSEG_1        (sevensegs[1*8+:8]),
        .HWIF_OUT_SEVENSEG_2        (sevensegs[2*8+:8]),
        .HWIF_OUT_SEVENSEG_3        (sevensegs[3*8+:8])
    );

    // Generate pulse from  LOAD_IN  field
    EDGE_DETECTOR LOAD_IN_EDGE_DETECTOR (
        .CLK            (CLK),
        .SAMPLE_IN      (core_ctrl[1]),
        .RISE_EDGE_OUT  (valid_in),
        .FALL_EDGE_OUT  () // Unused
    );

    // Latch the solution strobe
    DELTA_REG #(
        .DATA_WIDTH (1),
        .HAS_RESET  (1)
    )
    VALID_SOLUTION_LATCH (
        .CLK            (CLK),
        .RSTN           (rstn),
        .READ_EVENT     (core_ctrl[0]),
        .VALUE_IN       (valid_out),
        .VALUE_CHANGE   (core_status[0]),
        .VALUE_OUT      () // Unused
    );

    assign core_status[7:1] = 7'b0000000;

    // Wishbone-to-SCI bridge
    WB2SCI_BRIDGE #(
        .ADDR_WIDTH     (32),
        .DATA_WIDTH     (8),
        .NUM_HL_NEURONS (`HL_NEURONS),
        .NUM_OL_NEURONS (`OL_NEURONS),
        .HL_ADDR_WIDTH  (5),
        .OL_ADDR_WIDTH  (4)
    )
    WB2SCI_BRIDGE (
        .CLK        (CLK),
        .RSTN       (rstn),
        .RST        (RST),
        .WB_CYC     (wb2sci_cyc),
        .WB_STB     (wb2sci_stb),
        .WB_WE      (wb2sci_we),
        .WB_ADDR    (wb2sci_addr),
        .WB_WDATA   (wb2sci_wdata),
        .WB_SEL     (wb2sci_sel),
        .WB_STALL   (wb2sci_stall),
        .WB_ACK     (wb2sci_ack),
        .WB_RDATA   (wb2sci_rdata),
        .WB_ERR     (wb2sci_err),
        .SCI_CSN    (sci_csn),
        .SCI_REQ    (sci_req),
        .SCI_RESP   (sci_resp),
        .SCI_ACK    (sci_ack)
    );

    // The network
    NETWORK #(
        .FP_WIDTH   (`FP_WIDTH),
        .FP_FRAC    (`FP_FRAC),
        .NUM_INPUTS (`INPUT_SIZE),
        .HL_NEURONS (`HL_NEURONS),
        .OL_NEURONS (`OL_NEURONS)
    )
    NETWORK (
        .CLK        (CLK),
        .RSTN       (rstn),
        .SCI_CSN    (sci_csn),
        .SCI_REQ    (sci_req),
        .SCI_RESP   (sci_resp),
        .SCI_ACK    (sci_ack),
        .VALUES_IN  (values_in),
        .VALID_IN   (valid_in),
        .VALUES_OUT (values_out),
        .VALID_OUT  (valid_out),
        .OVERFLOW   () // Unused
    );

    // LEDs control engines
    LEDS_SWINGER #(
        .COUNTER_WIDTH  (24)
    )
    LEDS_SWINGER (
        .CLK    (CLK),
        .RSTN   (rstn),
        .DATA   (kit_swing)
    );

    assign config_done      = core_ctrl[2];
    assign input_valid      = core_ctrl[1];
    assign output_ready     = core_status[0];
    assign reset_asserted   = !rstn | RST;

    assign LEDS = {
        kit_swing,      //@[7:4]
        output_ready,   //@[3]
        input_valid,    //@[2]
        config_done,    //@[1]
        reset_asserted  //@[0]
    };

    // Core debug information
    assign { test_err, test_end, test_start, config_end, config_start, reset_end, reset_start } = core_debug_info[6:0];

    // 7-segments display control engines
    always @(posedge CLK) begin
        if(!rstn) begin
            ss_counter <= 24'd0;
            ss_overflow <= 1'b0;
        end
        else begin
            { ss_overflow, ss_counter } <= ss_counter + 1;
        end
    end

    always @(posedge CLK) begin
        if(!rstn) begin
            ss_anodes <= 4'hf;
            ss_segments <= 8'hff;
        end
        else if(ss_overflow) begin
            case(ss_anodes)
                4'b1110 : begin
                    ss_anodes <= 4'b1101;
                    ss_segments <= sevensegs[1*8 +: 8];
                end

                4'b1101 : begin
                    ss_anodes <= 4'b1011;
                    ss_segments <= sevensegs[2*8 +: 8];
                end

                4'b1011 : begin
                    ss_anodes <= 4'b0111;
                    ss_segments <= sevensegs[3*8 +: 8];
                end

                4'b0111 : begin
                    ss_anodes <= 4'b1110;
                    ss_segments <= sevensegs[0*8 +: 8];
                end

                default : begin
                    ss_anodes <= 4'b1110;
                    ss_segments <= sevensegs[0*8 +: 8];
                end
            endcase
        end
    end

    assign SS_ANODES    = ss_anodes;
    assign SS_SEGMENTS  = ss_segments;   
endmodule

`default_nettype wire
