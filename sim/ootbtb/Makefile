.PHONY: clean sim comp

# List of sources
SOURCES = \
	../../rtl/FIXED_POINT_ADD.v \
	../../rtl/FIXED_POINT_ABS.v \
	../../rtl/FIXED_POINT_MUL.v \
	../../rtl/FIXED_POINT_CHANGE_SIGN.v \
	../../rtl/FIXED_POINT_COMP.v \
	../../rtl/FIXED_POINT_ACC.v \
	../../rtl/FIXED_POINT_ACT_FUN.v \
	../../rtl/NEURON.v \
	../../rtl/SHIM_ALIGN.v \
	../../rtl/LAYER.v \
	../../rtl/NETWORK.v \
	../../rtl/../grogu/grogu.git/bundle/RW_REG.v \
	../../rtl/../grogu/grogu.git/bundle/RO_REG.v \
	../../rtl/../grogu/grogu.git/bundle/DELTA_REG.v \
	../../rtl/../grogu/grogu.git/bundle/AXIL2NATIVE.v \
	../../rtl/../grogu/grogu.gen/CORTEZ_REGPOOL/rtl/CORTEZ_REGPOOL.v \
	../../rtl/EDGE_DETECTOR.v \
	../../rtl/LEDS_SWINGER.v \
	../../rtl/WB2AXI4L_BRIDGE.v \
	../../rtl/NETWORK_TOP.v

# Launch GUI and control simulation interactively
INTERACTIVE ?= 0

# Constants
DATA_WIDTH ?= 8
NUM_INPUTS ?= 9
NUM_HL_NODES ?= 6
NUM_OL_NODES ?= 3

VSIM_ARGS = -32
ifeq ($(INTERACTIVE),0)
VSIM_ARGS += -batch -do "run -all; quit"
endif

all: sim

sim: comp
	vsim $(VSIM_ARGS) ootbtb

comp: $(SOURCES) ootbtb.sv WISHBONE.sv
	vlog -32 -noincr \
		+incdir+../../rtl +incdir+../../grogu/grogu.gen/CORTEZ_REGPOOL/rtl +incdir+../../grogu -timescale=1ns/100ps \
		+define+DATA_WIDTH=$(DATA_WIDTH) +define+NUM_INPUTS=$(NUM_INPUTS) +define+NUM_HL_NODES=$(NUM_HL_NODES) +define+NUM_OL_NODES=$(NUM_OL_NODES) \
		-sv -svfilesuffix=sv -sv17compat \
		$?

clean:
	rm -fR *.vcd work/

