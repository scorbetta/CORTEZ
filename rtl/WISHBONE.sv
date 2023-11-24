// Wishbone interface
interface wishbone_if
#(
    parameter DATA_WIDTH    = 32,
    parameter ADDR_WIDTH    = 32
)
(
    input   clk,
    input   rst
);

	logic                       cyc;
	logic                       stb;
	logic                       we;
	logic [ADDR_WIDTH-1:0]      addr;
	logic [DATA_WIDTH-1:0]      wdata;
	logic [(DATA_WIDTH/8)-1:0]  sel;
	logic                       stall;
	logic                       ack;
    logic [DATA_WIDTH-1:0]      rdata;
	logic                       err;

    modport master (
        input   clk,
        input   rst,
	    output  cyc,
	    output  stb,
	    output  we,
	    output  addr,
	    output  wdata,
	    output  sel,
	    input   stall,
	    input   ack,
        input   rdata,
	    input   err
    );

    modport slave (
        input   clk,
        input   rst,
	    input   cyc,
	    input   stb,
	    input   we,
	    input   addr,
	    input   wdata,
	    input   sel,
	    output  stall,
	    output  ack,
        output  rdata,
	    output  err
    );

    modport monitor (
        input   clk,
        input   rst,
	    input   cyc,
	    input   stb,
	    input   we,
	    input   addr,
	    input   wdata,
	    input   sel,
	    input   stall,
	    input   ack,
        input   rdata,
	    input   err
    );

`ifdef DISABLE_TASKS
`else
    // Zero out all control signals
    task set_idle();
        @(posedge clk);
        cyc <= 1'b0;
        stb <= 1'b0;
        we <= 1'b0;
        sel <= {(DATA_WIDTH/8){1'b0}};
    endtask

    // Write access
    task write_data(
        input logic [ADDR_WIDTH-1:0]    write_addr,
        input logic [DATA_WIDTH-1:0]    write_data []
    );

        // Open transaction
        we <= 1'b1;
        stb <= 1'b1;
        cyc <= 1'b1;
        wdata <= write_data[0];
        addr <= write_addr;

        // Wait for ack
        forever begin
            @(posedge clk);
            if(stb && ack) begin
                break;
            end
        end

        // Close transaction
        stb <= 1'b0;
        cyc <= 1'b0;

        // Shim delay
        @(posedge clk);
    endtask

    // Read access
    task read_data(
        input logic [ADDR_WIDTH-1:0]    read_addr,
        output logic [DATA_WIDTH-1:0]   read_data []
    );

        // Open transaction
        we <= 1'b0;
        stb <= 1'b1;
        cyc <= 1'b1;
        addr <= read_addr;

        // Wait for ack
        forever begin
            @(posedge clk);
            if(stb && ack) begin
                read_data = new [1](read_data);
                read_data[0] = rdata;
                break;
            end
        end

        // Close transaction
        stb <= 1'b0;
        cyc <= 1'b0;

        // Shim delay
        @(posedge clk);
    endtask
`endif /* DISABLE_TASKS */
endinterface
