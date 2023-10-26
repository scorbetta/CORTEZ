`timescale 1ns/100ps

// Returns the absolute value of a fixed-point number
module FIXED_POINT_ABS
#(
    // Input data width
    parameter WIDTH         = 8,
    // Number of fractional bits
    parameter FRAC_BITS     = 3
)
(
    input                       CLK,
    input                       RSTN,
    input signed [WIDTH-1:0]    VALUE_IN,
    input                       VALID_IN,
    output signed [WIDTH-1:0]   VALUE_OUT,
    output                      VALID_OUT
);

    logic signed [WIDTH-1:0]    value_out;
    logic                       valid_out;
    logic                       sign;
    logic signed [WIDTH-1:0]    value_converted;
    logic                       valid_converted;
    logic signed [WIDTH-1:0]    fixed_point_minus_one;

    // As usual, the MSB hints about the negative number
    assign sign = VALUE_IN[WIDTH-1];

    // Special number
    assign fixed_point_minus_one = { {WIDTH-FRAC_BITS{1'b1}}, {FRAC_BITS{1'b0}} };

    // Compute 2's complement conversion
    FIXED_POINT_MUL #(
        .WIDTH      (WIDTH),
        .FRAC_BITS  (FRAC_BITS)
    )
    FIXED_POINT_MUL_0 (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .VALUE_A_IN (VALUE_IN),
        .VALUE_B_IN (fixed_point_minus_one),
        .VALID_IN   (VALID_IN),
        .VALUE_OUT  (value_converted),
        .VALID_OUT  (valid_converted)
    );

    always_ff @(posedge CLK) begin
        if(!RSTN) begin
            valid_out <= 1'b0;
        end
        else begin
            valid_out <= 1'b0;

            if(VALID_IN && !sign) begin
                value_out <= VALUE_IN;
                valid_out <= 1'b1;
            end
            else if(valid_converted && sign) begin
                value_out <= value_converted;
                valid_out <= 1'b1;
            end
        end
    end

    // Pinout
    assign VALUE_OUT    = value_out;
    assign VALID_OUT    = valid_out;
endmodule
