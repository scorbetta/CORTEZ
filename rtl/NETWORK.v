`default_nettype none

// The top-level neural network module contains designed instances and connections of  LAYER
// modules. This network solves the 5x5 vowel recognition problem using bipolar inputs and outputs,
// similar to the Madaline network does. However, the Madaline's activation function is
// non-differentiable, and the training algorithm is poor. This network, instead, makes use of the
// more general back-propagation algorithm during training; it employs a aiecewise approximation of
// the tanh function
module NETWORK
#(
    // Fixed-point width
    parameter FP_WIDTH      = 8,
    // Fixed-point fractional bits
    parameter FP_FRAC       = 5,
    // Number of inputs
    parameter NUM_INPUTS    = 9,
    // Number of neurons in the hidden layer
    parameter HL_NEURONS    = 6,
    // Number of neurons in the output layer
    parameter OL_NEURONS    = 3
)
(
    input wire                                      CLK,
    input wire                                      RSTN,
    // Serial interface
    input wire [HL_NEURONS+OL_NEURONS-1:0]          SCI_CSN,
    input wire                                      SCI_REQ,
    inout wire                                      SCI_RESP,
    inout wire                                      SCI_ACK,
    // Input path
    input wire signed [NUM_INPUTS*FP_WIDTH-1:0]     VALUES_IN,
    input wire                                      VALID_IN,
    // Output path
    output wire signed [OL_NEURONS*FP_WIDTH-1:0]    VALUES_OUT,
    output wire                                     VALID_OUT,
    output wire                                     OVERFLOW
);

    // Connections
    wire signed [HL_NEURONS*FP_WIDTH-1:0]   hl_values_out;
    wire [HL_NEURONS-1:0]                   hl_valids_out;
    wire signed [OL_NEURONS*FP_WIDTH-1:0]   ol_values_out;
    wire [OL_NEURONS-1:0]                   ol_valids_out;
    wire                                    hl_overflow;
    wire                                    ol_overflow;
    wire [FP_WIDTH-1:0]                     hl_value_in;
    wire                                    hl_valid_in;
    wire [FP_WIDTH-1:0]                     ol_value_in;
    wire                                    ol_valid_in;
    wire                                    hl_ready;
    wire                                    ol_ready;
    wire signed [HL_NEURONS*FP_WIDTH-1:0]   hl_aligned_values_out;
    wire                                    hl_aligned_valid_out;

    // Hidden layer sequencer
    SEQUENCER #(
        .NUM_INPUTS (NUM_INPUTS),
        .WIDTH      (FP_WIDTH)
    )
    HL_SEQUENCER (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .VALUES_IN  (VALUES_IN),
        .VALID_IN   (VALID_IN),
        .TRIGGER    (hl_ready),
        .VALUE_OUT  (hl_value_in),
        .VALID_OUT  (hl_valid_in)
    );

    // Hidden layer
    HIDDEN_LAYER #(
        .NUM_INPUTS     (NUM_INPUTS),
        .NUM_OUTPUTS    (HL_NEURONS),
        .WIDTH          (FP_WIDTH),
        .FRAC_BITS      (FP_FRAC)
    )
    HIDDEN_LAYER (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .SCI_CSN    (SCI_CSN[HL_NEURONS-1:0]),
        .SCI_REQ    (SCI_REQ),
        .SCI_RESP   (SCI_RESP),
        .SCI_ACK    (SCI_ACK),
        .READY      (hl_ready),
        .VALUE_IN   (hl_value_in),
        .VALID_IN   (hl_valid_in),
        .VALUES_OUT (hl_values_out),
        .VALIDS_OUT (hl_valids_out),
        .OVERFLOW   (hl_overflow)
    );

    // By design, neurons might fire at different times. This logic barriers all incoming valids,
    // re-samples the intermediate values and generate a single pulse for the output layer
    SHIM_ALIGN #(
        .NUM_INPUTS (HL_NEURONS),
        .WIDTH      (FP_WIDTH)
    )
    HL_ALIGNMENT_BARRIER (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .VALUES_IN  (hl_values_out),
        .VALIDS_IN  (hl_valids_out),
        .VALUES_OUT (hl_aligned_values_out),
        .VALID_OUT  (hl_aligned_valid_out)
    );

    // Output layer sequencer
    SEQUENCER #(
        .NUM_INPUTS (HL_NEURONS),
        .WIDTH      (FP_WIDTH)
    )
    OL_SEQUENCER (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .VALUES_IN  (hl_aligned_values_out),
        .VALID_IN   (hl_aligned_valid_out),
        .TRIGGER    (ol_ready),
        .VALUE_OUT  (ol_value_in),
        .VALID_OUT  (ol_valid_in)
    );

    // Output layer
    OUTPUT_LAYER #(
        .NUM_INPUTS     (HL_NEURONS),
        .NUM_OUTPUTS    (OL_NEURONS),
        .WIDTH          (FP_WIDTH),
        .FRAC_BITS      (FP_FRAC)
    )
    OUTPUT_LAYER (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .SCI_CSN    (SCI_CSN[HL_NEURONS +: OL_NEURONS]),
        .SCI_REQ    (SCI_REQ),
        .SCI_RESP   (SCI_RESP),
        .SCI_ACK    (SCI_ACK),
        .READY      (ol_ready),
        .VALUE_IN   (ol_value_in),
        .VALID_IN   (ol_valid_in),
        .VALUES_OUT (ol_values_out),
        .VALIDS_OUT (ol_valids_out),
        .OVERFLOW   (ol_overflow)
    );

    SHIM_ALIGN #(
        .NUM_INPUTS (OL_NEURONS),
        .WIDTH      (FP_WIDTH)
    )
    OL_ALIGNMENT_BARRIER (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .VALUES_IN  (ol_values_out),
        .VALIDS_IN  (ol_valids_out),
        .VALUES_OUT (VALUES_OUT),
        .VALID_OUT  (VALID_OUT)
    );

    // Pinout
    assign OVERFLOW = hl_overflow | ol_overflow;
endmodule

`default_nettype wire
