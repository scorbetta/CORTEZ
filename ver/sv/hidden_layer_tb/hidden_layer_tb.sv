`timescale 1ns/100ps

`define NUM_INPUTS      16
`define NUM_OUTPUTS     8
`define WIDTH           8
`define FRAC_BITS       5
`define NUM_REGS        17

module hidden_layer_tb;
    logic                           clk;
    logic                           rstn;
    logic                           ready;
    logic [`WIDTH-1:0]              value_in;
    logic                           valid_in;
    logic [`NUM_OUTPUTS*`WIDTH-1:0] values_out;
    logic [`NUM_OUTPUTS-1:0]        valids_out;
    logic                           overflow;
    logic [$clog2(`NUM_REGS)-1:0]   addr;
    logic [`WIDTH-1:0]              wdata;
    logic [`WIDTH-1:0]              rdata;

    sci_if #(
        .NUM_PERIPHERALS    (`NUM_OUTPUTS),
        .ADDR_WIDTH         ($clog2(`NUM_REGS)),
        .DATA_WIDTH         (`WIDTH)
    )
    sci_if (
        .clk    (clk)
    );

    SIM_WIZARD #(
        .CLK_PERIOD     (2),
        .RESET_DELAY    (4),
        .INIT_PHASE     (0),
        .MAX_CYCLES     (1e4)
    )
    SIM_WIZARD (
        .USER_CLK   (clk),
        .USER_RST   (), // Unused
        .USER_RSTN  (rstn)
    );

    // DUT
    HIDDEN_LAYER #(
        .NUM_INPUTS     (`NUM_INPUTS),
        .NUM_OUTPUTS    (`NUM_OUTPUTS),
        .WIDTH          (`WIDTH),
        .FRAC_BITS      (`FRAC_BITS)
    )
    DUT (
        .CLK        (clk),
        .RSTN       (rstn),
        .SCI_CSN    (sci_if.csn),
        .SCI_REQ    (sci_if.req),
        .SCI_RESP   (sci_if.resp),
        .SCI_ACK    (sci_if.ack),
        .READY      (ready),
        .VALUE_IN   (value_in),
        .VALID_IN   (valid_in),
        .VALUES_OUT (values_out),
        .VALIDS_OUT (valids_out),
        .OVERFLOW   (overflow)
    );

    initial begin
        valid_in <= 1'b0;
        sci_if.m_set_idle();
        @(posedge rstn);
        repeat(10) @(posedge clk);

        // Initialize registers
        for(int rdx = 0; rdx < `NUM_REGS; rdx++) begin
            @(posedge clk);
            wdata = rdx[`WIDTH-1:0];
            addr = rdx[$clog2(`NUM_REGS)-1:0];
            sci_if.m_send_data(0, addr, wdata);
            repeat(4 + ($random % 10)) @(posedge clk);
        end

        // Readback registers and verify value
        for(int rdx = 0; rdx < `NUM_REGS; rdx++) begin
            @(posedge clk);
            addr = rdx[$clog2(`NUM_REGS)-1:0];
            sci_if.m_recv_data(0, addr, rdata);
            @(negedge clk);
            assert(rdata == rdx[`WIDTH-1:0]) else $fatal(1, "Readout mismatch from address 0x%h: 0x%0h, expected: 0x%0h", addr, rdata, rdx[`WIDTH-1:0]);
            repeat(4 + ($random % 10)) @(posedge clk);
        end

        repeat(1e2) @(posedge clk);
        $finish;
    end

`ifdef WAVES
    initial if(`WAVES == 1) begin
        $dumpfile("dump.vcd");
        $dumpvars(0, hidden_layer_tb);
    end
`endif /* WAVES */
endmodule
