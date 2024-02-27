// Wishbone protocol utility package
package wb_pkg;
endpackage

// Wishbone interface
interface wb_if
#(
    parameter ADDR_WIDTH    = 32,
    parameter DATA_WIDTH    = 32
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
    logic [DATA_WIDTH/8-1:0]    sel;
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

    // Zero out all control signals of a Master interface
    task set_master_idle();
        cyc <= 1'b0;
        stb <= 1'b0;
    endtask

    // Zero out all control signals of a Slave interface
    task set_slave_idle();
        stall <= 1'b0;
        ack <= 1'b0;
        err <= 1'b0;
    endtask

    // Write access
    task write_data(
        input logic [ADDR_WIDTH-1:0]    write_addr,
        input logic [DATA_WIDTH-1:0]    write_data
    );

        // Send Write
        @(posedge clk);
        cyc <= 1'b1;
        stb <= 1'b1;
        sel <= {(DATA_WIDTH/8){1'b1}};
        addr <= write_addr;
        we <= 1'b1;
        wdata <= write_data;

        // Wait for ack
        forever begin
            @(posedge clk);
            if(cyc && stb && ack) break;
        end

        cyc <= 1'b0;
        stb <= 1'b0;
    endtask

    // Read access
    task read_data(
        input logic [ADDR_WIDTH-1:0]    read_addr,
        output logic [DATA_WIDTH-1:0]   read_data
    );

        // Send Read
        @(posedge clk);
        cyc <= 1'b1;
        stb <= 1'b1;
        sel <= {(DATA_WIDTH/8){1'b1}};
        addr <= read_addr;
        we <= 1'b0;

        // Wait for ack
        forever begin
            @(posedge clk);
            if(cyc && stb && ack) break;
        end
        read_data <= rdata;

        @(posedge clk);
        cyc <= 1'b0;
        stb <= 1'b0;
        @(posedge clk);
    endtask
endinterface
