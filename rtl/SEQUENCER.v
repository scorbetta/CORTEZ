`default_nettype none

module SEQUENCER
#(
    parameter NUM_INPUTS    = 4,
    parameter WIDTH         = 8
)
(
    input wire                          CLK,
    input wire                          RSTN,
    input wire [NUM_INPUTS*WIDTH-1:0]   VALUES_IN,
    input wire                          VALID_IN,
    input wire                          TRIGGER,
    output wire [WIDTH-1:0]             VALUE_OUT,
    output wire                         VALID_OUT
);

    localparam IDLE         = 2'b00;
    localparam SEND_DATA    = 2'b01;
    localparam WAIT_TRIGGER = 2'b10;
    reg [1:0]                       curr_state;
    reg                             valid_out;
    reg [NUM_INPUTS*WIDTH-1:0]      new_values;
    wire [$clog2(NUM_INPUTS)-1:0]   data_count;
    reg                             reset_counter;
    wire                            trigger_rise;
    wire                            trigger_fall;
    reg                             trigger_rise_latch;
    reg                             trigger_fall_latch;
    reg                             data_count_en;

    always @(posedge CLK) begin
        if(VALID_IN) begin
            new_values <= VALUES_IN;
        end
    end

    // Latch incoming edges
    EDGE_DETECTOR TRIGGER_EDGE_DETECTOR (
        .CLK            (CLK),
        .RSTN           (RSTN),
        .SAMPLE_IN      (TRIGGER),
        .RISE_EDGE_OUT  (trigger_rise),
        .FALL_EDGE_OUT  (trigger_fall)
    );

    always @(posedge CLK) begin
        if(!RSTN) begin
            trigger_rise_latch <= 1'b0;
        end
        else if(!trigger_rise_latch && trigger_rise) begin
            trigger_rise_latch <= 1'b1;
        end
        else if(trigger_rise_latch && trigger_fall) begin
            trigger_rise_latch <= 1'b0;
        end
    end

    always @(posedge CLK) begin
        if(!RSTN) begin
            trigger_fall_latch <= 1'b0;
        end
        else if(!trigger_fall_latch && trigger_fall) begin
            trigger_fall_latch <= 1'b1;
        end
        else if(trigger_fall_latch && trigger_rise) begin
            trigger_fall_latch <= 1'b0;
        end
    end

    // Sequencer engine
    always @(posedge CLK) begin
        if(!RSTN) begin
            data_count_en <= 1'b0;
            reset_counter <= 1'b0;
            valid_out <= 1'b0;
            curr_state <= IDLE;
        end
        else begin
            data_count_en <= 1'b0;
            reset_counter <= 1'b0;
            valid_out <= 1'b0;

            case(curr_state)
                IDLE : begin
                    if(VALID_IN) begin
                        curr_state <= SEND_DATA;
                    end
                end

                SEND_DATA : begin
                    if(trigger_rise_latch) begin
                        valid_out <= 1'b1;
                        curr_state <= WAIT_TRIGGER;
                    end
                end

                WAIT_TRIGGER : begin
                    if(trigger_fall_latch && data_count < NUM_INPUTS-1) begin
                        data_count_en <= 1'b1;
                        curr_state <= SEND_DATA;
                    end
                    else if(trigger_fall_latch && data_count == NUM_INPUTS-1) begin
                        reset_counter <= 1'b1;
                        curr_state <= IDLE;
                    end
                end

                default : begin
                end
            endcase
        end
    end

    // Data counter
    COUNTER #(
        .WIDTH  ($clog2(NUM_INPUTS))
    )
    DATA_COUNTER (
        .CLK        (CLK),
        .RSTN       (RSTN & ~reset_counter),
        .EN         (data_count_en),
        .VALUE      (data_count),
        .OVERFLOW   () // Unused
    );

    // Pinout
    assign VALID_OUT    = valid_out;
    assign VALUE_OUT    = new_values[data_count*WIDTH +: WIDTH];
endmodule

`default_nettype wire
