`timescale 1ns/100ps

// Make Verilator happy with flattened interfaces
module NETWORK_TOP_WRAPPER
#(
    parameter AXI_BASE_ADDR = 32'h00000000
)
(
    // Clock and reset
    input           CLK,
    input           RSTN,
    input           RST,
    // Wishbone interface
    input           CYC,
    input           STB,
    input           WE,
    input [31:0]    ADDR,
    input [7:0]     WDATA,
    input [3:0]     SEL,
    output          STALL,
    output          ACK,
    output [7:0]    RDATA,
    output          ERR,
    // 7-segements display anode and segments control
    output [3:0]    SS_ANODES,
    output [7:0]    SS_SEGMENTS,
    // LEDs control
    output [7:0]    LEDS
);

    // Wishbone Slave interface
    wishbone_if #(
        .DATA_WIDTH (8),
        .ADDR_WIDTH (32)
    )
    wb_port (
        .clk    (CLK),
        .rst    (RST)
    );

    // AXI4 Lite Master interface
    axi4l_if #(
        .DATA_WIDTH (8),
        .ADDR_WIDTH (32)
    )
    axi4l_port (
        .aclk       (CLK),
        .aresetn    (RSTN)
    );

    // Unpack Wishbone interface
    assign wb_port.cyc      = CYC;
    assign wb_port.stb      = STB;
    assign wb_port.we       = WE;
    assign wb_port.addr     = ADDR;
    assign wb_port.wdata    = WDATA;
    assign wb_port.sel      = SEL;
    assign STALL            = wb_port.stall;
    assign ACK              = wb_port.ack;
    assign RDATA            = wb_port.rdata;
    assign ERR              = wb_port.err;

    // Wishbone-to-AXI4 Lite converter
    WB2AXI4LITE_BRIDGE #(
        .ADDR_WIDTH     (32),
        .DATA_WIDTH     (8),
        .AXI_BASE_ADDR  (AXI_BASE_ADDR)
    )
    WB2AXI_BRIDGE (
        .CLK            (CLK),
        .RSTN           (RSTN),
        .RST            (RST),
        .WISHBONE_PORT  (wb_port),
        .AXI4LITE_PORT  (axi4l_port)
    );

    // AXI4 Lite network
    NETWORK_TOP NETWORK_TOP (
        .CLK            (CLK),
        .RSTN           (RSTN),
        .AXI4L_PORT     (axi4l_port),
        .SS_ANODES      (SS_ANODES),
        .SS_SEGMENTS    (SS_SEGMENTS),
        .LEDS           (LEDS)
    );
endmodule
