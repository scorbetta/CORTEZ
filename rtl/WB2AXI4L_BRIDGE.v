`default_nettype none

// SystemVerilog porting of the original  WishboneAXI_v0_2_M_AXI4_LITE  VHDL design taken from
//  https://github.com/qermit/WishboneAXI/tree/master
module WB2AXI4LITE_BRIDGE
#(
    parameter ADDR_WIDTH    = 32,
    parameter DATA_WIDTH    = 32,
    parameter AXI_BASE_ADDR = 32'h00000000
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
    // AXI4 Lite Maste interface
    output wire [ADDR_WIDTH-1:0]        AXI_AWADDR,
    output wire [2:0]                   AXI_AWPROT,
    output wire                         AXI_AWVALID,
    input wire                          AXI_AWREADY,
    output wire [DATA_WIDTH-1:0]        AXI_WDATA,
    output wire [(DATA_WIDTH/8)-1:0]    AXI_WSTRB,
    output wire                         AXI_WVALID,
    input wire                          AXI_WREADY,
    input wire [1:0]                    AXI_BRESP,
    input wire                          AXI_BVALID,
    output wire                         AXI_BREADY,
    output wire [ADDR_WIDTH-1:0]        AXI_ARADDR,
    output wire [2:0]                   AXI_ARPROT,
    output wire                         AXI_ARVALID,
    input wire                          AXI_ARREADY,
    input wire [DATA_WIDTH-1:0]         AXI_RDATA,
    input wire [1:0]                    AXI_RRESP,
    input wire                          AXI_RVALID,
    output wire                         AXI_RREADY
);

    // Connections
    reg                         axi_awvalid;
    reg [ADDR_WIDTH-1:0]        axi_awaddr;
    reg                         axi_wvalid;
    reg [DATA_WIDTH-1:0]        axi_wdata;
    reg [(DATA_WIDTH/8)-1:0]    axi_wstrb;
    reg                         axi_arvalid;
    reg [ADDR_WIDTH-1:0]        axi_araddr;
    wire                        wb_stall;
    reg                         wb_r_stall;
    reg                         wb_w_stall;
    wire                        wb_r_ack;
    wire                        wb_r_err;
    wire                        wb_w_ack;
    wire                        wb_w_err;

    // Write address channel 
    always @(posedge CLK) begin
        if(!RSTN) begin
            axi_awvalid <= 1'b0;
        end
        else if(WB_CYC && WB_STB && WB_WE && !wb_stall) begin
            axi_awaddr <= (WB_ADDR - AXI_BASE_ADDR) >> 2;
            axi_awvalid <= 1'b1;
        end
        else if(AXI_AWREADY) begin
            axi_awvalid <= 1'b0;
        end
    end

    // Write data channel
    always @(posedge CLK) begin
        if(!RSTN) begin
          axi_wvalid <= 1'b0;
        end
        else if(WB_CYC && WB_STB && WB_WE && !wb_stall) begin
            axi_wdata <= WB_WDATA;
            axi_wstrb <= WB_SEL;
            axi_wvalid <= 1'b1;
        end
        else if(AXI_WREADY) begin
            axi_wvalid <= 1'b0;
        end
    end

    // Write is busy
    always @(posedge CLK) begin
        if(!RSTN) begin
            wb_w_stall <= 1'b0;
        end 
        else if(WB_CYC && WB_STB && WB_WE && !wb_stall) begin
            wb_w_stall <= 1'b1;
        end
        else if(AXI_BVALID) begin
            wb_w_stall <= 1'b0;
        end
    end

    // Read address channel
    always @(posedge CLK) begin
        if(!RSTN) begin
            axi_arvalid <= 1'b0;
        end
        else if(WB_CYC && WB_STB && !WB_WE && !wb_stall) begin
            axi_araddr <= (WB_ADDR - AXI_BASE_ADDR) >> 2;
            axi_arvalid <= 1'b1;
        end
        else if(AXI_ARREADY) begin
            axi_arvalid <= 1'b0;
        end
    end

    // Read is busy
    always @(posedge CLK) begin
        if(!RSTN) begin
          wb_r_stall <= 1'b0;
        end
        else if(WB_CYC && WB_STB && !WB_WE && !wb_stall) begin
            wb_r_stall <= 1'b1;
        end
        else if(AXI_RVALID) begin
            wb_r_stall <= 1'b0;
        end
    end

    // One transaction at a time
    assign wb_stall = wb_r_stall | wb_w_stall;

    // Read data channel always ready
    assign WB_RDATA     = AXI_RDATA;
    assign AXI_RREADY   = 1'b1;
    assign wb_r_ack     = (AXI_RVALID & AXI_RREADY);
    assign wb_r_err     = (AXI_RVALID & AXI_RREADY & AXI_RRESP[1]);
    
    // Write return channel always ready
    assign AXI_BREADY   = 1'b1;
    assign wb_w_ack     = (AXI_BVALID & AXI_BREADY);
    assign wb_w_err     = (AXI_BVALID & AXI_BREADY & AXI_BRESP[1]);

    // Unused
    assign AXI_AWPROT = 3'b000;
    assign AXI_ARPROT = 3'b000;

    // Pinout
    assign AXI_AWVALID  = axi_awvalid;
    assign AXI_AWADDR   = axi_awaddr;
    assign AXI_ARADDR   = axi_araddr;
    assign AXI_WDATA    = axi_wdata;
    assign AXI_WSTRB    = axi_wstrb;
    assign AXI_WVALID   = axi_wvalid;
    assign WB_STALL     = wb_stall;
    assign WB_ACK       = wb_r_ack | wb_w_ack;
    assign WB_ERR       = wb_r_err | wb_w_err;
    assign AXI_ARVALID  = axi_arvalid;
endmodule

`default_nettype wire
