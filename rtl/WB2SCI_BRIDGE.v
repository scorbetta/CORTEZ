`default_nettype none

module WB2SCI_BRIDGE
#(
    parameter ADDR_WIDTH        = 32, // At least 16 for CORTEZ chip
    parameter DATA_WIDTH        = 32,
    parameter NUM_HL_NEURONS    = 8, // 2 layers only in CORTEZ chip
    parameter NUM_OL_NEURONS    = 5,
    parameter HL_ADDR_WIDTH     = 5,
    parameter OL_ADDR_WIDTH     = 4
)
(
    input wire                                      CLK,
    input wire                                      RSTN,
    input wire                                      RST,
    // Wishbone Slave interface
    input wire                                      WB_CYC,
    input wire                                      WB_STB,
    input wire                                      WB_WE,
    input wire [ADDR_WIDTH-1:0]                     WB_ADDR,
    input wire [DATA_WIDTH-1:0]                     WB_WDATA,
    input wire [(DATA_WIDTH/8)-1:0]                 WB_SEL,
    output wire                                     WB_STALL,
    output wire                                     WB_ACK,
    output wire [DATA_WIDTH-1:0]                    WB_RDATA,
    output wire                                     WB_ERR,
    // Serial Configuration Master interface
    output wire [NUM_HL_NEURONS+NUM_OL_NEURONS-1:0] SCI_CSN,
    output wire                                     SCI_REQ,
    inout wire                                      SCI_RESP,
    inout wire                                      SCI_ACK
);

    // Share the SCI Master between HL and OL peripherals
    localparam SCI_MASTER_ADDR_WIDTH = (OL_ADDR_WIDTH > HL_ADDR_WIDTH) ? OL_ADDR_WIDTH : HL_ADDR_WIDTH;

    // FSM states
    localparam IDLE = 1'b0;
    localparam WAIT = 1'b1;

    // Signals
    reg                                         curr_state;
    wire                                        wb_stall;
    reg                                         wb_ack;
    reg [DATA_WIDTH-1:0]                        wb_rdata;
    wire                                        wb_err;
    reg [ADDR_WIDTH-1:0]                        wb_addr;
    wire                                        layer_select;
    wire [6:0]                                  neuron_select;
    wire [7:0]                                  reg_select;
    reg                                         sci_master_req;
    reg                                         sci_master_wnr;
    wire [HL_ADDR_WIDTH-1:0]                    hl_sci_master_addr;
    wire [OL_ADDR_WIDTH-1:0]                    ol_sci_master_addr;
    wire [NUM_HL_NEURONS-1:0]                   hl_sci_master_csn_in;
    wire [NUM_OL_NEURONS-1:0]                   ol_sci_master_csn_in;
    reg [DATA_WIDTH-1:0]                        sci_master_data_in;
    reg                                         sci_master_ack;
    wire [DATA_WIDTH-1:0]                       sci_master_data_out;
    wire                                        hl_sci_master_req;
    wire                                        hl_sci_master_ack;
    wire [DATA_WIDTH-1:0]                       hl_sci_master_data_out;
    wire                                        ol_sci_master_req;
    wire                                        ol_sci_master_ack;
    wire [DATA_WIDTH-1:0]                       ol_sci_master_data_out;
    wire [NUM_HL_NEURONS-1:0]                   hl_sci_csn;
    wire [NUM_OL_NEURONS-1:0]                   ol_sci_csn;
    wire                                        hl_sci_req;
    wire                                        ol_sci_req;

    // Decompose incoming address  wb_addr[ADDR_WIDTH-1:0]  . At least 16 bits are expected over the
    //  wb_addr  port: one bit addresses either HL or OL; 7 bits are used to address up to 128
    // neurons in every layer; 8 bits are used to address up to 256 registers within each neuron.
    //   [15]   layer select: 1'b0 for HL and 1'b1 for OL
    //   [14:8] neuron select
    //   [7:0]  register select
    assign { layer_select, neuron_select, reg_select } = wb_addr[15:0];
    
    assign hl_sci_master_addr   = reg_select[HL_ADDR_WIDTH-1:0];
    assign ol_sci_master_addr   = reg_select[OL_ADDR_WIDTH-1:0];
    assign hl_sci_master_csn_in = (layer_select == 1'b0) ? {NUM_HL_NEURONS{1'b1}} & ~(1 << neuron_select) : {NUM_HL_NEURONS{1'b1}};
    assign ol_sci_master_csn_in = (layer_select == 1'b1) ? {NUM_OL_NEURONS{1'b1}} & ~(1 << neuron_select) : {NUM_OL_NEURONS{1'b1}};

    // Main engine
    always @(posedge CLK) begin
        if(!RSTN) begin
            wb_ack <= 1'b0;
            sci_master_req <= 1'b0;
            curr_state <= IDLE;
        end
        else begin
            wb_ack <= 1'b0;
            sci_master_req <= 1'b0;

            case(curr_state)
                IDLE : begin
                    if(!WB_ACK && WB_CYC && WB_STB) begin
                        wb_addr <= (WB_ADDR >> 2);
                        sci_master_data_in <= WB_WDATA;
                        sci_master_req <= 1'b1;
                        sci_master_wnr <= WB_WE;
                        curr_state <= WAIT;
                    end
                end

                WAIT : begin
                    if(sci_master_wnr && sci_master_ack) begin
                        wb_ack <= 1'b1;
                        curr_state <= IDLE;
                    end
                    else if(!sci_master_wnr && sci_master_ack) begin
                        wb_ack <= 1'b1;
                        wb_rdata <= sci_master_data_out;
                        curr_state <= IDLE;
                    end
                end
            endcase
        end
    end

    assign wb_stall = (curr_state == IDLE) ? 1'b0 : 1'b1;
    assign wb_err   = (curr_state == 2'b11) ? 1'b1 : 1'b0;

    // Mux control signals driven by the main engine
    assign hl_sci_master_req    = sci_master_req & ~layer_select;
    assign ol_sci_master_req    = sci_master_req & layer_select;

    // Demux control signals back to the main engine
    assign sci_master_ack       = (layer_select == 1'b0) ? hl_sci_master_ack : ol_sci_master_ack;
    assign sci_master_data_out  = (layer_select == 1'b0) ? hl_sci_master_data_out : ol_sci_master_data_out;

    // SCI Master engines
    SCI_MASTER #(
        .ADDR_WIDTH         (HL_ADDR_WIDTH),
        .DATA_WIDTH         (DATA_WIDTH),
        .NUM_PERIPHERALS    (NUM_HL_NEURONS)
    )
    HL_SCI_MASTER (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .REQ        (hl_sci_master_req),
        .WNR        (sci_master_wnr),
        .ADDR       (hl_sci_master_addr),
        .CSN_IN     (hl_sci_master_csn_in),
        .DATA_IN    (sci_master_data_in),
        .ACK        (hl_sci_master_ack),
        .DATA_OUT   (hl_sci_master_data_out),
        .SCI_CSN    (hl_sci_csn),
        .SCI_REQ    (hl_sci_req),
        .SCI_RESP   (SCI_RESP),
        .SCI_ACK    (SCI_ACK)
    );

    SCI_MASTER #(
        .ADDR_WIDTH         (OL_ADDR_WIDTH),
        .DATA_WIDTH         (DATA_WIDTH),
        .NUM_PERIPHERALS    (NUM_OL_NEURONS)
    )
    OL_SCI_MASTER (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .REQ        (ol_sci_master_req),
        .WNR        (sci_master_wnr),
        .ADDR       (ol_sci_master_addr),
        .CSN_IN     (ol_sci_master_csn_in),
        .DATA_IN    (sci_master_data_in),
        .ACK        (ol_sci_master_ack),
        .DATA_OUT   (ol_sci_master_data_out),
        .SCI_CSN    (ol_sci_csn),
        .SCI_REQ    (ol_sci_req),
        .SCI_RESP   (SCI_RESP),
        .SCI_ACK    (SCI_ACK)
    );

    // Pinout
    assign WB_STALL = wb_stall;
    assign WB_ACK   = wb_ack;
    assign WB_RDATA = wb_rdata;
    assign WB_ERR   = wb_err;
    assign SCI_CSN  = { ol_sci_csn, hl_sci_csn };
    assign SCI_REQ  = (layer_select == 1'b0) ? hl_sci_req : ol_sci_req;

    reg [15:0] counter;
    always @(posedge CLK) begin
        if(!RSTN) begin
            counter <= 0;
        end
        else begin
            counter <= counter + 1;
        end
    end
endmodule

`default_nettype wire
