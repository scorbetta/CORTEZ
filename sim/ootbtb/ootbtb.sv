`timescale 1ns/100ps

`include "CORTEZ_REGPOOL.vh"
`define AXI_BASE_ADDR 32'h3000_0000

module ootbtb;
    logic                   clk;
    logic                   rst;
    logic                   rstn;
    logic [31:0]            write_addr;
    logic [`DATA_WIDTH-1:0] write_data [1];
    logic [31:0]            read_addr;
    logic [`DATA_WIDTH-1:0] read_data [1];
    logic [3:0]             ss_anodes;
    logic [7:0]             ss_segments;
    logic [7:0]             leds;
    integer                 fid;
    logic [`DATA_WIDTH-1:0] fid_read;

    wishbone #(
        .DATA_WIDTH (`DATA_WIDTH),
        .ADDR_WIDTH (32)
    )
    wb_port (
        .clk    (clk),
        .rstn   (rstn)
    );

    // Clock and resets
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

    // DUT
    NETWORK_TOP DUT (
        .CLK            (clk),
        .RST            (rst),
        .CYC            (wb_port.cyc),
        .STB            (wb_port.stb),
        .WE             (wb_port.we),
        .ADDR           (wb_port.addr),
        .WDATA          (wb_port.wdata),
        .SEL            (wb_port.sel),
        .STALL          (wb_port.stall),
        .ACK            (wb_port.ack),
        .RDATA          (wb_port.rdata),
        .ERR            (wb_port.err),
        .SS_ANODES      (ss_anodes),
        .SS_SEGMENTS    (ss_segments),
        .LEDS           (leds)
    );

    initial begin
        wb_port.set_idle();
        @(posedge rstn);
        repeat(1e1) @(posedge clk);

        // Test connections through all 4 debug registers
        for(int ddx = `DBUG_REG_0_OFFSET; ddx < `DBUG_REG_3_OFFSET; ddx++) begin
            write_addr = `AXI_BASE_ADDR + (ddx << 2);

            // Write
            write_data[0] = $random;
            wb_port.write_data(write_addr, write_data);

            // Read
            repeat(10) @(posedge clk);
            wb_port.read_data(write_addr, read_data);
            assert(read_data[0] == write_data[0]) else $fatal;
        end

        // Load hidden layer weights
        fid = $fopen("hidden_layer_weights_fp_hex.txt", "r");
        write_addr = `AXI_BASE_ADDR + (`HL_WEIGHTS_0_0_OFFSET << 2);
        for(int odx = 0; odx < `NUM_HL_NODES; odx++) begin
            for(int idx = 0; idx < `NUM_INPUTS; idx++) begin
                $fscanf(fid, "0x%h,", fid_read);
                write_data[0] = fid_read; 
                wb_port.write_data(write_addr, write_data);
                write_addr = write_addr + 8'd4;
            end
        end

        // Load hidden layer bias
        fid = $fopen("hidden_layer_bias_fp_hex.txt", "r");
        write_addr = `AXI_BASE_ADDR + (`HL_BIAS_0_OFFSET << 2);
        for(int odx = 0; odx < `NUM_HL_NODES; odx++) begin
            $fscanf(fid, "0x%h,", fid_read);
            write_data[0] = fid_read; 
            wb_port.write_data(write_addr, write_data);
            write_addr = write_addr + 8'd4;
        end

        // Load output layer weights
        fid = $fopen("output_layer_weights_fp_hex.txt", "r");
        write_addr = `AXI_BASE_ADDR + (`OL_WEIGHTS_0_0_OFFSET << 2);
        for(int odx = 0; odx < `NUM_OL_NODES; odx++) begin
            for(int idx = 0; idx < `NUM_HL_NODES; idx++) begin
                $fscanf(fid, "0x%h,", fid_read);
                write_data[0] = fid_read; 
                wb_port.write_data(write_addr, write_data);
                write_addr = write_addr + 8'd4;
            end
        end

        // Load output layer bias
        fid = $fopen("output_layer_bias_fp_hex.txt", "r");
        write_addr = `AXI_BASE_ADDR + (`OL_BIAS_0_OFFSET << 2);
        for(int odx = 0; odx < `NUM_OL_NODES; odx++) begin
            $fscanf(fid, "0x%h,", fid_read);
            write_data[0] = fid_read; 
            wb_port.write_data(write_addr, write_data);
            write_addr = write_addr + 8'd4;
        end

        // Try the network
        //write_data[0] = 8'h20; 
        //write_addr = `AXI_BASE_ADDR + `INPUT_GRID_0_OFFSET;
        //wb_port.write_data(write_addr, write_data);
        //write_addr = `AXI_BASE_ADDR + `INPUT_GRID_1_OFFSET;
        //wb_port.write_data(write_addr, write_data);
        //write_addr = `AXI_BASE_ADDR + `INPUT_GRID_2_OFFSET;
        //wb_port.write_data(write_addr, write_data);

        //write_addr = `AXI_BASE_ADDR + `INPUT_GRID_3_OFFSET;
        //wb_port.write_data(write_addr, write_data);
        //write_addr = `AXI_BASE_ADDR + `INPUT_GRID_4_OFFSET;
        //write_data[0] = 8'he0;
        //wb_port.write_data(write_addr, write_data);
        //write_addr = `AXI_BASE_ADDR + `INPUT_GRID_5_OFFSET;
        //write_data[0] = 8'h20;
        //wb_port.write_data(write_addr, write_data);

        //write_addr = `AXI_BASE_ADDR + `INPUT_GRID_6_OFFSET;
        //wb_port.write_data(write_addr, write_data);
        //write_addr = `AXI_BASE_ADDR + `INPUT_GRID_7_OFFSET;
        //wb_port.write_data(write_addr, write_data);
        //write_addr = `AXI_BASE_ADDR + `INPUT_GRID_8_OFFSET;
        //wb_port.write_data(write_addr, write_data);

        //write_data[0] = 8'h02;
        //write_addr = `CORE_CTRL_OFFSET;
        //wb_port.write_data(write_addr, write_data);

        repeat(1e3) @(posedge clk);
        $finish;
   end

   initial begin
       $dumpfile("ootbtb.vcd");
       $dumpvars(0, ootbtb);
   end
endmodule
