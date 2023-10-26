`timescale 1ns/100ps

// Fixed-point comparator
module FIXED_POINT_COMP
#(
    // Input data width
    parameter WIDTH         = 8,
    // Number of fractional bits
    parameter FRAC_BITS     = 3
)
(
    input signed [WIDTH-1:0]    VALUE_A_IN,
    input signed [WIDTH-1:0]    VALUE_B_IN,
    // Outputs are relative to ordered  VALUE_A_IN op VALUE_B_IN  
    output                      GT,
    output                      EQ,
    output                      LT
);

    // To save space, derive the third operation
    logic gt;
    logic eq;
    logic lt;

    assign gt = ( VALUE_A_IN > VALUE_B_IN ? 1'b1 : 1'b0 );
    assign eq = ( VALUE_A_IN == VALUE_B_IN ? 1'b1 : 1'b0 );
    assign lt = ~gt & ~eq;

    // Pinout
    assign GT = gt;
    assign EQ = eq;
    assign LT = lt;
endmodule