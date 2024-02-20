package sci_pkg;
endpackage

interface sci_if
#(
    parameter NUM_PERIPHERALS   = 1,
    parameter ADDR_WIDTH        = 4,
    parameter DATA_WIDTH        = 8
)
(
    input clk
);

    logic [NUM_PERIPHERALS-1:0] csn; // Active low
    logic                       req;
    wire                        resp; // Tri-state, must be  wire  
    wire                        ack; //

    modport master (
        input   clk,
        output  csn,
        output  req,
        input   resp,
        input   ack
    );

    modport slave (
        input   clk,
        input   csn,
        input   req,
        inout   resp,
        inout   ack
    );

    modport monitor (
        input   clk,
        input   csn,
        input   req,
        input   resp,
        input   ack
    );

    // Generate chip-select mask
    function logic [NUM_PERIPHERALS-1:0] get_mask (
        input int pid
    );
        assert((pid==-1) || (pid>=0 && pid<NUM_PERIPHERALS)) else $fatal(1, "Invalid PID: %0d, expected: {-1} U [%0d,%0d)", pid, 0, NUM_PERIPHERALS);
        get_mask = {NUM_PERIPHERALS{1'b1}};

        if(pid >= 0) begin
            get_mask[pid] = 1'b0;
        end
    endfunction

    // Put Master in idle
    task m_set_idle();
        csn <= get_mask(-1);
        req <= 1'bx;
    endtask

    // Write data
    task m_send_data(
        input int                       pid,
        input logic [ADDR_WIDTH-1:0]    addr,
        input logic [DATA_WIDTH-1:0]    data
    );

        // Verify prerequisites
        assert(csn == get_mask(-1)) else $fatal(1, "Unexpected sci.csn: 0x%0x, expected: 0x%0x", csn, get_mask(-1));
        assert(ack === 1'bz) else $fatal(1, "Unexpected sci.ack: 1'b%0b, expected: 1'bz", ack);
        assert(resp === 1'bz) else $fatal(1, "Unexpected sci.resp: 1'b%0b, expected: 1'bz", resp);

        // 1st phase: Write-not-Read
        @(negedge clk);
        csn <= get_mask(pid);
        req <= 1'b1;

        // 2nd phase: address, LSB first!
        for(int adx = 0; adx < ADDR_WIDTH; adx++) begin
            @(negedge clk);
            req <= addr[adx];
        end

        // 3rd phase: data, LSB first!
        for(int ddx = 0; ddx < DATA_WIDTH; ddx++) begin
            @(negedge clk);
            req <= data[ddx];
        end

        // 4th phase: wait ack then release bus
        while(!ack) @(negedge clk);
        csn <= get_mask(-1);
        @(negedge clk);
    endtask

    // Read data
    task m_recv_data(
        input int                       pid,
        input logic [ADDR_WIDTH-1:0]    addr,
        output logic [DATA_WIDTH-1:0]   data
    );

        // Verify prerequisites
        assert(csn == get_mask(-1)) else $fatal(1, "Unexpected sci.csn: 0x%0x, expected: 0x%0x", csn, get_mask(-1));
        assert(ack === 1'bz) else $fatal(1, "Unexpected sci.ack: 1'b%0b, expected: 1'bz", ack);
        assert(resp === 1'bz) else $fatal(1, "Unexpected sci.resp: 1'b%0b, expected: 1'bz", resp);

        // 1st phase: Write-not-Read
        @(negedge clk);
        csn <= get_mask(pid);
        req <= 1'b0;

        // 2nd phase: address, LSB first!
        for(int adx = 0; adx < ADDR_WIDTH; adx++) begin
            @(negedge clk);
            req <= addr[adx];
        end

        // 3rd phase: wait ack w/data, LSB first!
        while(!ack) @(negedge clk);
        for(int ddx = 0; ddx < DATA_WIDTH; ddx++) begin
            assert(ack === 1'b1) else $fatal(1, "Unexpected sci.ack during readout at beat %0d/%0d: 1'b%0b, expected: 1'b1", ddx+1, DATA_WIDTH, ack);
            data[ddx] <= resp;
            @(negedge clk);
        end

        // 4th phase: relase bus
        @(negedge clk);
        csn <= get_mask(-1);
    endtask
endinterface
