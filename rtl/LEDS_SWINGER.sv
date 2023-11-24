`timescale 1ns/100ps

module LEDS_SWINGER
#(
    parameter COUNTER_WIDTH = 24
)
(
    input           CLK,
    input           RSTN,
    output [3:0]    DATA
);

    logic [3:0]                 data;
    logic [COUNTER_WIDTH-1:0]   counter;
    logic                       overflow;
    logic                       lnr;

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

    always_ff @(posedge CLK) begin
        if(!RSTN) begin
            data <= 4'b1100;
            lnr <= 1'b1;
        end
        else if(overflow) begin
            case(data)
                4'b1100 : begin
                    data <= 4'b1001;
                end

                4'b1001 : begin
                    lnr <= ~lnr;
                    if(lnr) begin
                        data <= 4'b0011;
                    end
                    else begin
                        data <= 4'b1100;
                    end
                end

                4'b0011 : begin
                    data <= 4'b1001;
                end 
            endcase
        end
    end

    // Pinout
    assign DATA = data;
endmodule
