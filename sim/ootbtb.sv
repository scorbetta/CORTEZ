`timescale 1ns/100ps

// Import network configuration
`include "NETWORK_CONFIG.svh"

// For printout
`define SCALING (2.0**-`FIXED_POINT_FRAC_BITS)

module ootbtb;
    logic                                       clk;
    logic                                       rstn;
    logic signed [`FIXED_POINT_WORD_WIDTH-1:0]  values_in [`NUM_INPUTS];
    logic signed [`FIXED_POINT_WORD_WIDTH-1:0]  hl_weights [`NUM_HL_NODES*`NUM_INPUTS];
    logic signed [`FIXED_POINT_WORD_WIDTH-1:0]  ol_weights [`NUM_OL_NODES*`NUM_HL_NODES];
    logic signed [`FIXED_POINT_WORD_WIDTH-1:0]  hl_bias [`NUM_HL_NODES];
    logic signed [`FIXED_POINT_WORD_WIDTH-1:0]  ol_bias [`NUM_OL_NODES];
    logic                                       valid_in;
    logic signed [`FIXED_POINT_WORD_WIDTH-1:0]  values_out [`NUM_OL_NODES];
    logic                                       valid_out;

    // Clock and reset
    initial begin
        clk = 1'b0;
        forever begin
            #2.0 clk = ~clk;
        end
    end

    initial begin
        rstn <= 1'b0;
        repeat(10) @(posedge clk);
        rstn <= 1'b1;
    end

    // DUT
    NETWORK DUT (
        .CLK            (clk),
        .RSTN           (rstn),
        .VALUES_IN      (values_in),
        .VALID_IN       (valid_in),
        .HL_WEIGHTS_IN  (hl_weights),
        .HL_BIAS_IN     (hl_bias),
        .OL_WEIGHTS_IN  (ol_weights),
        .OL_BIAS_IN     (ol_bias),
        .VALUES_OUT     (values_out),
        .VALID_OUT      (valid_out)
    );

    // Random weights
    initial begin
        for(int ndx = 0; ndx < `NUM_HL_NODES; ndx++) begin
            for(int idx = 0; idx < `NUM_INPUTS; idx++) begin
                hl_weights[ndx*`NUM_INPUTS+idx] = $random % 2;
            end
        end

        for(int ndx = 0; ndx < `NUM_OL_NODES; ndx++) begin
            for(int idx = 0; idx < `NUM_HL_NODES; idx++) begin
                ol_weights[ndx*`NUM_HL_NODES+idx] = $random % 2;
            end
        end
    end

    // Random bias
    initial begin
        for(int ndx = 0; ndx < `NUM_HL_NODES; ndx++) begin
            hl_bias[ndx] = $random % 2;
        end

        for(int ndx = 0; ndx < `NUM_OL_NODES; ndx++) begin
            ol_bias[ndx] = $random % 2;
        end
    end

    initial begin
        valid_in <= 1'b0;
        @(posedge rstn);
        repeat(1e1) @(posedge clk);

        @(posedge clk);
        valid_in <= 1'b1;
        for(int idx = 0; idx < `NUM_INPUTS; idx++) begin
            values_in[idx] <= $random;
        end

        @(posedge clk);
        valid_in <= 1'b0;

        repeat(1e2) @(posedge clk);
        $finish;
   end

   initial begin
       $dumpfile("ootbtb.vcd");
       $dumpvars(0, ootbtb);
   end
endmodule
