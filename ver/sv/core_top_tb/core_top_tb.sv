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
`include "CORE_REGFILE.vh"

// Derived constants
`define NUM_HL_REGS     (`HL_NEURON_REGFILE_BIAS_OFFSET-`HL_NEURON_REGFILE_WEIGHT_0_OFFSET+1)
`define HL_ADDR_WIDTH   ($clog2(`NUM_HL_REGS))
`define NUM_OL_REGS     (`OL_NEURON_REGFILE_BIAS_OFFSET-`OL_NEURON_REGFILE_WEIGHT_0_OFFSET+1)
`define OL_ADDR_WIDTH   ($clog2(`NUM_OL_REGS))

module core_top_tb;
    logic           clk;
    logic           rst;
    logic [7:0]     wdata;
    logic [7:0]     rdata;
    logic [31:0]    addr;
    logic           slave_select;
    logic           layer_select;
    logic [6:0]     neuron_select;
    logic [7:0]     register_select;
    integer         temp;
    integer         test_no;

    wb_if #(
        .ADDR_WIDTH (32),
        .DATA_WIDTH (`WIDTH)
    )
    wb_if (
        .clk    (clk),
        .rst    (rst)
    );

    SIM_WIZARD #(
        .CLK_PERIOD     (2),
        .RESET_DELAY    (4),
        .INIT_PHASE     (0),
        .MAX_CYCLES     (1e6)
    )
    SIM_WIZARD (
        .USER_CLK   (clk),
        .USER_RST   (rst),
        .USER_RSTN  () // Unused
    );

    // DUT
    CORE_TOP DUT (
        .CLK            (clk),
        .RST            (rst),
        .CYC            (wb_if.cyc),
        .STB            (wb_if.stb),
        .WE             (wb_if.we),
        .ADDR           (wb_if.addr),
        .WDATA          (wb_if.wdata),
        .SEL            (wb_if.sel),
        .STALL          (wb_if.stall),
        .ACK            (wb_if.ack),
        .RDATA          (wb_if.rdata),
        .ERR            (wb_if.err),
        .SS_ANODES      (), // Unused
        .SS_SEGMENTS    (), //
        .LEDS           ()  //
    );

    // Initialize all registers to either a debug value (and then read back) or to random values (no
    // read back in this case)
    task init_regs(input logic random_data);
        // Initialize hidden layer registers
        $display("info: Initializing hidden layer neurons");
        slave_select = 1'b1;
        layer_select = 1'b0;
        for(int ndx = 0; ndx < `HL_NEURONS; ndx++) begin
            neuron_select = ndx[6:0];
            for(int rdx = 0; rdx < `NUM_HL_REGS; rdx++) begin
                @(posedge clk);
                wdata = 32'd0 | rdx[`WIDTH-1:0];
                if(random_data) void'(randomize(wdata));
                register_select = rdx[7:0];
                addr = 32'd0 | { slave_select, { layer_select, neuron_select, register_select, 2'b00 } };
                wb_if.write_data(addr, wdata);
                repeat(4 + ($random % 10)) @(posedge clk);
            end
        end

        // Initialize output layer registers
        $display("info: Initializing output layer neurons");
        layer_select = 1'b1;
        for(int ndx = 0; ndx < `OL_NEURONS; ndx++) begin
            neuron_select = ndx[6:0];
            for(int rdx = 0; rdx < `NUM_OL_REGS; rdx++) begin
                @(posedge clk);
                wdata = 32'd0 | rdx[`WIDTH-1:0];
                if(random_data) void'(randomize(wdata));
                register_select = rdx[7:0];
                addr = 32'd0 | { slave_select, { layer_select, neuron_select, register_select, 2'b00 } };
                wb_if.write_data(addr, wdata);
                repeat(4 + ($random % 10)) @(posedge clk);
            end
        end

        if(!random_data) begin
            $display("info: Verifying values");

            // Readback registers and verify value
            layer_select = 1'b0;
            for(int ndx = 0; ndx < `HL_NEURONS; ndx++) begin
                neuron_select = ndx[6:0];
                for(int rdx = 0; rdx < `NUM_HL_REGS; rdx++) begin
                    @(posedge clk);
                    register_select = rdx[7:0];
                    addr = 32'd0 | { slave_select, { layer_select, neuron_select, register_select, 2'b00 } };
                    wb_if.read_data(addr, rdata);
                    @(negedge clk);
                    assert(rdata == rdx[`WIDTH-1:0]) else $fatal(1, "Readout mismatch from address 0x%h: 0x%0h, expected: 0x%0h", addr[`HL_ADDR_WIDTH-1:0], rdata, rdx[`WIDTH-1:0]);
                    repeat(4 + ($random % 10)) @(posedge clk);
                end
            end

            layer_select = 1'b1;
            for(int ndx = 0; ndx < `OL_NEURONS; ndx++) begin
                neuron_select = ndx[6:0];
                for(int rdx = 0; rdx < `NUM_OL_REGS; rdx++) begin
                    @(posedge clk);
                    register_select = rdx[7:0];
                    addr = 32'd0 | { slave_select, { layer_select, neuron_select, register_select, 2'b00 } };
                    wb_if.read_data(addr, rdata);
                    @(negedge clk);
                    assert(rdata == rdx[`WIDTH-1:0]) else $fatal(1, "Readout mismatch from address 0x%h: 0x%0h, expected: 0x%0h", addr[`OL_ADDR_WIDTH-1:0], rdata, rdx[`WIDTH-1:0]);
                    repeat(4 + ($random % 10)) @(posedge clk);
                end
            end
        end
    endtask

    // Write random data to debug registers in the Core regfile, then readback
    task test_db_regs();
        $display("info: Write/Read tests on Core debug registers");
        slave_select = 1'b0;
        for(int tdx = 0; tdx < 25; tdx++) begin
            // Write
            @(posedge clk);
            void'(randomize(wdata));
            temp = `CORE_REGFILE_DBUG_REG_0_OFFSET + ($random % 4);
            addr = 32'd0 | { slave_select, temp[14:0], 2'b00 };
            wb_if.write_data(addr, wdata);

            // Read
            repeat(4 + ($random % 10)) @(posedge clk);
            wb_if.read_data(addr, rdata);
            assert(rdata == wdata) else $fatal(1, "Readout mismatch from address 0x%h: 0x%0h, expected: 0x%0h", addr, rdata, wdata);
        end
    endtask

    // Write value to register in Core regfile
    task core_regfile_write(input logic [31:0] offset, input logic [`WIDTH-1:0] data);
        slave_select = 1'b1;
        addr = 32'd0 | { slave_select, offset[14:0], 2'b00 };
        wb_if.write_data(addr, data);
    endtask

    // Read value from register in Core regfile
    task core_regfile_read(input logic [31:0] offset, output logic [`WIDTH-1:0] data);
        slave_select = 1'b1;
        addr = 32'd0 | { slave_select, offset[14:0], 2'b00 };
        wb_if.read_data(addr, data);
    endtask

    // Wait for a solution to be ready, polling the register. Polling window is limited
    task wait_solution(input integer max_cycles);
        while(temp < max_cycles) begin
            @(posedge clk);
            core_regfile_read(`CORE_REGFILE_CORE_STATUS_OFFSET, rdata);
            if(rdata[0]) begin
                break;
            end
            else begin
                temp++;
            end
        end

        assert(temp != max_cycles) else $fatal(1, "Solution not found within sampling window");
    endtask

    initial begin
        wb_if.set_master_idle();
        @(negedge rst);
        repeat(10) @(posedge clk);

        // Reset Core
        $display("test: Core reset");
        core_regfile_write(`CORE_REGFILE_CORE_DEBUG_INFO_OFFSET, 8'h01);
        core_regfile_write(`CORE_REGFILE_CORE_CTRL_OFFSET, 8'h01);
        core_regfile_write(`CORE_REGFILE_CORE_CTRL_OFFSET, 8'h00);
        core_regfile_write(`CORE_REGFILE_CORE_DEBUG_INFO_OFFSET, 8'h02);

        // Init regs w/ random data and readback
        $display("test: Core initialization");
        core_regfile_write(`CORE_REGFILE_CORE_DEBUG_INFO_OFFSET, 8'h04);
        init_regs(1'b0);
        core_regfile_write(`CORE_REGFILE_CORE_DEBUG_INFO_OFFSET, 8'h08);
        core_regfile_write(`CORE_REGFILE_CORE_CTRL_OFFSET, 8'h04);

        // Test debug regs in core regfile
        $display("test: Core test via debug registers");
        core_regfile_write(`CORE_REGFILE_CORE_DEBUG_INFO_OFFSET, 8'h10);
        test_db_regs();

        // Stimuli
        for(test_no = 1; test_no <= `NUM_TESTS; test_no++) begin
            $display("test: Running test %0d/%0d", test_no, `NUM_TESTS);
            temp = 1 + ($random % 100);
            repeat(temp) @(posedge clk);

            // Write  *_INPUT_GRID_*  registers
            for(int idx = 0; idx < `NUM_INPUTS; idx++) begin
                void'(randomize(wdata));
                core_regfile_write(`CORE_REGFILE_INPUT_GRID_0_OFFSET + idx, wdata);
            end

            // Trigger network
            core_regfile_read(`CORE_REGFILE_CORE_CTRL_OFFSET, rdata);
            rdata[1] = 1'b1;
            core_regfile_write(`CORE_REGFILE_CORE_CTRL_OFFSET, rdata);
            rdata[1] = 1'b0;
            core_regfile_write(`CORE_REGFILE_CORE_CTRL_OFFSET, rdata);

            // Wait for solution
            wait_solution(1000);

            // Random shim delay
            temp = 0 + ($random % 100);
            repeat(temp) @(posedge clk);
        end

        core_regfile_write(`CORE_REGFILE_CORE_DEBUG_INFO_OFFSET, 8'h20);
        $display("test: PASS");
        $finish;
    end

`ifdef WAVES
    initial if(`WAVES == 1) begin
        $dumpfile("dump.vcd");
        $dumpvars(0, core_top_tb);
    end
`endif /* WAVES */
endmodule
