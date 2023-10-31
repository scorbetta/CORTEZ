library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.genram_pkg.all;
use work.wishbone_pkg.all;
use work.axi_helpers_pkg.all;
use work.wb_helpers_pkg.all;

-- Wrapper for the Wishbone-to-AXI4 Lite bridge
entity WB2AXI4L_BRIDGE is
    generic (
        ADDR_WIDTH : integer    := 32;
        DATA_WIDTH : integer    := 32
    );

    port (
        aclk            : in std_logic;
        aresetn         : in std_logic;
        -- Wishbone Slave interface signals
        wb_cyc          : in std_logic;
        wb_stb          : in std_logic;
        wb_adr          : in std_logic_vector(ADDR_WIDTH-1 downto 0);
        wb_sel          : in std_logic_vector((ADDR_WIDTH/8)-1 downto 0);
        wb_we           : in std_logic;
        wb_wdat         : in std_logic_vector(DATA_WIDTH-1 downto 0);
        wb_ack          : out std_logic;
        wb_err          : out std_logic;
        wb_rty          : out std_logic;
        wb_stall        : out std_logic;
        wb_int          : out std_logic;
        wb_rdat         : out std_logic_vector(DATA_WIDTH-1 downto 0);
        -- AXI Master interface signals
        axi4l_awready   : in std_logic;
        axi4l_wready    : in std_logic;
        axi4l_bresp     : in std_logic_vector(1 downto 0);
        axi4l_bvalid    : in std_logic;
        axi4l_arready   : in std_logic;
        axi4l_rdata     : in std_logic_vector(DATA_WIDTH-1 downto 0);
        axi4l_rresp     : in std_logic_vector(1 downto 0);
        axi4l_rvalid    : in std_logic;
        axi4l_awaddr    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        axi4l_awvalid   : out std_logic;     
        axi4l_wdata     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        axi4l_wstrb     : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
        axi4l_wvalid    : out std_logic;
        axi4l_bready    : out std_logic;
        axi4l_araddr    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        axi4l_arvalid   : out std_logic;
        axi4l_rready    : out std_logic
    );
end entity;

architecture IMPLEMENTATION of WB2AXI4L_BRIDGE is
    signal s_wb_m2s_i     : t_wishbone_slave_in;
    signal s_wb_s2m_i     : t_wishbone_slave_out;
    signal m_axi_s2m_i    : t_axi4_s2m;
    signal m_axi_m2s_i    : t_axi4_m2s;

    component WishboneAXI_v0_2_M_AXI4_LITE is
        generic (
            C_WB_ADR_WIDTH      : integer;
            C_WB_DAT_WIDTH      : integer;
            C_M_AXI_ADDR_WIDTH  : integer;
            C_M_AXI_DATA_WIDTH  : integer
        );
        port (    
            aclk        : in std_logic;
            aresetn     : in std_logic;
            s_wb_m2s    : in  t_wishbone_slave_in;
            s_wb_s2m    : out t_wishbone_slave_out;
            m_axi_s2m   : in t_axi4_s2m;
            m_axi_m2s   : out t_axi4_m2s
        );
    end component;
begin
    -- Unpack records
    s_wb_m2s_i.cyc      <= wb_cyc;
    s_wb_m2s_i.stb      <= wb_stb;
    s_wb_m2s_i.adr      <= wb_adr;
    s_wb_m2s_i.sel      <= wb_sel;
    s_wb_m2s_i.we       <= wb_we;
    s_wb_m2s_i.dat      <= wb_wdat;
    wb_ack              <= s_wb_s2m_i.ack;
    wb_err              <= s_wb_s2m_i.err;
    wb_rty              <= s_wb_s2m_i.rty;
    wb_stall            <= s_wb_s2m_i.stall;
    wb_int              <= s_wb_s2m_i.int;
    wb_rdat             <= s_wb_s2m_i.dat;
    m_axi_s2m_i.awready <= axi4l_awready;
    m_axi_s2m_i.wready  <= axi4l_wready;
    m_axi_s2m_i.bresp   <= axi4l_bresp;
    m_axi_s2m_i.bvalid  <= axi4l_bvalid;
    m_axi_s2m_i.arready <= axi4l_arready;
    m_axi_s2m_i.rdata   <= axi4l_rdata;
    m_axi_s2m_i.rresp   <= axi4l_rresp;
    m_axi_s2m_i.rvalid  <= axi4l_rvalid;
    axi4l_awaddr        <= m_axi_m2s_i.awaddr;
    axi4l_awvalid       <= m_axi_m2s_i.awvalid;
    axi4l_wdata         <= m_axi_m2s_i.wdata;
    axi4l_wstrb         <= m_axi_m2s_i.wstrb;
    axi4l_wvalid        <= m_axi_m2s_i.wvalid;
    axi4l_bready        <= m_axi_m2s_i.bready;
    axi4l_araddr        <= m_axi_m2s_i.araddr;
    axi4l_arvalid       <= m_axi_m2s_i.arvalid;
    axi4l_rready        <= m_axi_m2s_i.rready;

    -- Wrapped instance
    WRAPPED_INSTANCES : WishboneAXI_v0_2_M_AXI4_LITE
        generic map (
            C_WB_ADR_WIDTH      => ADDR_WIDTH,
            C_WB_DAT_WIDTH      => DATA_WIDTH,
            C_M_AXI_ADDR_WIDTH  => ADDR_WIDTH,
            C_M_AXI_DATA_WIDTH  => DATA_WIDTH
        )
        port map (
            aclk        => aclk,
            aresetn     => aresetn,
            s_wb_m2s    => s_wb_m2s_i,
            s_wb_s2m    => s_wb_s2m_i,
            m_axi_s2m   => m_axi_s2m_i,
            m_axi_m2s   => m_axi_m2s_i
        );
end architecture;
