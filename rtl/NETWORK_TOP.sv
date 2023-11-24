`timescale 1ns/100ps

`include "NETWORK_CONFIG.svh"
`include "CORTEZ_REGPOOL.svh"

import cortez_regpool_pkg::*;

module NETWORK_TOP
(
    input           CLK,
    input           RSTN,
    // AXI interface
    axi4l_if.slave  AXI4L_PORT,
    // Output device control
    output [3:0]    SS_ANODES,
    output [7:0]    SS_SEGMENTS,
    output [7:0]    LEDS
);

    // Internal connections
    cortez_regpool_pkg::regpool__in_t           regpool_bundle_in;
    cortez_regpool_pkg::regpool__out_t          regpool_bundle_out;
    logic signed [`FIXED_POINT_WORD_WIDTH-1:0]  values_in [`NUM_INPUTS];
    logic                                       valid_in;
    logic signed [`FIXED_POINT_WORD_WIDTH-1:0]  hl_weights_in [`NUM_HL_NODES*`NUM_INPUTS];
    logic signed [`FIXED_POINT_WORD_WIDTH-1:0]  hl_bias_in [`NUM_HL_NODES];
    logic signed [`FIXED_POINT_WORD_WIDTH-1:0]  ol_weights_in [`NUM_OL_NODES*`NUM_HL_NODES];
    logic signed [`FIXED_POINT_WORD_WIDTH-1:0]  ol_bias_in [`NUM_OL_NODES];
    logic signed [`FIXED_POINT_WORD_WIDTH-1:0]  values_out [`NUM_OL_NODES];
    logic                                       valid_out;
    logic [3:0]                                 kit_swing;
    logic                                       reset_asserted;
    logic                                       config_done;
    logic                                       input_valid;
    logic                                       output_ready;

    // CSR block
    CORTEZ_REGPOOL CSR (
        .ACLK       (CLK),
        .ARESETN    (RSTN),
        .AXIL       (AXI4L_PORT),
        .hwif_in    (regpool_bundle_in),
        .hwif_out   (regpool_bundle_out)
    );

    // Unpack CSR bundle
    `include "CSR_BUNDLE_WIRES.svh"

    // The network
    NETWORK NETWORK (
        .CLK            (CLK),
        .RSTN           (RSTN),
        .VALUES_IN      (values_in),
        .VALID_IN       (valid_in),
        .HL_WEIGHTS_IN  (hl_weights_in),
        .HL_BIAS_IN     (hl_bias_in),
        .OL_WEIGHTS_IN  (ol_weights_in),
        .OL_BIAS_IN     (ol_bias_in),
        .VALUES_OUT     (values_out),
        .VALID_OUT      (valid_out)
    );

    // Decode solution to 7-segments display
    SS_DECODER SS_DECODER (
        .CLK                (CLK),
        .RSTN               (RSTN),
        .REGPOOL_BUNDLE_OUT (regpool_bundle_out),
        .REGPOOL_BUNDLE_IN  (regpool_bundle_in),
        .SS_ANODES          (SS_ANODES),
        .SS_SEGMENTS        (SS_SEGMENTS)
    );

    // Kit-like swinger
    LEDS_SWINGER #(
        .COUNTER_WIDTH  (24)
    )
    LEDS_SWINGER (
        .CLK    (CLK),
        .RSTN   (RSTN),
        .DATA   (kit_swing)
    );

    // Compose other LEDs bits
    assign config_done      = regpool_bundle_out.CORE_CTRL.CFG_DONE.value;
    assign input_valid      = regpool_bundle_out.CORE_CTRL.LOAD_IN.value;
    assign output_ready     = regpool_bundle_in.CORE_STATUS.VALID_OUT.next;
    assign reset_asserted   = !RSTN;

    // Pinout
    assign LEDS = {
        kit_swing,      //@[7:4]
        output_ready,   //@[3]
        input_valid,    //@[2]
        config_done,    //@[1]
        reset_asserted  //@[0]
    };
endmodule
