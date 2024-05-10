`default_nettype none

// A generic layer is a fully-connected layer of neurons
module HIDDEN_LAYER #(
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
    input wire [NUM_OUTPUTS-1:0]                SCI_CSN,
    input wire                                  SCI_REQ,
    inout wire                                  SCI_RESP,
    inout wire                                  SCI_ACK,
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
    wire [NUM_OUTPUTS-1:0]  sci_resps;
    wire [NUM_OUTPUTS-1:0]  sci_acks;

    generate
        for(gdx = 0; gdx < NUM_OUTPUTS; gdx = gdx + 1) begin
            HL_NEURON #(
                .NUM_INPUTS (NUM_INPUTS),
                .WIDTH      (WIDTH),
                .FRAC_BITS  (FRAC_BITS)
            )
            NEURON (
                .CLK        (CLK),
                .RSTN       (RSTN),
                .SCI_CSN    (SCI_CSN[gdx]),
                .SCI_REQ    (SCI_REQ),
                .SCI_RESP   (sci_resps[gdx]),
                .SCI_ACK    (sci_acks[gdx]),
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

    // Tri-stated  RESP/ACK  bus
    `include "sci_resp_z.v"
    `include "sci_ack_z.v"

    // Pinout
    assign READY        = &readies;
    assign VALIDS_OUT   = valids_out;
    assign OVERFLOW     = |overflow;
endmodule

`default_nettype wire
