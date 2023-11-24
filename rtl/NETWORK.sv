`timescale 1ns/100ps

`include "NETWORK_CONFIG.svh"

// The top-level neural network module contains designed instances and connections of  LAYER
// modules. This network solves the 5x5 vowel recognition problem using bipolar inputs and outputs,
// similar to the Madaline network does. However, the Madaline's activation function is
// non-differentiable, and the training algorithm is poor. This network, instead, makes use of the
// more general back-propagation algorithm during training; it employs a aiecewise approximation of
// the tanh function
module NETWORK
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

    // Connections
    logic signed [`FIXED_POINT_WORD_WIDTH-1:0]  hl_values_out [`NUM_HL_NODES];
    logic                                       hl_valids_out [`NUM_HL_NODES];
    logic signed [`FIXED_POINT_WORD_WIDTH-1:0]  ol_values_in [`NUM_HL_NODES];
    logic                                       ol_valid_in;
    logic signed [`FIXED_POINT_WORD_WIDTH-1:0]  ol_values_out [`NUM_OL_NODES];
    logic                                       ol_valids_out [`NUM_OL_NODES];

    // Hidden layer
    LAYER #(
        .NUM_INPUTS     (`NUM_INPUTS),
        .NUM_OUTPUTS    (`NUM_HL_NODES),
        .WIDTH          (`FIXED_POINT_WORD_WIDTH),
        .FRAC_BITS      (`FIXED_POINT_FRAC_BITS)
    )
    HIDDEN_LAYER (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .VALUES_IN  (VALUES_IN),
        .WEIGHTS_IN (HL_WEIGHTS_IN),
        .BIAS_IN    (HL_BIAS_IN),
        .VALID_IN   (VALID_IN),
        .VALUES_OUT (hl_values_out),
        .VALIDS_OUT (hl_valids_out)
    );

    // By design, neurons might fire at different times. This logic barriers all incoming valids,
    // re-samples the intermediate values and generate a single pulse for the output layer
    SHIM_ALIGN #(
        .NUM_INPUTS (`NUM_HL_NODES),
        .WIDTH      (`FIXED_POINT_WORD_WIDTH)
    )
    HL_OL_ALIGNMENT_BARRIER (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .VALUES_IN  (hl_values_out),
        .VALIDS_IN  (hl_valids_out),
        .VALUES_OUT (ol_values_in),
        .VALID_OUT  (ol_valid_in)
    );

    // Output layer
    LAYER #(
        .NUM_INPUTS     (`NUM_HL_NODES),
        .NUM_OUTPUTS    (`NUM_OL_NODES),
        .WIDTH          (`FIXED_POINT_WORD_WIDTH),
        .FRAC_BITS      (`FIXED_POINT_FRAC_BITS)
    )
    OUTPUT_LAYER (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .VALUES_IN  (ol_values_in),
        .WEIGHTS_IN (OL_WEIGHTS_IN),
        .BIAS_IN    (OL_BIAS_IN),
        .VALID_IN   (ol_valid_in),
        .VALUES_OUT (ol_values_out),
        .VALIDS_OUT (ol_valids_out)
    );

    SHIM_ALIGN #(
        .NUM_INPUTS (`NUM_OL_NODES),
        .WIDTH      (`FIXED_POINT_WORD_WIDTH)
    )
    OL_OUTPUT_ALIGNMENT_BARRIER (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .VALUES_IN  (ol_values_out),
        .VALIDS_IN  (ol_valids_out),
        .VALUES_OUT (VALUES_OUT),
        .VALID_OUT  (VALID_OUT)
    );
endmodule
