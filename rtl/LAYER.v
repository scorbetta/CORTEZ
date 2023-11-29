`default_nettype none

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
    input wire                                              CLK,
    input wire                                              RSTN,
    // Input path
    input wire signed [NUM_INPUTS*WIDTH-1:0]                VALUES_IN,
    input wire signed [NUM_OUTPUTS*NUM_INPUTS*WIDTH-1:0]    WEIGHTS_IN,
    input wire signed [NUM_OUTPUTS*WIDTH-1:0]               BIAS_IN,
    input wire                                              VALID_IN,
    // Output path
    output wire signed [NUM_OUTPUTS*WIDTH-1:0]              VALUES_OUT,
    output wire [NUM_OUTPUTS-1:0]                           VALIDS_OUT
);

    genvar gdx;

    generate
        for(gdx = 0; gdx < NUM_OUTPUTS; gdx = gdx + 1) begin
            NEURON #(
                .NUM_INPUTS (NUM_INPUTS),
                .WIDTH      (WIDTH),
                .FRAC_BITS  (FRAC_BITS)
            )
            NEURON (
                .CLK        (CLK),
                .RSTN       (RSTN),
                .VALUES_IN  (VALUES_IN),
                .WEIGHTS_IN (WEIGHTS_IN[gdx*NUM_INPUTS*WIDTH +: NUM_INPUTS*WIDTH]),
                .VALID_IN   (VALID_IN),
                .BIAS_IN    (BIAS_IN[gdx*WIDTH +: WIDTH]),
                .VALUE_OUT  (VALUES_OUT[gdx*WIDTH +: WIDTH]),
                .VALID_OUT  (VALIDS_OUT[gdx])
            );
        end
    endgenerate
endmodule

`default_nettype wire
