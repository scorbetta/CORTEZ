`default_nettype none

// Simple crossbar to connect one Master to two Slaves. One transaction at a time only
module WBXBAR
(
    input wire          CLK,
    input wire          RSTN,
    // Master-side interface
    input wire          WBM_CYC,
    input wire          WBM_STB,
    input wire          WBM_WE,
    input wire [31:0]   WBM_ADDR,
    input wire [7:0]    WBM_WDATA,
    input wire          WBM_SEL,
    output wire         WBM_STALL,
    output wire         WBM_ACK,
    output wire [7:0]   WBM_RDATA,
    output wire         WBM_ERR,
    // Slave#0-side interface
    output wire         WBS0_CYC,
    output wire         WBS0_STB,
    output wire         WBS0_WE,
    output wire [31:0]  WBS0_ADDR,
    output wire [7:0]   WBS0_WDATA,
    output wire         WBS0_SEL,
    input wire          WBS0_STALL,
    input wire          WBS0_ACK,
    input wire [7:0]    WBS0_RDATA,
    input wire          WBS0_ERR,
    // Slave#1-side interface
    output wire         WBS1_CYC,
    output wire         WBS1_STB,
    output wire         WBS1_WE,
    output wire [31:0]  WBS1_ADDR,
    output wire [7:0]   WBS1_WDATA,
    output wire         WBS1_SEL,
    input wire          WBS1_STALL,
    input wire          WBS1_ACK,
    input wire [7:0]    WBS1_RDATA,
    input wire          WBS1_ERR
);

    localparam IDLE     = 2'b00;
    localparam WRITE    = 2'b01;
    localparam READ     = 2'b10;
    localparam PAD      = 2'b11;

    reg [1:0]   curr_state;
    reg         wbm_ack;
    reg         wbm_we;
    reg [31:0]  wbm_addr;
    reg [7:0]   wbm_wdata;
    reg [7:0]   wbm_rdata;
    reg         wbm_sel;
    reg [1:0]   wbsx_cyc;
    reg [1:0]   wbsx_stb;
    reg         slave_select;

    // Simplified control engine
    always @(posedge CLK) begin
        if(!RSTN) begin
            wbm_ack <= 1'b0;
            wbsx_cyc <= 2'b00;
            wbsx_stb <= 2'b00;
            curr_state <= IDLE;
        end
        else begin
            wbm_ack <= 1'b0;

            case(curr_state)
                IDLE : begin
                    wbm_we <= WBM_WE;
                    wbm_addr <= WBM_ADDR;
                    wbm_wdata <= WBM_WDATA;
                    wbm_sel <= WBM_SEL;
                    slave_select = WBM_ADDR[18];

                    if(WBM_CYC && WBM_STB && WBM_WE) begin
                        wbsx_cyc <= { WBM_ADDR[18], ~WBM_ADDR[18] };
                        wbsx_stb <= { WBM_ADDR[18], ~WBM_ADDR[18] };
                        curr_state <= WRITE;
                    end
                    else if(WBM_CYC && WBM_STB && !WBM_WE) begin
                        wbsx_cyc <= { WBM_ADDR[18], ~WBM_ADDR[18] };
                        wbsx_stb <= { WBM_ADDR[18], ~WBM_ADDR[18] };
                        curr_state <= READ;
                    end
                end

                WRITE : begin
                    if((!slave_select && WBS0_ACK) || (slave_select && WBS1_ACK)) begin
                        wbsx_cyc <= 2'b00;
                        wbsx_stb <= 2'b00;
                        wbm_ack <= 1'b1;
                        curr_state <= PAD;
                    end
                end

                READ : begin
                    if(!slave_select && WBS0_ACK) begin
                        wbsx_cyc <= 2'b00;
                        wbsx_stb <= 2'b00;
                        wbm_ack <= 1'b1;
                        wbm_rdata <= WBS0_RDATA;
                        curr_state <= PAD;
                    end
                    else if(slave_select && WBS1_ACK) begin
                        wbsx_cyc <= 2'b00;
                        wbsx_stb <= 2'b00;
                        wbm_ack <= 1'b1;
                        wbm_rdata <= WBS1_RDATA;
                        curr_state <= PAD;
                    end
                end

                PAD : begin
                    if(!WBM_CYC && !WBM_STB) begin
                        curr_state <= IDLE;
                    end
                end

                default : begin
                end
            endcase
        end
    end

    assign { WBS1_CYC, WBS0_CYC }   = wbsx_cyc;
    assign { WBS1_STB, WBS0_STB }   = wbsx_stb;

    // Pinout
    assign WBM_STALL    = ((curr_state == IDLE) && (wbm_ack == 1'b0)) ? 1'b0 : 1'b1;
    assign WBM_ERR      = 1'b0;
    assign WBM_ACK      = wbm_ack;
    assign WBM_RDATA    = wbm_rdata;
    assign WBS0_WE      = wbm_we;
    assign WBS0_ADDR    = wbm_addr;
    assign WBS0_WDATA   = wbm_wdata;
    assign WBS0_SEL     = wbm_sel;
    assign WBS1_WE      = wbm_we;
    assign WBS1_ADDR    = wbm_addr;
    assign WBS1_WDATA   = wbm_wdata;
    assign WBS1_SEL     = wbm_sel;
endmodule

`default_nettype wire
