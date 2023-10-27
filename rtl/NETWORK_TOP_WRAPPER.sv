`timescale 1ns/100ps

// Make Verilator happy with flattened interfaces
module NETWORK_TOP_WRAPPER
(
    input           CLK,
    input           RSTN,
    input [31:0]    AXI4L_AWADDR,
    input [2:0]     AXI4L_AWPROT,
    input           AXI4L_AWVALID,
    output          AXI4L_AWREADY,
    input [31:0]    AXI4L_WDATA,
    input [3:0]     AXI4L_WSTRB,
    input           AXI4L_WVALID,
    output          AXI4L_WREADY,
    output [1:0]    AXI4L_BRESP,
    output          AXI4L_BVALID,
    input           AXI4L_BREADY,
    input [31:0]    AXI4L_ARADDR,
    input [2:0]     AXI4L_ARPROT,
    input           AXI4L_ARVALID,
    output          AXI4L_ARREADY,
    output [31:0]   AXI4L_RDATA,
    output [1:0]    AXI4L_RRESP,
    output          AXI4L_RVALID,
    input           AXI4L_RREADY
);

    axi4l_if #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (32)
    )
    axi4l_port (
        .aclk       (CLK),
        .aresetn    (RSTN)
    );

    assign axi4l_port.awaddr    = AXI4L_AWADDR;
    assign axi4l_port.awprot    = AXI4L_AWPROT;
    assign axi4l_port.awvalid   = AXI4L_AWVALID;
    assign AXI4L_AWREADY        = axi4l_port.awready;
    assign axi4l_port.wdata     = AXI4L_WDATA;
    assign axi4l_port.wstrb     = AXI4L_WSTRB;
    assign axi4l_port.wvalid    = AXI4L_WVALID;
    assign AXI4L_WREADY         = axi4l_port.wready;
    assign AXI4L_BRESP          = axi4l_port.bresp;
    assign AXI4L_BVALID         = axi4l_port.bvalid;
    assign axi4l_port.bready    = AXI4L_BREADY;
    assign axi4l_port.araddr    = AXI4L_ARADDR;
    assign axi4l_port.arprot    = AXI4L_ARPROT;
    assign axi4l_port.arvalid   = AXI4L_ARVALID;
    assign AXI4L_ARREADY        = axi4l_port.arready;
    assign AXI4L_RDATA          = axi4l_port.rdata;
    assign AXI4L_RRESP          = axi4l_port.rresp;
    assign AXI4L_RVALID         = axi4l_port.rvalid;
    assign axi4l_port.rready    = AXI4L_RREADY;

    NETWORK_TOP NETWORK_TOP (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .AXI4L_PORT (axi4l_port)
    );
endmodule
