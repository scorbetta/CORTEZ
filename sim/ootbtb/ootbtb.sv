`timescale 1ns/100ps

// Import network configuration
`include "NETWORK_CONFIG.svh"
// Import regpool defines
`include "CORTEZ_REGPOOL.svh"

// For printout
`define SCALING (2.0**-`FIXED_POINT_FRAC_BITS)

module ootbtb;
    logic           clk;
    logic           rstn;
    logic [31:0]    write_addr;
    logic [7:0]     write_data [1];
    logic [31:0]    read_addr;
    logic [7:0]     read_data [1];
    logic [3:0]     ss_anodes;
    logic [7:0]     ss_segments;
    logic [7:0]     leds;

    axi4l_if #(
        .ADDR_WIDTH (32),
        .DATA_WIDTH (8)
    )
    axi4l_port (
        .aclk       (clk),
        .aresetn    (rstn)
    );

    // File read
    integer         fid;
    logic [7:0]    fid_read;

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

    // DUT
    NETWORK_TOP DUT (
        .CLK            (clk),
        .RSTN           (rstn),
        .AXI4L_PORT     (axi4l_port),
        .SS_ANODES      (ss_anodes),
        .SS_SEGMENTS    (ss_segments),
        .LEDS           (leds)
    );

    initial begin
        axi4l_port.set_idle();
        @(posedge rstn);
        repeat(1e1) @(posedge clk);

        // Load hidden layer weights
        fid = $fopen("hidden_layer_weights_fp_hex.txt", "r");
        write_addr = `HL_WEIGHTS_0_0_OFFSET;
        for(int odx = 0; odx < `NUM_HL_NODES; odx++) begin
            for(int idx = 0; idx < `NUM_INPUTS; idx++) begin
                $fscanf(fid, "0x%h,", fid_read);
                write_data[0] = fid_read; 
                axi4l_port.write_data(write_addr, write_data);
                write_addr = write_addr + 8'd4;
            end
        end

        // Load hidden layer bias
        fid = $fopen("hidden_layer_bias_fp_hex.txt", "r");
        write_addr = `HL_BIAS_0_OFFSET;
        for(int odx = 0; odx < `NUM_HL_NODES; odx++) begin
            $fscanf(fid, "0x%h,", fid_read);
            write_data[0] = fid_read; 
            axi4l_port.write_data(write_addr, write_data);
            write_addr = write_addr + 8'd4;
        end

        // Load output layer weights
        fid = $fopen("output_layer_weights_fp_hex.txt", "r");
        write_addr = `OL_WEIGHTS_0_0_OFFSET;
        for(int odx = 0; odx < `NUM_OL_NODES; odx++) begin
            for(int idx = 0; idx < `NUM_HL_NODES; idx++) begin
                $fscanf(fid, "0x%h,", fid_read);
                write_data[0] = fid_read; 
                axi4l_port.write_data(write_addr, write_data);
                write_addr = write_addr + 8'd4;
            end
        end

        // Load output layer bias
        fid = $fopen("output_layer_bias_fp_hex.txt", "r");
        write_addr = `OL_BIAS_0_OFFSET;
        for(int odx = 0; odx < `NUM_OL_NODES; odx++) begin
            $fscanf(fid, "0x%h,", fid_read);
            write_data[0] = fid_read; 
            axi4l_port.write_data(write_addr, write_data);
            write_addr = write_addr + 8'd4;
        end

        // Try the network
        write_data[0] = 8'h20; 
        write_addr = `INPUT_GRID_0_OFFSET;
        axi4l_port.write_data(write_addr, write_data);
        write_addr = `INPUT_GRID_1_OFFSET;
        axi4l_port.write_data(write_addr, write_data);
        write_addr = `INPUT_GRID_2_OFFSET;
        axi4l_port.write_data(write_addr, write_data);

        write_addr = `INPUT_GRID_3_OFFSET;
        axi4l_port.write_data(write_addr, write_data);
        write_addr = `INPUT_GRID_4_OFFSET;
        write_data[0] = 8'he0;
        axi4l_port.write_data(write_addr, write_data);
        write_addr = `INPUT_GRID_5_OFFSET;
        write_data[0] = 8'h20;
        axi4l_port.write_data(write_addr, write_data);

        write_addr = `INPUT_GRID_6_OFFSET;
        axi4l_port.write_data(write_addr, write_data);
        write_addr = `INPUT_GRID_7_OFFSET;
        axi4l_port.write_data(write_addr, write_data);
        write_addr = `INPUT_GRID_8_OFFSET;
        axi4l_port.write_data(write_addr, write_data);

        write_data[0] = 8'h02;
        write_addr = `CORE_CTRL_OFFSET;
        axi4l_port.write_data(write_addr, write_data);

        repeat(1e3) @(posedge clk);
        $finish;
   end

   initial begin
       $dumpfile("ootbtb.vcd");
       $dumpvars(0, ootbtb);
   end
endmodule
