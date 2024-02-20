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
    input wire                          CLK,
    input wire                          RSTN,
    input wire                          RST,
    // Wishbone Slave interface
    input wire                          WB_CYC,
    input wire                          WB_STB,
    input wire                          WB_WE,
    input wire [ADDR_WIDTH-1:0]         WB_ADDR,
    input wire [DATA_WIDTH-1:0]         WB_WDATA,
    input wire [(DATA_WIDTH/8)-1:0]     WB_SEL,
    output wire                         WB_STALL,
    output wire                         WB_ACK,
    output wire [DATA_WIDTH-1:0]        WB_RDATA,
    output wire                         WB_ERR,
    // Serial Configuration Master interface
    output wire [NUM_HL_NEURONS-1:0]    HL_SCI_CSN,
    output wire [NUM_OL_NEURONS-1:0]    OL_SCI_CSN,
    output wire                         SCI_SOUT,
    inout wire                          SCI_SIN,
    inout wire                          SCI_SACK
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
    wire [SCI_MASTER_ADDR_WIDTH-1:0]            sci_master_addr;
    wire [(NUM_HL_NEURONS+NUM_OL_NEURONS-1):0]  sci_master_csn_in;
    reg [DATA_WIDTH-1:0]                        sci_master_data_in;
    reg                                         sci_master_ack;
    wire [DATA_WIDTH-1:0]                       sci_master_data_out;

    // Decompose incoming address  wb_addr[ADDR_WIDTH-1:0]  . At least 16 bits are expected over the
    //  wb_addr  port: one bit addresses either HL or OL; 7 bits are used to address up to 128
    // neurons in every layer; 8 bits are used to address up to 256 registers within each neuron.
    //   [15]   layer select: 1'b0 for HL and 1'b1 for OL
    //   [14:8] neuron select
    //   [7:0]  register select
    assign { layer_select, neuron_select, reg_select } = wb_addr[15:0];

    // Decode Wishbone address into SCI address and SCI chip-select
    assign sci_master_addr =
        (layer_select == 1'b0)
        ? { {(SCI_MASTER_ADDR_WIDTH-HL_ADDR_WIDTH){1'b0}}, reg_select[HL_ADDR_WIDTH-1:0] }
        : { {(SCI_MASTER_ADDR_WIDTH-OL_ADDR_WIDTH){1'b0}}, reg_select[OL_ADDR_WIDTH-1:0] };

    assign sci_master_csn_in = {(NUM_HL_NEURONS+NUM_OL_NEURONS){1'b1}} & ~(1 << neuron_select);

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
                        wb_addr <= WB_ADDR;
                        sci_master_data_in <= WB_WDATA;
                        sci_master_req <= 1'b1;
                        sci_master_wnr <= WB_WE;
                        curr_state <= WAIT;
                    end
                end

                WAIT : begin
                    if(sci_master_wnr) begin
                        wb_ack <= 1'b1;
                        curr_state <= IDLE;
                    end
                    else if(sci_master_ack && !sci_master_wnr) begin
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

    // SCI Master engines
    SCI_MASTER #(
        .ADDR_WIDTH         (SCI_MASTER_ADDR_WIDTH),
        .DATA_WIDTH         (DATA_WIDTH),
        .NUM_PERIPHERALS    (NUM_HL_NEURONS + NUM_OL_NEURONS)
    )
    SCI_MASTER (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .REQ        (sci_master_req),
        .WNR        (sci_master_wnr),
        .ADDR       (sci_master_addr),
        .CSN_IN     (sci_master_csn_in),
        .DATA_IN    (sci_master_data_in),
        .ACK        (sci_master_ack),
        .DATA_OUT   (sci_master_data_out),
        .SCI_CSN    ({ OL_SCI_CSN, HL_SCI_CSN }),
        .SCI_SOUT   (SCI_SOUT),
        .SCI_SIN    (SCI_SIN),
        .SCI_SACK   (SCI_SACK)
    );

    // Pinout
    assign WB_STALL = wb_stall;
    assign WB_ACK   = wb_ack;
    assign WB_RDATA = wb_rdata;
    assign WB_ERR   = wb_err;
endmodule

`default_nettype wire
