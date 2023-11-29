`default_nettype none

module LEDS_SWINGER
#(
    parameter COUNTER_WIDTH = 24
)
(
    input wire          CLK,
    input wire          RSTN,
    output wire [3:0]   DATA
);

    reg [3:0]               data;
    reg [COUNTER_WIDTH-1:0] counter;
    reg                     overflow;
    reg                     lnr;

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

    always @(posedge CLK) begin
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

`default_nettype wire
