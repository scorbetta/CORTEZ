`timescale 1ns/100ps

// A neuron consists of a configurable number of inputs and a single output
module NEURON #(
    // Number of inputs
    parameter NUM_INPUTS    = 1,
    // Input data width
    parameter WIDTH         = 8,
    // Number of fractional bits
    parameter FRAC_BITS     = 3
)
(
    input                       CLK,
    input                       RSTN,
    // Inputs are all asserted at the same time
    input signed [WIDTH-1:0]    VALUES_IN [NUM_INPUTS],
    input signed [WIDTH-1:0]    WEIGHTS_IN [NUM_INPUTS],
    input signed [WIDTH-1:0]    BIAS_IN,
    input                       VALID_IN,
    // Output path
    output signed [WIDTH-1:0]   VALUE_OUT,
    output                      VALID_OUT
);

    logic signed [WIDTH-1:0]    mul_result [NUM_INPUTS];
    logic signed                mul_valid [NUM_INPUTS];
    logic                       all_mul_valid;
    logic signed [WIDTH-1:0]    acc_result;
    logic                       acc_valid;
    logic signed [WIDTH-1:0]    acc_bias_in [2];

    // Parallel multipliers
    generate
        for(genvar gdx = 0; gdx < NUM_INPUTS; gdx++) begin
            FIXED_POINT_MUL #(
                .WIDTH      (WIDTH),
                .FRAC_BITS  (FRAC_BITS)
            )
            FP_MUL (
                .CLK        (CLK),
                .RSTN       (RSTN),
                .VALUE_A_IN (VALUES_IN[gdx]),
                .VALUE_B_IN (WEIGHTS_IN[gdx]),
                .VALID_IN   (VALID_IN),
                .VALUE_OUT  (mul_result[gdx]),
                .VALID_OUT  (mul_valid[gdx])
            );
        end
    endgenerate

    // Warning: Neither ICARUS nor VERILATOR do support streaming operators, but the design is such
    // that  mul_valid[*]  get asserted simultaneously
    assign all_mul_valid = mul_valid[0];

    // Accumulation engine
    FIXED_POINT_ACC #(
        .WIDTH          (WIDTH),
        .FRAC_BITS      (FRAC_BITS),
        .NUM_INPUTS     (NUM_INPUTS),
        .HAS_EXT_BIAS   (1'b1)
    )
    FP_ACC (
        .CLK            (CLK),
        .RSTN           (RSTN),
        .VALUES_IN      (mul_result),
        .VALID_IN       (all_mul_valid),
        .EXT_VALUE_IN   (BIAS_IN),
        .VALUE_OUT      (acc_result),
        .VALID_OUT      (acc_valid)
    );

    // Non-linear activation function
    FIXED_POINT_ACT_FUN #(
        .WIDTH      (WIDTH),
        .FRAC_BITS  (FRAC_BITS)
    )
    FP_ACT (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .VALUE_IN   (acc_result),
        .VALID_IN   (acc_valid),
        .VALUE_OUT  (VALUE_OUT),
        .VALID_OUT  (VALID_OUT)
    );
endmodule
