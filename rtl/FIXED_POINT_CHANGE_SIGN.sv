`timescale 1ns/100ps

// Changes the sign of the incoming value to the target one. This can be used in different contexts,
// e.g. to share ALUs for odd-symmetric functions
module FIXED_POINT_CHANGE_SIGN
#(
    // Input data width
    parameter WIDTH         = 8,
    // Number of fractional bits
    parameter FRAC_BITS     = 3
)
(
    input                       CLK,
    input                       RSTN,
    // 1'b0 -> we want positive, 1'b1 -> we want negative
    input                       TARGET_SIGN,
    input signed [WIDTH-1:0]    VALUE_IN,
    input                       VALID_IN,
    output signed [WIDTH-1:0]   VALUE_OUT,
    output                      VALID_OUT
);

    logic signed [WIDTH-1:0]    value_out;
    logic                       valid_out;
    logic                       sign;
    logic                       sign_match;
    logic signed [WIDTH-1:0]    value_converted;
    logic                       valid_converted;
    logic signed [WIDTH-1:0]    fixed_point_minus_one;
    logic                       valid_in_filtered;

    // As usual, the MSB hints about the negative number
    assign sign = VALUE_IN[WIDTH-1];

    // Special number
    assign fixed_point_minus_one = { {WIDTH-FRAC_BITS{1'b1}}, {FRAC_BITS{1'b0}} };

    // Multiplication run only when required, this also simplifies mux later
    assign valid_in_filtered = VALID_IN & ~sign_match;

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
        .VALID_IN   (valid_in_filtered),
        .VALUE_OUT  (value_converted),
        .VALID_OUT  (valid_converted)
    );

    // When sign of incoming value already matches the desired one, discard all computations
    assign sign_match = (sign & TARGET_SIGN) | (!sign & !TARGET_SIGN);

    always_ff @(posedge CLK) begin
        if(!RSTN) begin
            valid_out <= 1'b0;
        end
        else begin
            valid_out <= 1'b0;

            if(VALID_IN && sign_match) begin
                value_out <= VALUE_IN;
                valid_out <= 1'b1;
            end
            else if(valid_converted) begin
                value_out <= value_converted;
                valid_out <= 1'b1;
            end
        end
    end

    // Pinout
    assign VALUE_OUT    = value_out;
    assign VALID_OUT    = valid_out;
endmodule
