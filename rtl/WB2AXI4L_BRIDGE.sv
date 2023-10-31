`timescale 1ns/100ps

// SystemVerilog porting of the original  WishboneAXI_v0_2_M_AXI4_LITE  VHDL design taken from
//  https://github.com/qermit/WishboneAXI/tree/master
module WB2AXI4LITE_BRIDGE
#(
    parameter ADDR_WIDTH    = 32,
    parameter DATA_WIDTH    = 32
)
(
    input               CLK,
    input               RSTN,
    input               RST,
    wishbone_if.slave   WISHBONE_PORT,
    axi4l_if.master     AXI4LITE_PORT
);

    // Connections
    logic                       wb_stall;
    logic [ADDR_WIDTH-1:0]      axi_waddr;
    logic [DATA_WIDTH-1:0]      axi_wdata;
    logic [(DATA_WIDTH/8)-1:0]  axi_wstrb;
    logic [ADDR_WIDTH-1:0]      axi_raddr;

    // Part of these interfaces are used to control output interfaces
    wishbone_if #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    )
    wb_r (
        .clk    (CLK),
        .rst    (RST)
    );

    wishbone_if #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    )
    wb_w (
        .clk    (CLK),
        .rst    (RST)
    );

    // AXI4 signals
    assign AXI4LITE_PORT.awaddr = axi_waddr;
    assign AXI4LITE_PORT.araddr = axi_raddr;
    assign AXI4LITE_PORT.wdata = axi_wdata;
    assign AXI4LITE_PORT.wstrb = axi_wstrb;

    // Write address channel 
    always_ff @(posedge CLK) begin
        if(!RSTN) begin
            AXI4LITE_PORT.awvalid <= 1'b0;
        end
        else if(WISHBONE_PORT.cyc && WISHBONE_PORT.stb && WISHBONE_PORT.we && !wb_stall) begin
            axi_waddr = WISHBONE_PORT.addr;
            AXI4LITE_PORT.awvalid <= 1'b1;
        end
        else if(AXI4LITE_PORT.awready) begin
            AXI4LITE_PORT.awvalid <= 1'b0;
        end
    end

    // Write data channel
    always_ff @(posedge CLK) begin
        if(!RSTN) begin
          AXI4LITE_PORT.wvalid <= 1'b0;
        end
        else if(WISHBONE_PORT.cyc && WISHBONE_PORT.stb && WISHBONE_PORT.we && !wb_stall) begin
            axi_wdata <= WISHBONE_PORT.wdata;
            axi_wstrb <= WISHBONE_PORT.sel;
            AXI4LITE_PORT.wvalid <= 1'b1;
        end
        else if(AXI4LITE_PORT.wready) begin
            AXI4LITE_PORT.wvalid <= 1'b0;
        end
    end

    // Write response channel
    always_ff @(posedge CLK) begin
        if(!RSTN) begin
            WISHBONE_PORT.stall <= 1'b0;
        end 
        else if(WISHBONE_PORT.cyc && WISHBONE_PORT.stb && WISHBONE_PORT.we && !wb_stall) begin
            WISHBONE_PORT.stall <= 1'b1;
        end
        else if(AXI4LITE_PORT.bvalid) begin
            WISHBONE_PORT.stall <= 1'b0;
        end
    end

    // Read address channel
    always_ff @(posedge CLK) begin
        if(!RSTN) begin
            AXI4LITE_PORT.arvalid <= 1'b0;
        end
        else if(WISHBONE_PORT.cyc && WISHBONE_PORT.stb && !WISHBONE_PORT.we && !wb_stall) begin
            axi_raddr <= WISHBONE_PORT.addr;
            AXI4LITE_PORT.arvalid <= 1'b1;
        end
        else if(AXI4LITE_PORT.arready) begin
            AXI4LITE_PORT.arvalid <= 1'b0;
        end
    end

    // AXI stall
    always_ff @(posedge CLK) begin
        if(!RSTN) begin
          wb_r.stall <= 1'b0;
        end
        else if(WISHBONE_PORT.cyc && WISHBONE_PORT.stb && !WISHBONE_PORT.we && !wb_stall) begin
            wb_r.stall <= 1'b1;
        end
        else if(AXI4LITE_PORT.rvalid) begin
            wb_r.stall <= 1'b0;
        end
    end

    always_ff @(posedge CLK) begin
        if(!RSTN) begin
          wb_w.stall <= 1'b0;
        end
        else if(WISHBONE_PORT.cyc && WISHBONE_PORT.stb && WISHBONE_PORT.we && !wb_stall) begin
            wb_w.stall <= 1'b1;
        end
        else if(AXI4LITE_PORT.bvalid) begin
            wb_w.stall <= 1'b0;
        end
    end

    // Wishbone signals
    assign wb_stall = ( (!wb_r.stall && !wb_w.stall) ? 1'b0 : 1'b1 );
    assign WISHBONE_PORT.ack = ( (wb_r.ack || wb_w.ack) ? 1'b1 : 1'b0 );
    assign WISHBONE_PORT.err = ( (wb_r.err || wb_w.err) ? 1'b1 : 1'b0 );
    assign WISHBONE_PORT.wdata = wb_r.wdata;
 
    // Read channel always ready
    assign WISHBONE_PORT.rdata = AXI4LITE_PORT.rdata;
    assign AXI4LITE_PORT.rready = 1'b1;
    assign wb_r.ack = (AXI4LITE_PORT.rvalid & !AXI4LITE_PORT.rresp[1]);
    assign wb_r.err = (AXI4LITE_PORT.rvalid & !AXI4LITE_PORT.rresp[1]);
    
    // Wishbone Write return channel always ready
    assign AXI4LITE_PORT.bready = 1'b1;
    assign wb_w.ack = (AXI4LITE_PORT.bvalid & !AXI4LITE_PORT.bresp[1]);
    assign wb_w.err = (AXI4LITE_PORT.bvalid & !AXI4LITE_PORT.bresp[1]);
endmodule
