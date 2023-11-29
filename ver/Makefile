# COCOTB configuration
TOPLEVEL_LANG = verilog
SIM ?= verilator

# Design configuration
WIDTH ?= 8
FRAC_BITS ?= 3
NUM_INPUTS ?= 2
NUM_OUTPUTS ?= 2

# Prefix for change of hierarchy. Do *not* modify this line!
VERILOG_SOURCES = $(shell grep -E "\.[s]*v$$" ../rtl/rtl_sources.list | sed 's/^/\.\.\/rtl\//g' )

# Top-level module determines also test name
TOPLEVEL ?= FIXED_POINT_ABS
MODULE = test.test_$(shell echo $(TOPLEVEL) | tr 'A-Z' 'a-z')

# Miscellanea
RANDOM_SEED ?= 1697646161
SEED ?= $(RANDOM_SEED)
WAVES ?= 0

# Verilator general options
EXTRA_ARGS += -I../rtl -I../grogu -I../grogu/grogu.gen/CORTEZ_REGPOOL/rtl +1364-2005ext+v --autoflush --timing

# Design parameters
ifneq ($(TOPLEVEL),NETWORK)
ifneq ($(TOPLEVEL),NETWORK_TOP)
EXTRA_ARGS += -GWIDTH=$(WIDTH) -GFRAC_BITS=$(FRAC_BITS)
endif
endif

ifeq ($(TOPLEVEL),NEURON)
EXTRA_ARGS += -GNUM_INPUTS=$(NUM_INPUTS)
endif

ifeq ($(TOPLEVEL),LAYER)
EXTRA_ARGS += -GNUM_INPUTS=$(NUM_INPUTS) -GNUM_OUTPUTS=$(NUM_OUTPUTS)
endif

# Disable warnings
EXTRA_ARGS += -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC

ifeq ($(WAVES),1)
EXTRA_ARGS += --trace-fst --trace-structs
endif

# Include COCOTB Makefiles
include $(shell cocotb-config --makefiles)/Makefile.sim

# User-defined clean all
purge: clean
	find . -name __pycache__ -exec rm -fR {} +
