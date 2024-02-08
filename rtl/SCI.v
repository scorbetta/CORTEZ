`default_nettype none

module SCI #(
    // Address width
    parameter ADDR_WIDTH    = 8,
    // Data width
    parameter DATA_WIDTH    = 8
)
(
    input wire                      CLK,
    input wire                      RSTN,
    // Serial interface
    input wire                      CSN,
    input wire                      SIN,
    output wire                     SOUT,
    output wire                     SACK,
    // Register interface
    output wire                     WREQ,
    output wire [ADDR_WIDTH-1:0]    WADDR,
    output wire [DATA_WIDTH-1:0]    WDATA,
    input wire                      WACK,
    output wire                     RREQ,
    output wire [ADDR_WIDTH-1:0]    RADDR,
    input wire [DATA_WIDTH-1:0]     RDATA,
    input wire                      RVALID
);

    localparam IDLE         = 3'b000;
    localparam ADDRESS      = 3'b001;
    localparam WRITE_DATA   = 3'b010;
    localparam READ_DATA    = 3'b011;
    localparam FLUSH_DATA   = 3'b100;

    reg [2:0]               curr_state;
    reg                     wnr;
    wire                    addr_count_en;
    wire                    data_count_en;
    reg                     count_reset;
    wire [ADDR_WIDTH-1:0]   addr_count;
    wire [DATA_WIDTH-1:0]   data_count;
    wire                    wdata_shift_en;
    wire                    rdata_shift_en;
    reg                     wreq;
    reg                     rreq;
    wire [ADDR_WIDTH-1:0]   reg_addr;
    wire [DATA_WIDTH-1:0]   reg_wdata;

    // Control engine
    always @(posedge CLK) begin
        if(!RSTN) begin
            wnr <= 1'b0;
            count_reset <= 1'b0;
            wreq <= 1'b0;
            rreq <= 1'b0;
            curr_state <= IDLE;
        end
        else begin
            count_reset <= 1'b1;
            wreq <= 1'b0;
            rreq <= 1'b0;

            case(curr_state)
                IDLE : begin
                    if(!CSN) begin
                        wnr <= SIN;
                        curr_state <= ADDRESS;
                    end
                end

                ADDRESS : begin
                    if(addr_count == ADDR_WIDTH-1) begin
                        if(wnr) begin
                            curr_state <= WRITE_DATA;
                        end
                        else begin
                            rreq <= 1'b1;
                            curr_state <= READ_DATA;
                        end
                    end
                end

                WRITE_DATA : begin
                    if(data_count == DATA_WIDTH-1) begin
                        wreq <= 1'b1;
                        count_reset <= 1'b0;
                        curr_state <= IDLE;
                    end
                end

                READ_DATA : begin
                    if(RVALID) begin
                        curr_state <= FLUSH_DATA;
                    end
                end

                FLUSH_DATA : begin
                    if(data_count == DATA_WIDTH-1) begin
                        count_reset <= 1'b0;
                        curr_state <= IDLE;
                    end
                end

                default : begin
                end
            endcase
        end
    end

    // Count up only when in proper phase
    assign addr_count_en = (curr_state == ADDRESS) ? 1'b1 : 1'b0;
    assign data_count_en = (curr_state == WRITE_DATA || curr_state == FLUSH_DATA) ? 1'b1 : 1'b0;
    assign wdata_shift_en = (curr_state == WRITE_DATA) ? 1'b1 : 1'b0;
    assign rdata_shift_en = (curr_state == FLUSH_DATA) ? 1'b1 : 1'b0;

    COUNTER #(
        .WIDTH  (ADDR_WIDTH)
    )
    ADDR_COUNTER (
        .CLK        (CLK),
        .RSTN       (count_reset),
        .EN         (addr_count_en),
        .VALUE      (addr_count),
        .OVERFLOW   () // Unused
    );

    COUNTER #(
        .WIDTH  (DATA_WIDTH)
    )
    DATA_COUNTER (
        .CLK        (CLK),
        .RSTN       (count_reset),
        .EN         (data_count_en),
        .VALUE      (data_count),
        .OVERFLOW   () // Unused
    );

    SIPO_BUFFER #(
        .DEPTH  (ADDR_WIDTH)
    )
    ADDRESS_BUFFER (
        .CLK    (CLK),
        .SIN    (SIN),
        .EN     (addr_count_en),
        .POUT   (reg_addr)
    );

    SIPO_BUFFER #(
        .DEPTH  (DATA_WIDTH)
    )
    WDATA_BUFFER (
        .CLK    (CLK),
        .SIN    (SIN),
        .EN     (wdata_shift_en),
        .POUT   (reg_wdata)
    );

    PISO_BUFFER #(
        .DEPTH  (DATA_WIDTH)
    )
    RDATA_BUFFER (
        .CLK        (CLK),
        .PIN        (RDATA),
        .LOAD_IN    (RVALID),
        .SHIFT_OUT  (rdata_shift_en),
        .SOUT       (SOUT)
    );

    assign WREQ     = wreq;
    assign WADDR    = reg_addr;
    assign WDATA    = reg_wdata;
    assign RREQ     = rreq;
    assign RADDR    = reg_addr;
    assign SACK     = rdata_shift_en;
endmodule

`default_nettype wire
