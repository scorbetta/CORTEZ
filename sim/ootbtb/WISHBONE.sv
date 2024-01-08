// Wishbone interface
interface wishbone
#(
    parameter DATA_WIDTH    = 32,
    parameter ADDR_WIDTH    = 32
)
(
    input   clk,
    input   rstn
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
        input   rstn,
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
        input   rstn,
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
        input   rstn,
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
    // Generic wait for event macro
    `define WAIT_CONDITION(a) \
        forever begin \
            @(posedge clk); \
            if(a) break; \
        end

   //@TBD // Start a simple Slave that continuously accepts incoming requests and generates responses. Up
   //@TBD // to 16 written values are remembered and sent back during Read accesses, useful for simple
   //@TBD // Write/Read tests
   //@TBD task start_slave();
   //@TBD     // Local cache
   //@TBD     logic [DATA_WIDTH-1:0] cache [16];

   //@TBD     // Wait out of reset
   //@TBD     @(posedge rstn);

   //@TBD     forever begin
   //@TBD         fork
   //@TBD             // Write address channel
   //@TBD             begin
   //@TBD                 awready <= 1'b0;
   //@TBD                 `WAIT_CONDITION(awvalid);
   //@TBD                 awready <= 1'b1;
   //@TBD                 @(posedge clk);
   //@TBD                 awready <= 1'b0;
   //@TBD             end

   //@TBD             // Write data channel
   //@TBD             begin
   //@TBD                 wready <= 1'b0;
   //@TBD                 `WAIT_CONDITION(wvalid);
   //@TBD                 wready <= 1'b1;
   //@TBD                 cache[awaddr[3:0]] <= wdata;
   //@TBD                 @(posedge clk);
   //@TBD                 wready <= 1'b0;
   //@TBD             end

   //@TBD             // Write response channel
   //@TBD             begin
   //@TBD                 bvalid <= 1'b0;
   //@TBD                 bresp <= 2'b00;
   //@TBD                 `WAIT_CONDITION(wvalid && wready);
   //@TBD                 bvalid <= 1'b1;
   //@TBD                 `WAIT_CONDITION(bvalid && bready);
   //@TBD                 bvalid <= 1'b0;
   //@TBD             end

   //@TBD             // Read address channel
   //@TBD             begin
   //@TBD                 arready <= 1'b0;
   //@TBD                 `WAIT_CONDITION(arvalid);
   //@TBD                 arready <= 1'b1;
   //@TBD                 @(posedge clk);
   //@TBD                 arready <= 1'b0;
   //@TBD             end

   //@TBD             // Read data and response channel
   //@TBD             begin
   //@TBD                 rvalid <= 1'b0;
   //@TBD                 rresp <= 2'b00;
   //@TBD                 `WAIT_CONDITION(arvalid && arready);
   //@TBD                 rvalid <= 1'b1;
   //@TBD                 rdata <= cache[araddr[3:0]];
   //@TBD                 `WAIT_CONDITION(rvalid && rready);
   //@TBD                 rvalid <= 1'b0;
   //@TBD             end
   //@TBD         join
   //@TBD     end
   //@TBD endtask

    // Zero out all control signals
    task set_idle();
        @(posedge clk);
        cyc <= 1'b0;
        stb <= 1'b0;
    endtask

    // Write access
    task write_data(
        input logic [ADDR_WIDTH-1:0]    write_addr,
        input logic [DATA_WIDTH-1:0]    write_data []
    );

        cyc <= 1'b0;
        stb <= 1'b0;

        // Send request
        @(posedge clk);
        cyc <= 1'b1;
        stb <= 1'b1;
        sel <= {DATA_WIDTH/8{1'b1}};
        we <= 1'b1;
        addr <= write_addr;
        wdata <= write_data[0];

        // Wait ack
        @(posedge ack);

        // Close transaction
        @(posedge clk);
        cyc <= 1'b0;
        stb <= 1'b0;

        // Shim delay
        @(posedge clk);
    endtask

    // Read access
    task read_data(
        input logic [ADDR_WIDTH-1:0]    read_addr,
        output logic [DATA_WIDTH-1:0]   read_data []
    );

        cyc <= 1'b0;
        stb <= 1'b0;

        // Send request
        @(posedge clk);
        cyc <= 1'b1;
        stb <= 1'b1;
        sel <= {DATA_WIDTH/8{1'b1}};
        we <= 1'b0;
        addr <= read_addr;

        // Wait ack
        @(posedge ack);
        @(negedge clk);
        read_data = new [1](read_data);
        read_data[0] = rdata;

        // Close transaction
        @(posedge clk);
        cyc <= 1'b0;
        stb <= 1'b0;

        // Shim delay
        @(posedge clk);

        // Shim delay
        @(posedge clk);
    endtask
`endif /* DISABLE_TASKS */
endinterface
