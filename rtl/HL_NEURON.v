`default_nettype none

// A neuron consists of a configurable number of inputs and a single output
module HL_NEURON #(
    // Number of inputs
    parameter NUM_INPUTS    = 1,
    // Input data width
    parameter WIDTH         = 8,
    // Number of fractional bits
    parameter FRAC_BITS     = 3
)
(
    input wire                      CLK,
    input wire                      RSTN,
    // CSI interface
    input wire                      SCI_CSN,
    input wire                      SCI_REQ,
    output wire                     SCI_RESP,
    output wire                     SCI_ACK,
    // Inputs are all asserted at the same time
    output wire                     READY,
    input wire signed [WIDTH-1:0]   VALUE_IN,
    input wire                      VALID_IN,
    // Output path
    output wire signed [WIDTH-1:0]  VALUE_OUT,
    output wire                     VALID_OUT,
    output wire                     OVERFLOW
);

    wire                                mul_overflow;
    wire                                add_overflow;
    wire                                act_overflow;
    wire                                bias_add_overflow;
    reg                                 overflow;
    genvar                              gdx;
    wire [NUM_INPUTS*WIDTH-1:0]         weights;
    wire [WIDTH-1:0]                    bias;
    wire                                regpool_wreq;
    wire [5:0]                          regpool_waddr;
    wire [7:0]                          regpool_wdata;
    wire                                regpool_wack;
    wire                                regpool_rreq;
    wire [5:0]                          regpool_raddr;
    wire [7:0]                          regpool_rdata;
    wire                                regpool_rvalid;
    wire                                mul_start;
    wire signed [WIDTH-1:0]             mul_value_a_in;
    wire signed [WIDTH-1:0]             mul_value_b_in;
    wire signed [WIDTH-1:0]             mul_value_out;
    wire                                mul_done;
    wire signed [WIDTH-1:0]             acc_in;
    wire signed [WIDTH-1:0]             acc_out;
    wire                                acc_mux;
    wire                                add_done;
    wire                                act_done;
    wire                                bias_add_start;
    wire                                bias_add_done;
    wire signed [WIDTH-1:0]             biased_acc_out;
    wire                                busy;

    // Local registers
    SCI_SLAVE #(
        .ADDR_WIDTH (6), // 36+1 registers
        .DATA_WIDTH (8)
    )
    SCI_SLAVE (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .SCI_CSN    (SCI_CSN),
        .SCI_REQ    (SCI_REQ),
        .SCI_RESP   (SCI_RESP),
        .SCI_ACK    (SCI_ACK),
        .NI_WREQ    (regpool_wreq),
        .NI_WADDR   (regpool_waddr),
        .NI_WDATA   (regpool_wdata),
        .NI_WACK    (regpool_wack),
        .NI_RREQ    (regpool_rreq),
        .NI_RADDR   (regpool_raddr),
        .NI_RDATA   (regpool_rdata),
        .NI_RVALID  (regpool_rvalid)
    );

    HL_NEURON_REGFILE REGFILE (
        .CLK                (CLK),
        .RSTN               (RSTN),
        .WREQ               (regpool_wreq),
        .WADDR              (regpool_waddr),
        .WDATA              (regpool_wdata),
        .WACK               (regpool_wack),
        .RREQ               (regpool_rreq),
        .RADDR              (regpool_raddr),
        .RDATA              (regpool_rdata),
        .RVALID             (regpool_rvalid),
        .HWIF_OUT_WEIGHT_0  (weights[0*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_1  (weights[1*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_2  (weights[2*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_3  (weights[3*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_4  (weights[4*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_5  (weights[5*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_6  (weights[6*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_7  (weights[7*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_8  (weights[8*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_9  (weights[9*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_10 (weights[10*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_11 (weights[11*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_12 (weights[12*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_13 (weights[13*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_14 (weights[14*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_15 (weights[15*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_16 (weights[16*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_17 (weights[17*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_18 (weights[18*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_19 (weights[19*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_20 (weights[20*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_21 (weights[21*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_22 (weights[22*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_23 (weights[23*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_24 (weights[24*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_25 (weights[25*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_26 (weights[26*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_27 (weights[27*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_28 (weights[28*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_29 (weights[29*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_30 (weights[30*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_31 (weights[31*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_32 (weights[32*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_33 (weights[33*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_34 (weights[34*WIDTH+:WIDTH]),
        .HWIF_OUT_WEIGHT_35 (weights[35*WIDTH+:WIDTH]),
        .HWIF_OUT_BIAS      (bias)
    );

    // Multiplier
    FIXED_POINT_MUL #(
        .WIDTH      (WIDTH),
        .FRAC_BITS  (FRAC_BITS)
    )
    FP_MUL (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .VALUE_A_IN (mul_value_a_in),
        .VALUE_B_IN (mul_value_b_in),
        .VALID_IN   (mul_start),
        .VALUE_OUT  (mul_value_out),
        .VALID_OUT  (mul_done),
        .OVERFLOW   (mul_overflow)
    );

    // Accumulator (adder engine)
    assign acc_in = ( acc_mux ? acc_out : {WIDTH{1'b0}} );

    FIXED_POINT_ADD #(
        .WIDTH  (WIDTH)
    )
    FP_ADD (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .VALUE_A_IN (acc_in),
        .VALUE_B_IN (mul_value_out),
        .VALID_IN   (mul_done),
        .VALUE_OUT  (acc_out),
        .VALID_OUT  (add_done),
        .OVERFLOW   (add_overflow)
    );

    // Bias
    FIXED_POINT_ADD #(
        .WIDTH  (WIDTH)
    )
    FP_BIAS (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .VALUE_A_IN (acc_out),
        .VALUE_B_IN (bias),
        .VALID_IN   (bias_add_start),
        .VALUE_OUT  (biased_acc_out),
        .VALID_OUT  (bias_add_done),
        .OVERFLOW   (bias_add_overflow)
    );

    // Non-linear activation function
    FIXED_POINT_ACT_FUN #(
        .WIDTH      (WIDTH),
        .FRAC_BITS  (FRAC_BITS)
    )
    FP_ACT (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .VALUE_IN   (biased_acc_out),
        .VALID_IN   (bias_add_done),
        .VALUE_OUT  (VALUE_OUT),
        .VALID_OUT  (act_done),
        .OVERFLOW   (act_overflow)
    );

    // Control engine
    NEURON_CONTROL_ENGINE #(
        .WIDTH      (WIDTH),
        .NUM_INPUTS (NUM_INPUTS)
    )
    NCE (
        .CLK            (CLK),
        .RSTN           (RSTN),
        .VALUE_IN       (VALUE_IN),
        .VALID_IN       (VALID_IN),
        .WEIGHTS        (weights),
        .MUL_START      (mul_start),
        .MUL_VALUE_A_IN (mul_value_a_in),
        .MUL_VALUE_B_IN (mul_value_b_in),
        .ACC_MUX        (acc_mux),
        .ADD_DONE       (add_done),
        .BIAS_ADD_START (bias_add_start),
        .ACT_DONE       (act_done),
        .BUSY           (busy)
    );

    // Overflow is sticky
    always @(posedge CLK) begin
        if(!RSTN || VALID_IN) begin
            overflow <= 1'b0;
        end
        else begin
            overflow <= mul_overflow | add_overflow | act_overflow | bias_add_overflow;
        end
    end

    // Pinout
    assign READY        = ~busy;
    assign OVERFLOW     = overflow;
    assign VALID_OUT    = act_done;
endmodule

`default_nettype wire
