`timescale 1ns/100ps

// Import regpool defines
`include "CORTEZ_REGPOOL.vh"

// For printout
`define SCALING (2.0**-`FIXED_POINT_FRAC_BITS)

module ootbtb;
    // Signals
    reg         clk;
    reg         rst;
    reg         cyc;
    reg         stb;
    reg         we;
    reg [31:0]  addr;
    reg [7:0]   wdata;
    reg         sel;
    wire        stall;
    wire        ack;
    wire [7:0]  rdata;
    wire        err;
    wire [3:0]  ss_anodes;
    wire [7:0]  ss_segments;
    wire [7:0]  leds;

    // File read
    integer     fid;
    reg [7:0]   fid_read;

    // Clock and reset
    initial begin
        clk = 1'b0;
        forever begin
            #2.0 clk = ~clk;
        end
    end

    initial begin
        rst <= 1'b1;
        repeat(10) @(posedge clk);
        rst <= 1'b0;
    end

    // DUT
    NETWORK_TOP DUT (
        .CLK            (clk),
        .RST            (rst),
        .CYC            (cyc),
        .STB            (stb),
        .WE             (we),
        .ADDR           (addr),
        .WDATA          (wdata),
        .SEL            (sel),
        .STALL          (stall),
        .ACK            (ack),
        .RDATA          (rdata),
        .ERR            (err),
        .SS_ANODES      (ss_anodes),
        .SS_SEGMENTS    (ss_segments),
        .LEDS           (leds)
    );

    initial begin
        @(negedge rst);
        repeat(1e1) @(posedge clk);

    //    // Load hidden layer weights
    //    fid = $fopen("hidden_layer_weights_fp_hex.txt", "r");
    //    write_addr = `HL_WEIGHTS_0_0_OFFSET;
    //    for(int odx = 0; odx < `NUM_HL_NODES; odx++) begin
    //        for(int idx = 0; idx < `NUM_INPUTS; idx++) begin
    //            $fscanf(fid, "0x%h,", fid_read);
    //            write_data[0] = fid_read; 
    //            axi4l_port.write_data(write_addr, write_data);
    //            write_addr = write_addr + 8'd4;
    //        end
    //    end

    //    // Load hidden layer bias
    //    fid = $fopen("hidden_layer_bias_fp_hex.txt", "r");
    //    write_addr = `HL_BIAS_0_OFFSET;
    //    for(int odx = 0; odx < `NUM_HL_NODES; odx++) begin
    //        $fscanf(fid, "0x%h,", fid_read);
    //        write_data[0] = fid_read; 
    //        axi4l_port.write_data(write_addr, write_data);
    //        write_addr = write_addr + 8'd4;
    //    end

    //    // Load output layer weights
    //    fid = $fopen("output_layer_weights_fp_hex.txt", "r");
    //    write_addr = `OL_WEIGHTS_0_0_OFFSET;
    //    for(int odx = 0; odx < `NUM_OL_NODES; odx++) begin
    //        for(int idx = 0; idx < `NUM_HL_NODES; idx++) begin
    //            $fscanf(fid, "0x%h,", fid_read);
    //            write_data[0] = fid_read; 
    //            axi4l_port.write_data(write_addr, write_data);
    //            write_addr = write_addr + 8'd4;
    //        end
    //    end

    //    // Load output layer bias
    //    fid = $fopen("output_layer_bias_fp_hex.txt", "r");
    //    write_addr = `OL_BIAS_0_OFFSET;
    //    for(int odx = 0; odx < `NUM_OL_NODES; odx++) begin
    //        $fscanf(fid, "0x%h,", fid_read);
    //        write_data[0] = fid_read; 
    //        axi4l_port.write_data(write_addr, write_data);
    //        write_addr = write_addr + 8'd4;
    //    end

    //    // Try the network
    //    write_data[0] = 8'h20; 
    //    write_addr = `INPUT_GRID_0_OFFSET;
    //    axi4l_port.write_data(write_addr, write_data);
    //    write_addr = `INPUT_GRID_1_OFFSET;
    //    axi4l_port.write_data(write_addr, write_data);
    //    write_addr = `INPUT_GRID_2_OFFSET;
    //    axi4l_port.write_data(write_addr, write_data);

    //    write_addr = `INPUT_GRID_3_OFFSET;
    //    axi4l_port.write_data(write_addr, write_data);
    //    write_addr = `INPUT_GRID_4_OFFSET;
    //    write_data[0] = 8'he0;
    //    axi4l_port.write_data(write_addr, write_data);
    //    write_addr = `INPUT_GRID_5_OFFSET;
    //    write_data[0] = 8'h20;
    //    axi4l_port.write_data(write_addr, write_data);

    //    write_addr = `INPUT_GRID_6_OFFSET;
    //    axi4l_port.write_data(write_addr, write_data);
    //    write_addr = `INPUT_GRID_7_OFFSET;
    //    axi4l_port.write_data(write_addr, write_data);
    //    write_addr = `INPUT_GRID_8_OFFSET;
    //    axi4l_port.write_data(write_addr, write_data);

    //    write_data[0] = 8'h02;
    //    write_addr = `CORE_CTRL_OFFSET;
    //    axi4l_port.write_data(write_addr, write_data);

        repeat(1e3) @(posedge clk);
        $finish;
    end

    initial begin
        $dumpfile("ootbtb.vcd");
        $dumpvars(0, ootbtb);
    end
endmodule
