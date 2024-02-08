`default_nettype none

// A generic layer is a fully-connected layer of neurons
module OUTPUT_LAYER #(
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
    input wire                                  CLK,
    input wire                                  RSTN,
    // Serial interface
    input wire [NUM_OUTPUTS-1:0]                CSN,
    input wire                                  SIN,
    output wire [NUM_OUTPUTS-1:0]               SOUT,
    output wire [NUM_OUTPUTS-1:0]               SACK,
    // Input path
    output wire                                 READY,
    input wire signed [WIDTH-1:0]               VALUE_IN,
    input wire                                  VALID_IN,
    // Output path
    output wire signed [NUM_OUTPUTS*WIDTH-1:0]  VALUES_OUT,
    output wire [NUM_OUTPUTS-1:0]               VALIDS_OUT,
    output wire                                 OVERFLOW
);

    wire [NUM_OUTPUTS-1:0]  overflow;
    genvar                  gdx;
    wire [NUM_OUTPUTS-1:0]  readies;
    wire [NUM_OUTPUTS-1:0]  valids_out;
    wire                    all_valids;

    generate
        for(gdx = 0; gdx < NUM_OUTPUTS; gdx = gdx + 1) begin
            OL_NEURON #(
                .NUM_INPUTS (NUM_INPUTS),
                .WIDTH      (WIDTH),
                .FRAC_BITS  (FRAC_BITS)
            )
            NEURON (
                .CLK        (CLK),
                .RSTN       (RSTN),
                .CSN        (CSN[gdx]),
                .SIN        (SIN),
                .SOUT       (SOUT[gdx]),
                .SACK       (SACK[gdx]),
                .READY      (readies[gdx]),
                .VALUE_IN   (VALUE_IN),
                .VALID_IN   (VALID_IN),
                .VALUE_OUT  (VALUES_OUT[gdx*WIDTH +: WIDTH]),
                .VALID_OUT  (valids_out[gdx]),
                .OVERFLOW   (overflow[gdx])
            );
        end
    endgenerate

    assign all_valids = &valids_out;

    // Pinout
    assign READY        = &readies;
    assign VALIDS_OUT   = valids_out;
    assign OVERFLOW     = |overflow;
endmodule

`default_nettype wire
