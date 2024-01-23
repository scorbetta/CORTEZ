`default_nettype none

module SHIM_ALIGN
#(
    parameter NUM_INPUTS    = 1,
    parameter WIDTH         = 8
)
(
    input wire                                  CLK,
    input wire                                  RSTN,
    input wire signed [NUM_INPUTS*WIDTH-1:0]    VALUES_IN,
    input wire [NUM_INPUTS-1:0]                 VALIDS_IN,
    output wire signed [NUM_INPUTS*WIDTH-1:0]   VALUES_OUT,
    output wire                                 VALID_OUT
);

    // States encoding
    localparam BUSY = 0;
    localparam IDLE = 1;

    reg [0:0]                           curr_state;
    reg [NUM_INPUTS-1:0]                valids_in;
    reg signed [NUM_INPUTS*WIDTH-1:0]   values_in;
    reg                                 valid_out;
    reg                                 reset_valids;
    wire                                all_valids;
    genvar                              gdx;

    // Keep sampling incoming valid edges
    generate
        for(gdx = 0; gdx < NUM_INPUTS; gdx = gdx + 1) begin
            always @(posedge CLK) begin
                if(!RSTN) begin
                    valids_in[gdx] <= 1'b0;
                end
                else if(reset_valids) begin
                    valids_in[gdx] <= 1'b0;
                end
                else if(!valids_in[gdx] && VALIDS_IN[gdx]) begin
                    valids_in[gdx] <= VALIDS_IN[gdx];
                    values_in[gdx*WIDTH +: WIDTH] <= VALUES_IN[gdx*WIDTH +: WIDTH];
                end
            end
        end
    endgenerate

    assign all_valids = &valids_in;

    // FSM waits for all valids to be captured, then generates a single-cycle pulse to the
    // downstream logic
    always @(posedge CLK) begin
        if(!RSTN) begin
            reset_valids <= 1'b0;
            valid_out <= 1'b0;
            curr_state <= IDLE;
        end
        else begin
            valid_out <= 1'b0;
            reset_valids <= 1'b0;

            case(curr_state)
                IDLE : begin
                    if(all_valids) begin
                        reset_valids <= 1'b1;
                        valid_out <= 1'b1;
                        curr_state <= BUSY;
                    end
                end

                BUSY : begin
                    curr_state <= IDLE;
                end
            endcase
        end
    end

    // Pinout
    assign VALUES_OUT   = values_in;
    assign VALID_OUT    = valid_out;
endmodule

`default_nettype wire
