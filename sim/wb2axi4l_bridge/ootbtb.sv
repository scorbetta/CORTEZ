`timescale 1ns/100ps

module ootbtb;
    logic           clk;
    logic           rst;
    logic           rstn;
    logic [31:0]    write_addr;
    logic [31:0]    write_data [1];
    logic [31:0]    read_data [1];

    axi4l_if #(
        .ADDR_WIDTH (32),
        .DATA_WIDTH (32)
    )
    axi4l (
        .aclk       (clk),
        .aresetn    (rstn)
    );

    wishbone_if #(
        .ADDR_WIDTH (32),
        .DATA_WIDTH (32)
    )
    wb (
        .clk    (clk),
        .rst    (rst)
    );

    // DUT (VHDL wrapper)
    WB2AXI4L_BRIDGE #(
        .ADDR_WIDTH (32),
        .DATA_WIDTH (32)
    )
    DUT (
        .aclk            (clk),
        .aresetn         (rstn),
        .wb_cyc          (wb.cyc),
        .wb_stb          (wb.stb),
        .wb_adr          (wb.addr),
        .wb_sel          (wb.sel),
        .wb_we           (wb.we),
        .wb_wdat         (wb.wdata),
        .wb_ack          (wb.ack),
        .wb_err          (wb.err),
        .wb_rty          (), // Unused
        .wb_stall        (wb.stall),
        .wb_int          (), // Unused
        .wb_rdat         (wb.rdata),
        .axi4l_awready   (axi4l.awready),
        .axi4l_wready    (axi4l.wready),
        .axi4l_bresp     (axi4l.bresp),
        .axi4l_bvalid    (axi4l.bvalid),
        .axi4l_arready   (axi4l.arready),
        .axi4l_rdata     (axi4l.rdata),
        .axi4l_rresp     (axi4l.rresp),
        .axi4l_rvalid    (axi4l.rvalid),
        .axi4l_awaddr    (axi4l.awaddr),
        .axi4l_awvalid   (axi4l.awvalid),
        .axi4l_wdata     (axi4l.wdata),
        .axi4l_wstrb     (axi4l.wstrb),
        .axi4l_wvalid    (axi4l.wvalid),
        .axi4l_bready    (axi4l.bready),
        .axi4l_araddr    (axi4l.araddr),
        .axi4l_arvalid   (axi4l.arvalid),
        .axi4l_rready    (axi4l.rready)
    );

    // Clock and reset
    initial begin
        clk = 1'b0;
        forever begin
            #2.0 clk = ~clk;
        end
    end

    initial begin
        rstn <= 1'b0;
        repeat(10) @(posedge clk);
        rstn <= 1'b1;
    end

    assign rst = ~rstn;

    initial begin
        axi4l.start_slave();
    end

    // Stimuli
    initial begin
	    wb.set_idle();

        @(posedge rstn);
        repeat(1e1) @(posedge clk);

        // Single Write followed by single Read
        for(int test = 0; test < 16; test++) begin
            write_addr = 32'd0 + (test << 2);
            write_data[0] = $random;
            wb.write_data(write_addr, write_data);

            repeat(4) @(posedge clk);
            wb.read_data(write_addr, read_data);
        end

        repeat(1e3) @(posedge clk);
        $finish;
   end

   initial begin
       $dumpfile("ootbtb.vcd");
       $dumpvars(0, ootbtb);
   end
endmodule
