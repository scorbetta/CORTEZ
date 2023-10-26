`timescale 1ns/100ps

`include "NETWORK_CONFIG.svh"

module NETWORK_TOP
(
    input                                       CLK,
    input                                       RSTN,
    // Input path
    input signed [`FIXED_POINT_WORD_WIDTH-1:0]  VALUES_IN [`NUM_INPUTS],
    input                                       VALID_IN,
    // Hidden layer weights
    input signed [`FIXED_POINT_WORD_WIDTH-1:0]  HL_WEIGHTS_IN [`NUM_HL_NODES*`NUM_INPUTS],
    input signed [`FIXED_POINT_WORD_WIDTH-1:0]  HL_BIAS_IN [`NUM_HL_NODES],
    // Output layer weights
    input signed [`FIXED_POINT_WORD_WIDTH-1:0]  OL_WEIGHTS_IN [`NUM_OL_NODES*`NUM_HL_NODES],
    input signed [`FIXED_POINT_WORD_WIDTH-1:0]  OL_BIAS_IN [`NUM_OL_NODES],
    // Output path
    output signed [`FIXED_POINT_WORD_WIDTH-1:0] VALUES_OUT [`NUM_OL_NODES],
    output                                      VALID_OUT
);

    NETWORK NETWORK (
        .CLK            (CLK),
        .RSTN           (RSTN),
        .VALUES_IN      (VALUES_IN),
        .VALID_IN       (VALID_IN),
        .HL_WEIGHTS_IN  (HL_WEIGHTS_IN),
        .HL_BIAS_IN     (HL_BIAS_IN),
        .OL_WEIGHTS_IN  (OL_WEIGHTS_IN),
        .OL_BIAS_IN     (OL_BIAS_IN),
        .VALUES_OUT     (VALUES_OUT),
        .VALID_OUT      (VALID_OUT)
    );
endmodule
