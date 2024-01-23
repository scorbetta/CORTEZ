`default_nettype none

`include "CORTEZ_REGPOOL.vh"

module NETWORK_TOP
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
    wire signed [25*8-1:0]   values_in;
    wire signed [10*25*8-1:0] hl_weights;
    wire signed [10*8-1:0]   hl_bias;
    wire signed [5*10*8-1:0] ol_weights;
    wire signed [5*8-1:0]   ol_bias;
    wire signed [5*8-1:0]  values_out;
    wire                    valid_in;
    wire                    valid_out;
    wire [3:0]              kit_swing;
    wire                    reset_asserted;
    wire                    config_done;
    wire                    input_valid;
    wire                    output_ready;
    wire [7:0]              core_ctrl;
    wire [7:0]              core_debug_info;
    wire                    reset_start;
    wire                    reset_end;
    wire                    config_start;
    wire                    config_end;
    wire                    test_start;
    wire                    test_end;
    wire                    test_err;
    wire [7:0]              core_status;
    wire [4*8-1:0]          sevensegs;
    wire [31:0]             awaddr;
    wire [2:0]              awprot;
    wire                    awvalid;
    wire                    awready;
    wire [7:0]              wdata;
    wire                    wstrb;
    wire                    wvalid;
    wire                    wready;
    wire [1:0]              bresp;
    wire                    bvalid;
    wire                    bready;
    wire [31:0]             araddr;
    wire [2:0]              arprot;
    wire                    arvalid;
    wire                    arready;
    wire [7:0]              rdata;
    wire [1:0]              rresp;
    wire                    rvalid;
    wire                    rready;
    wire                    rstn;
    reg [3:0]               ss_anodes;
    reg [7:0]               ss_segments;
    reg [23:0]              ss_counter;
    reg                     ss_overflow;
    wire                    network_overflow;

    // Internal modules use active-low reset as well
    assign rstn = ~RST;

    // Wishbone-to-AXI4 Lite bridge
    WB2AXI4LITE_BRIDGE #(
        .ADDR_WIDTH     (32),
        .DATA_WIDTH     (8),
        .AXI_BASE_ADDR  (32'h3000_0000)
    )
    WB2AXI_BRIDGE (
        .CLK            (CLK),
        .RSTN           (rstn),
        .RST            (RST),
        .WB_CYC         (CYC),
        .WB_STB         (STB),
        .WB_WE          (WE),
        .WB_ADDR        (ADDR),
        .WB_WDATA       (WDATA),
        .WB_SEL         (SEL),
        .WB_STALL       (STALL),
        .WB_ACK         (ACK),
        .WB_RDATA       (RDATA),
        .WB_ERR         (ERR),
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

    // CSR block
    CORTEZ_REGPOOL CSR (
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
        .HWIF_OUT_HL_WEIGHTS_0      (hl_weights[0*25*8 +: 25*8]),
        .HWIF_OUT_HL_WEIGHTS_1      (hl_weights[1*25*8 +: 25*8]),
        .HWIF_OUT_HL_WEIGHTS_2      (hl_weights[2*25*8 +: 25*8]),
        .HWIF_OUT_HL_WEIGHTS_3      (hl_weights[3*25*8 +: 25*8]),
        .HWIF_OUT_HL_WEIGHTS_4      (hl_weights[4*25*8 +: 25*8]),
        .HWIF_OUT_HL_WEIGHTS_5      (hl_weights[5*25*8 +: 25*8]),
        .HWIF_OUT_HL_WEIGHTS_6      (hl_weights[6*25*8 +: 25*8]),
        .HWIF_OUT_HL_WEIGHTS_7      (hl_weights[7*25*8 +: 25*8]),
        .HWIF_OUT_HL_WEIGHTS_8      (hl_weights[8*25*8 +: 25*8]),
        .HWIF_OUT_HL_WEIGHTS_9      (hl_weights[9*25*8 +: 25*8]),
        .HWIF_OUT_HL_BIAS_0         (hl_bias[0*8 +: 8]),
        .HWIF_OUT_HL_BIAS_1         (hl_bias[1*8 +: 8]),
        .HWIF_OUT_HL_BIAS_2         (hl_bias[2*8 +: 8]),
        .HWIF_OUT_HL_BIAS_3         (hl_bias[3*8 +: 8]),
        .HWIF_OUT_HL_BIAS_4         (hl_bias[4*8 +: 8]),
        .HWIF_OUT_HL_BIAS_5         (hl_bias[5*8 +: 8]),
        .HWIF_OUT_HL_BIAS_6         (hl_bias[6*8 +: 8]),
        .HWIF_OUT_HL_BIAS_7         (hl_bias[7*8 +: 8]),
        .HWIF_OUT_HL_BIAS_8         (hl_bias[8*8 +: 8]),
        .HWIF_OUT_HL_BIAS_9         (hl_bias[9*8 +: 8]),
        .HWIF_OUT_OL_WEIGHTS_0      (ol_weights[0*10*8 +: 10*8]),
        .HWIF_OUT_OL_WEIGHTS_1      (ol_weights[1*10*8 +: 10*8]),
        .HWIF_OUT_OL_WEIGHTS_2      (ol_weights[2*10*8 +: 10*8]),
        .HWIF_OUT_OL_WEIGHTS_3      (ol_weights[3*10*8 +: 10*8]),
        .HWIF_OUT_OL_WEIGHTS_4      (ol_weights[4*10*8 +: 10*8]),
        .HWIF_OUT_OL_BIAS_0         (ol_bias[0*8 +: 8]),
        .HWIF_OUT_OL_BIAS_1         (ol_bias[1*8 +: 8]),
        .HWIF_OUT_OL_BIAS_2         (ol_bias[2*8 +: 8]),
        .HWIF_OUT_OL_BIAS_3         (ol_bias[3*8 +: 8]),
        .HWIF_OUT_OL_BIAS_4         (ol_bias[4*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_0      (values_in[0*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_1      (values_in[1*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_2      (values_in[2*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_3      (values_in[3*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_4      (values_in[4*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_5      (values_in[5*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_6      (values_in[6*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_7      (values_in[7*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_8      (values_in[8*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_9      (values_in[9*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_10      (values_in[10*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_11      (values_in[11*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_12      (values_in[12*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_13      (values_in[13*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_14      (values_in[14*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_15      (values_in[15*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_16      (values_in[16*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_17      (values_in[17*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_18      (values_in[18*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_19      (values_in[19*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_20      (values_in[20*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_21      (values_in[21*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_22      (values_in[22*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_23      (values_in[23*8 +: 8]),
        .HWIF_OUT_INPUT_GRID_24      (values_in[24*8 +: 8]),
        .HWIF_IN_OUTPUT_SOLUTION_0  (values_out[0*8 +: 8]),
        .HWIF_IN_OUTPUT_SOLUTION_1  (values_out[1*8 +: 8]),
        .HWIF_IN_OUTPUT_SOLUTION_2  (values_out[2*8 +: 8]),
        .HWIF_IN_OUTPUT_SOLUTION_3  (values_out[3*8 +: 8]),
        .HWIF_IN_OUTPUT_SOLUTION_4  (values_out[4*8 +: 8]),
        .HWIF_OUT_CORE_CTRL         (core_ctrl),
        .HWIF_OUT_CORE_DEBUG_INFO   (core_debug_info),
        .HWIF_IN_CORE_STATUS        (core_status),
        .HWIF_OUT_SEVENSEG_0        (sevensegs[0*8 +: 8]),
        .HWIF_OUT_SEVENSEG_1        (sevensegs[1*8 +: 8]),
        .HWIF_OUT_SEVENSEG_2        (sevensegs[2*8 +: 8]),
        .HWIF_OUT_SEVENSEG_3        (sevensegs[3*8 +: 8])
    );

    // Generate pulse from  LOAD_IN  field
    EDGE_DETECTOR LOAD_IN_EDGE_DETECTOR (
        .CLK            (CLK),
        .RSTN           (rstn),
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

    // The network
    NETWORK #(
        .FP_WIDTH   (8),
        .FP_FRAC    (5),
        .NUM_INPUTS (25),
        .HL_NEURONS (10),
        .OL_NEURONS (5)
    )
    NETWORK (
        .CLK            (CLK),
        .RSTN           (rstn),
        .VALUES_IN      (values_in),
        .VALID_IN       (valid_in),
        .HL_WEIGHTS_IN  (hl_weights),
        .HL_BIAS_IN     (hl_bias),
        .OL_WEIGHTS_IN  (ol_weights),
        .OL_BIAS_IN     (ol_bias),
        .VALUES_OUT     (values_out),
        .VALID_OUT      (valid_out),
        .OVERFLOW       (network_overflow)
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
