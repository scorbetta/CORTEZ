`default_nettype none

// The top-level neural network module contains designed instances and connections of  LAYER
// modules. This network solves the 5x5 vowel recognition problem using bipolar inputs and outputs,
// similar to the Madaline network does. However, the Madaline's activation function is
// non-differentiable, and the training algorithm is poor. This network, instead, makes use of the
// more general back-propagation algorithm during training; it employs a aiecewise approximation of
// the tanh function
module NETWORK
(
    input wire                      CLK,
    input wire                      RSTN,
    // Input path
    input wire signed [9*8-1:0]     VALUES_IN,
    input wire                      VALID_IN,
    // Hidden layer weights
    input wire signed [6*9*8-1:0]   HL_WEIGHTS_IN,
    input wire signed [6*8-1:0]     HL_BIAS_IN,
    // Output layer weights
    input wire signed [3*6*8-1:0]   OL_WEIGHTS_IN,
    input wire signed [3*8-1:0]     OL_BIAS_IN,
    // Output path
    output wire signed [3*8-1:0]    VALUES_OUT,
    output wire                     VALID_OUT
);

    // Connections
    wire signed [6*8-1:0]   hl_values_out;
    wire [5:0]              hl_valids_out;
    wire signed [6*8-1:0]   ol_values_in;
    wire                    ol_valid_in;
    wire signed [3*8-1:0]   ol_values_out;
    wire [2:0]              ol_valids_out;

    // Hidden layer
    LAYER #(
        .NUM_INPUTS     (9),
        .NUM_OUTPUTS    (6),
        .WIDTH          (8),
        .FRAC_BITS      (5)
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
        .NUM_INPUTS (6),
        .WIDTH      (8)
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
        .NUM_INPUTS     (6),
        .NUM_OUTPUTS    (3),
        .WIDTH          (8),
        .FRAC_BITS      (5)
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
        .NUM_INPUTS (3),
        .WIDTH      (8)
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

`default_nettype wire
