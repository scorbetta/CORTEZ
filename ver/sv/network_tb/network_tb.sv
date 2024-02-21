`timescale 1ns/100ps

`define NUM_INPUTS  16
`define HL_NEURONS  8
`define OL_NEURONS  5
`define WIDTH       8
`define FRAC_BITS   5
`define NUM_TESTS   1000

// Regs offsets
`include "HL_NEURON_REGFILE.vh"
`include "OL_NEURON_REGFILE.vh"

// Derived constants
`define NUM_HL_REGS     (`HL_NEURON_REGFILE_BIAS_OFFSET-`HL_NEURON_REGFILE_WEIGHT_0_OFFSET+1)
`define HL_ADDR_WIDTH   ($clog2(`NUM_HL_REGS))
`define NUM_OL_REGS     (`OL_NEURON_REGFILE_BIAS_OFFSET-`OL_NEURON_REGFILE_WEIGHT_0_OFFSET+1)
`define OL_ADDR_WIDTH   ($clog2(`NUM_OL_REGS))

module network_tb;
    logic                           clk;
    logic                           rstn;
    logic                           valid_in;
    logic [`OL_NEURONS*`WIDTH-1:0]  values_out;
    logic                           valid_out;
    logic                           overflow;
    logic [31:0]                    rdata;
    int                             wait_count;
    int                             temp;

    // Subject to randomization
    logic [31:0]                    addr;
    logic [31:0]                    wdata;
    logic [`NUM_INPUTS*`WIDTH-1:0]  values_in;

    sci_if #(
        .NUM_PERIPHERALS    (`HL_NEURONS+`OL_NEURONS)
    )
    sci_if (
        .clk    (clk)
    );

    SIM_WIZARD #(
        .CLK_PERIOD     (2),
        .RESET_DELAY    (4),
        .INIT_PHASE     (0),
        .MAX_CYCLES     (1e6)
    )
    SIM_WIZARD (
        .USER_CLK   (clk),
        .USER_RST   (), // Unused
        .USER_RSTN  (rstn)
    );

    // DUT
    NETWORK #(
        .FP_WIDTH   (`WIDTH),
        .FP_FRAC    (`FRAC_BITS),
        .NUM_INPUTS (`NUM_INPUTS),
        .HL_NEURONS (`HL_NEURONS),
        .OL_NEURONS (`OL_NEURONS)
    )
    DUT (
        .CLK        (clk),
        .RSTN       (rstn),
        .SCI_CSN    (sci_if.csn),
        .SCI_REQ    (sci_if.req),
        .SCI_RESP   (sci_if.resp),
        .SCI_ACK    (sci_if.ack),
        .VALUES_IN  (values_in),
        .VALID_IN   (valid_in),
        .VALUES_OUT (values_out),
        .VALID_OUT  (valid_out),
        .OVERFLOW   (overflow)
    );

    // Initialize all registers to either a debug value (and then read back) or to random values (no
    // read back in this case)
    task init_regs(input logic random_data);
        // Initialize hidden layer registers
        $display("info: Initializing hidden layer neurons");
        for(int ndx = 0; ndx < `HL_NEURONS; ndx++) begin
            for(int rdx = 0; rdx < `NUM_HL_REGS; rdx++) begin
                @(posedge clk);
                wdata = 32'd0 | rdx[`WIDTH-1:0];
                if(random_data) void'(randomize(wdata));
                addr = 32'd0 | rdx[`HL_ADDR_WIDTH-1:0];
                sci_if.m_send_data(ndx, `HL_ADDR_WIDTH, addr, `WIDTH, wdata);
                repeat(4 + ($random % 10)) @(posedge clk);
            end
        end

        // Initialize output layer registers
        $display("info: Initializing output layer neurons");
        for(int ndx = 0; ndx < `OL_NEURONS; ndx++) begin
            for(int rdx = 0; rdx < `NUM_OL_REGS; rdx++) begin
                @(posedge clk);
                wdata = 32'd0 | rdx[`WIDTH-1:0];
                if(random_data) void'(randomize(wdata));
                addr = 32'd0 | rdx[`OL_ADDR_WIDTH-1:0];
                sci_if.m_send_data(`HL_NEURONS+ndx, `OL_ADDR_WIDTH, addr, `WIDTH, wdata);
                repeat(4 + ($random % 10)) @(posedge clk);
            end
        end

        if(!random_data) begin
            $display("info: Verifying values");

            // Readback registers and verify value
            for(int ndx = 0; ndx < `HL_NEURONS; ndx++) begin
                for(int rdx = 0; rdx < `NUM_HL_REGS; rdx++) begin
                    @(posedge clk);
                    addr = 32'd0 | rdx[`HL_ADDR_WIDTH-1:0];
                    sci_if.m_recv_data(ndx, `HL_ADDR_WIDTH, addr, `WIDTH, rdata);
                    @(negedge clk);
                    assert(rdata[`WIDTH-1:0] == rdx[`WIDTH-1:0]) else $fatal(1, "Readout mismatch from address 0x%h: 0x%0h, expected: 0x%0h", addr[`HL_ADDR_WIDTH-1:0], rdata[`WIDTH-1:0], rdx[`WIDTH-1:0]);
                    repeat(4 + ($random % 10)) @(posedge clk);
                end
            end

            for(int ndx = 0; ndx < `OL_NEURONS; ndx++) begin
                for(int rdx = 0; rdx < `NUM_OL_REGS; rdx++) begin
                    @(posedge clk);
                    addr = 32'd0 | rdx[`OL_ADDR_WIDTH-1:0];
                    sci_if.m_recv_data(`HL_NEURONS+ndx, `OL_ADDR_WIDTH, addr, `WIDTH, rdata);
                    @(negedge clk);
                    assert(rdata[`WIDTH-1:0] == rdx[`WIDTH-1:0]) else $fatal(1, "Readout mismatch from address 0x%h: 0x%0h, expected: 0x%0h", addr[`OL_ADDR_WIDTH-1:0], rdata[`WIDTH-1:0], rdx[`WIDTH-1:0]);
                    repeat(4 + ($random % 10)) @(posedge clk);
                end
            end
        end
    endtask

    initial begin
        valid_in <= 1'b0;
        sci_if.m_set_idle();
        @(posedge rstn);
        repeat(10) @(posedge clk);

        // Init regs and readback
        init_regs(1'b0);

        // Init regs to random data
        init_regs(1'b1);

        // Stimuli
        for(int tdx = 1; tdx <= `NUM_TESTS; tdx++) begin
            $display("test: Running test %0d/%0d", tdx, `NUM_TESTS);
            void'(randomize(values_in));

            temp = 1 + ($random % 100);
            repeat(temp) @(posedge clk);
            valid_in <= 1'b1;
            @(posedge clk);
            valid_in <= 1'b0;

            // Bounded wait
            wait_count = 1000;
            while(1) begin
                @(negedge clk);
                if(valid_out || wait_count < 0) break;
                else wait_count--;
            end
            assert(wait_count != -1) else $fatal(1, "Bounded wait expired waiting for  valid_out");
            @(posedge clk);

            temp = 0 + ($random % 100);
            repeat(temp) @(posedge clk);
        end

        $finish;
    end

`ifdef WAVES
    initial if(`WAVES == 1) begin
        $dumpfile("dump.vcd");
        $dumpvars(0, network_tb);
    end
`endif /* WAVES */
endmodule
