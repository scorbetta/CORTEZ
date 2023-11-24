`timescale 1ns/100ps

// (8,5) fixed point special values
`define FP_ZERO         8'h00
`define FP_PLUS_ONE     8'h20
`define FP_MINUS_ONE    8'he0

// Input characters format over 72 bits
`define INPUT_CHAR_O { `FP_PLUS_ONE, `FP_PLUS_ONE, `FP_PLUS_ONE, `FP_PLUS_ONE, `FP_MINUS_ONE, `FP_PLUS_ONE, `FP_PLUS_ONE, `FP_PLUS_ONE, `FP_PLUS_ONE }
`define INPUT_CHAR_U { `FP_PLUS_ONE, `FP_MINUS_ONE, `FP_PLUS_ONE, `FP_PLUS_ONE, `FP_MINUS_ONE, `FP_PLUS_ONE, `FP_PLUS_ONE, `FP_PLUS_ONE, `FP_PLUS_ONE }
`define INPUT_CHAR_I { `FP_MINUS_ONE, `FP_PLUS_ONE, `FP_MINUS_ONE, `FP_MINUS_ONE, `FP_PLUS_ONE, `FP_MINUS_ONE, `FP_MINUS_ONE, `FP_PLUS_ONE, `FP_MINUS_ONE }

// Output characters format over 27 bits
`define OUTPUT_CHAR_O { `FP_ZERO, `FP_ZERO, `FP_PLUS_ONE }
`define OUTPUT_CHAR_U { `FP_ZERO, `FP_PLUS_ONE, `FP_ZERO }
`define OUTPUT_CHAR_I { `FP_PLUS_ONE, `FP_ZERO, `FP_ZERO }

// 7-segments display chars
`define SS_CHAR_O 7'b1000000
`define SS_CHAR_U 7'b1000001
`define SS_CHAR_I 7'b1001111
`define SS_CHAR_X 7'b0001001

module SS_DECODER
#(
    parameter COUNTER_WIDTH = 24
)
(
    input                                       CLK,
    input                                       RSTN,
    input cortez_regpool_pkg::regpool__out_t    REGPOOL_BUNDLE_OUT,
    input cortez_regpool_pkg::regpool__in_t     REGPOOL_BUNDLE_IN,
    output [3:0]                                SS_ANODES,
    output [7:0]                                SS_SEGMENTS
);

    logic [COUNTER_WIDTH-1:0]   counter;
    logic                       overflow;
    logic [3:0]                 ss_anodes;
    logic [6:0]                 ss_segments;
    logic [6:0]                 ss_inputs;
    logic [6:0]                 ss_outputs;
    logic                       ss_dot;
    logic [9*8-1:0]             all_inputs;
    logic [3*8-1:0]             all_outputs;

    // Pre-scaler
    always @(posedge CLK) begin
        if(!RSTN) begin
            counter <= 0;
            overflow <= 1'b0;
        end
        else begin
            { overflow, counter } <= counter + 1;
        end
    end

    // Twiggle 7-segments anodes around
    always_ff @(posedge CLK) begin
        if(!RSTN) begin
            ss_anodes <= 4'b1111;
            ss_segments <= 7'b1111111;
            ss_dot <= 1'b1;
        end
        else if(overflow) begin
            case(ss_anodes)
                4'b1111 : begin
                    ss_anodes <= 4'b0111;
                    ss_segments <= ss_inputs;
                end

                4'b0111 : begin
                    ss_anodes <= 4'b1011;
                    ss_segments <= ss_outputs;
                end

                4'b1011 : begin
                    ss_anodes <= 4'b0111;
                    ss_segments <= ss_inputs;
                end
            endcase
        end
    end

    // Decode inputs to 7-segments display
    assign all_inputs = {
        REGPOOL_BUNDLE_OUT.INPUT_GRID_7.data.value,
        REGPOOL_BUNDLE_OUT.INPUT_GRID_6.data.value,
        REGPOOL_BUNDLE_OUT.INPUT_GRID_5.data.value,
        REGPOOL_BUNDLE_OUT.INPUT_GRID_4.data.value,
        REGPOOL_BUNDLE_OUT.INPUT_GRID_3.data.value,
        REGPOOL_BUNDLE_OUT.INPUT_GRID_2.data.value,
        REGPOOL_BUNDLE_OUT.INPUT_GRID_1.data.value,
        REGPOOL_BUNDLE_OUT.INPUT_GRID_0.data.value
    };

    always_ff @(posedge CLK) begin
        if(!RSTN) begin
            ss_inputs <= 7'b1111111;
        end
        else begin
            case(all_inputs)
                `INPUT_CHAR_O : begin
                    ss_inputs <= `SS_CHAR_O;
                end

                `INPUT_CHAR_U : begin
                    ss_inputs <= `SS_CHAR_U;
                end

                `INPUT_CHAR_I : begin
                    ss_inputs <= `SS_CHAR_I;
                end

                default : begin
                    ss_inputs <= `SS_CHAR_X;
                end
            endcase
        end
    end

    // Decode outputs to 7-segments display
    assign all_outputs = {
        REGPOOL_BUNDLE_IN.OUTPUT_SOLUTION_2.data.next & 8'hf0,
        REGPOOL_BUNDLE_IN.OUTPUT_SOLUTION_1.data.next & 8'hf0,
        REGPOOL_BUNDLE_IN.OUTPUT_SOLUTION_0.data.next & 8'hf0
    };

    always_ff @(posedge CLK) begin
        if(!RSTN) begin
            ss_outputs <= 7'b1111111;
        end
        else begin
            case(all_outputs)
                `OUTPUT_CHAR_O : begin
                    ss_outputs <= `SS_CHAR_O;
                end

                `OUTPUT_CHAR_U : begin
                    ss_outputs <= `SS_CHAR_U;
                end

                `OUTPUT_CHAR_I : begin
                    ss_outputs <= `SS_CHAR_I;
                end

                default : begin
                    ss_outputs <= `SS_CHAR_X;
                end
            endcase
        end
    end

    // Pinout
    assign SS_ANODES    = ss_anodes;
    assign SS_SEGMENTS  = { ss_dot, ss_segments };
endmodule
