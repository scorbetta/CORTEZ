`timescale 1ns/100ps

module SHIM_ALIGN
#(
    parameter NUM_INPUTS    = 1,
    parameter WIDTH         = 8
)
(
    input                       CLK,
    input                       RSTN,
    input signed [WIDTH-1:0]    VALUES_IN [NUM_INPUTS],
    input                       VALIDS_IN [NUM_INPUTS],
    output signed [WIDTH-1:0]   VALUES_OUT [NUM_INPUTS],
    output                      VALID_OUT
);

    typedef enum { BUSY, IDLE } state_t;
    state_t                     curr_state;
    logic [NUM_INPUTS-1:0]      valids_in;
    logic signed [WIDTH-1:0]    values_in [NUM_INPUTS];
    logic                       valid_out;
    logic                       reset_valids;
    logic                       all_valids;

    // Keep sampling incoming valid edges
    generate
        for(genvar gdx = 0; gdx < NUM_INPUTS; gdx++) begin
            always_ff @(posedge CLK) begin
                if(!RSTN || reset_valids) begin
                    valids_in[gdx] <= 1'b0;
                end
                else if(!valids_in[gdx] && VALIDS_IN[gdx]) begin
                    valids_in[gdx] <= VALIDS_IN[gdx];
                    values_in[gdx] <= VALUES_IN[gdx];
                end
            end
        end
    endgenerate

    assign all_valids = &valids_in;

    // FSM waits for all valids to be captured, then generates a single-cycle pulse to the
    // downstream logic
    always_ff @(posedge CLK) begin
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
