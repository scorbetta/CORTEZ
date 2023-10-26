`timescale 1ns/100ps

// A generic layer is a fully-connected layer of neurons
module LAYER #(
    // Number of inputs
    parameter NUM_INPUTS    = 1,
    // Number of outputs
    parameter NUM_OUTPUTS   = 1,
    // Input data width
    parameter WIDTH         = 8,
    // Number of fractional bits
    parameter FRAC_BITS     = 3
)
(
    input                       CLK,
    input                       RSTN,
    // Input path
    input signed [WIDTH-1:0]    VALUES_IN [NUM_INPUTS],
    //input signed [WIDTH-1:0]    WEIGHTS_IN [NUM_OUTPUTS] [NUM_INPUTS],
    input signed [WIDTH-1:0]    WEIGHTS_IN [NUM_OUTPUTS*NUM_INPUTS],
    input signed [WIDTH-1:0]    BIAS_IN [NUM_OUTPUTS],
    input                       VALID_IN,
    // Output path
    output signed [WIDTH-1:0]   VALUES_OUT [NUM_OUTPUTS],
    output [0:0]                VALIDS_OUT [NUM_OUTPUTS]
);

    logic valid_out [NUM_OUTPUTS];

    generate
        for(genvar gdx = 0; gdx < NUM_OUTPUTS; gdx++) begin
            NEURON #(
                .NUM_INPUTS (NUM_INPUTS),
                .WIDTH      (WIDTH),
                .FRAC_BITS  (FRAC_BITS)
            )
            NEURON (
                .CLK        (CLK),
                .RSTN       (RSTN),
                .VALUES_IN  (VALUES_IN),
                //.WEIGHTS_IN (WEIGHTS_IN[gdx]),
                .WEIGHTS_IN (WEIGHTS_IN[gdx*NUM_INPUTS +: NUM_INPUTS]),
                .VALID_IN   (VALID_IN),
                .BIAS_IN    (BIAS_IN[gdx]),
                .VALUE_OUT  (VALUES_OUT[gdx]),
                .VALID_OUT  (VALIDS_OUT[gdx])
            );
        end
    endgenerate
endmodule
