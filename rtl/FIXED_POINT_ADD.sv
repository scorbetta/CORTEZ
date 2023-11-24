`timescale 1ns/100ps

// Fixed-point adder
module FIXED_POINT_ADD
#(
    // The width of the input values
    parameter WIDTH     = 8,
    // Number of bits reserved to the fractional part. Also, the position of the binary point from
    // LSB. Must be strictly positive
    parameter FRAC_BITS = 3
)
(
    input                       CLK,
    input                       RSTN,
    // Input operand
    input signed [WIDTH-1:0]    VALUE_A_IN,
    input signed [WIDTH-1:0]    VALUE_B_IN,
    input                       VALID_IN,
    // Accumulator
    output signed [WIDTH-1:0]   VALUE_OUT,
    output                      VALID_OUT
);

    logic signed [WIDTH-1:0]    value_out;
    logic                       valid_out;

    always_ff @(posedge CLK) begin
        if(!RSTN) begin
            valid_out <= 1'b0;
            value_out <= 0;
        end
        else begin
            valid_out <= 1'b0;

            if(VALID_IN) begin
                value_out <= VALUE_A_IN + VALUE_B_IN;
                valid_out <= 1'b1;
            end
        end
    end

    // Pinout
    assign VALUE_OUT    = value_out;
    assign VALID_OUT    = valid_out;
endmodule
