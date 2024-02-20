`default_nettype none

module SCI_MASTER
#(
    parameter ADDR_WIDTH        = 4,
    parameter DATA_WIDTH        = 8,
    parameter NUM_PERIPHERALS   = 2
)
(
    input wire                          CLK,
    input wire                          RSTN,
    // Request interface
    input wire                          REQ,
    input wire                          WNR,
    input wire [ADDR_WIDTH-1:0]         ADDR,
    input wire [NUM_PERIPHERALS-1:0]    CSN_IN,
    input wire [DATA_WIDTH-1:0]         DATA_IN,
    output wire                         ACK,
    output wire [DATA_WIDTH-1:0]        DATA_OUT,
    // Serial interface
    output wire [NUM_PERIPHERALS-1:0]   SCI_CSN,
    output wire                         SCI_SOUT,
    inout                               SCI_SIN,
    inout                               SCI_SACK
);

    localparam IDLE             = 2'b00;
    localparam ADDRESS_PHASE    = 2'b01;
    localparam WDATA_PHASE      = 2'b10;
    localparam RDATA_PHASE      = 2'b11;

    reg [1:0]                       curr_state;
    reg                             sci_sout;
    wire [NUM_PERIPHERALS-1:0]      sci_csn;
    reg [$clog2(DATA_WIDTH)-1:0]    data_count;
    reg [$clog2(ADDR_WIDTH)-1:0]    addr_count;
    wire                            addr_load;
    wire                            addr_shift;
    wire                            addr;
    wire                            wdata_load;
    wire                            wdata_shift;
    wire                            wdata;
    wire                            rdata_load;
    wire                            count_rstn;
    reg                             ack;
    wire                            sci_sin_enable;
    wire                            sci_sin;
    wire                            sci_sack_enable;
    wire                            sci_sack;

    // Address and data buffers
    PISO_BUFFER #(
        .DEPTH  (ADDR_WIDTH)
    )
    ADDR_BUFFER (
        .CLK        (CLK),
        .PIN        (ADDR),
        .LOAD_IN    (REQ),
        .SHIFT_OUT  (addr_shift),
        .SOUT       (addr)
    );

    PISO_BUFFER #(
        .DEPTH  (DATA_WIDTH)
    )
    WDATA_BUFFER (
        .CLK        (CLK),
        .PIN        (DATA_IN),
        .LOAD_IN    (wdata_load),
        .SHIFT_OUT  (wdata_shift),
        .SOUT       (wdata)
    );

    // Data from the selected peripheral will shift in serially. Data will *not* be counted,
    // instead data transfer is considered done when the peripheral clears  SCI_SACK  signal
    SIPO_BUFFER #(
        .DEPTH  (DATA_WIDTH)
    )
    RDATA_BUFFER (
        .CLK    (CLK),
        .SIN    (SCI_SIN),
        .EN     (rdata_load),
        .POUT   (DATA_OUT)
    );

    // Load data only when needed
    assign wdata_load = REQ & WNR;

    // Counters
    COUNTER #(
        .WIDTH  (ADDR_WIDTH)
    )
    ADDR_COUNTER (
        .CLK        (CLK),
        .RSTN       (count_rstn),
        .EN         (addr_shift),
        .VALUE      (addr_count),
        .OVERFLOW   () // Unused
    );

    COUNTER #(
        .WIDTH  (DATA_WIDTH)
    )
    WDATA_COUNTER (
        .CLK        (CLK),
        .RSTN       (count_rstn),
        .EN         (wdata_shift),
        .VALUE      (data_count),
        .OVERFLOW   () // Unused
    );

    // Detects peripheral transfer end
    EDGE_DETECTOR PERIPH_ACK_EDGE (
        .CLK            (CLK),
        .SAMPLE_IN      (SCI_SACK),
        .RISE_EDGE_OUT  (), // Unused
        .FALL_EDGE_OUT  (ack)
    );

    // Shift and count control signals
    assign count_rstn   = (curr_state == IDLE) ? 1'b0 : 1'b1;
    assign addr_shift   = (curr_state == ADDRESS_PHASE) ? 1'b1 : 1'b0;
    assign wdata_shift  = (curr_state == WDATA_PHASE) ? 1'b1 : 1'b0;
    assign rdata_load   = (curr_state == RDATA_PHASE) ? SCI_SACK : 1'b0;

    // Peripheral select
    assign sci_csn = ( (curr_state == IDLE) ? ( REQ ? CSN_IN : {NUM_PERIPHERALS{1'b1}} ) : CSN_IN );

    // Main engine
    always @(posedge CLK) begin
        if(!RSTN) begin
            curr_state <= IDLE;
        end
        else begin
            case(curr_state)
                IDLE : begin
                    if(REQ) begin
                        curr_state <= ADDRESS_PHASE;
                    end
                end

                ADDRESS_PHASE : begin
                    if(addr_count == ADDR_WIDTH-1 && WNR) begin
                        curr_state <= WDATA_PHASE;
                    end
                    else if(addr_count == ADDR_WIDTH-1 && !WNR) begin
                        curr_state <= RDATA_PHASE;
                    end
                end

                WDATA_PHASE : begin
                    if(data_count == DATA_WIDTH-1) begin
                        curr_state <= IDLE;
                    end
                end

                RDATA_PHASE : begin
                    if(ack) begin
                        curr_state <= IDLE;
                    end
                end
            endcase
        end
    end

    // Mux internals to output
    always @* begin
        case(curr_state)
            IDLE : begin
                sci_sout = WNR;
            end

            ADDRESS_PHASE : begin
                sci_sout = addr;
            end

            WDATA_PHASE : begin
                sci_sout = wdata;
            end

            default : begin
                sci_sout = WNR;
            end
        endcase
    end

    // Response interface line is tri-stated
    assign sci_sin_enable   = 1'b0;
    assign SCI_SIN          = (sci_sin_enable ? 1'b0 : 1'bz);
    assign sci_sin          = SCI_SIN;

    assign sci_sack_enable  = 1'b0;
    assign SCI_SACK         = (sci_sack_enable ? 1'b0 : 1'bz);
    assign sci_sack         = SCI_SACK;

    // Pinout
    assign ACK      = ack;
    assign SCI_CSN  = sci_csn;
    assign SCI_SOUT = sci_sout;
endmodule

`default_nettype wire
