.PHONY: show_config clean

# Reference network configuration file specs
INI_FILE = ../../model/neural_network/trained_network/config.ini

# Retrieve design configuration from trained network
FP_WIDTH := $(shell grep -w "fp_width" $(INI_FILE) | awk '{print $$3}')
FP_FRAC := $(shell grep -w "fp_frac" $(INI_FILE) | awk '{print $$3}')
GRID_SIDE := $(shell grep -w "boulder" $(INI_FILE) | awk '{print $$3}' | sed -nE 's/^.*_g([0-9]+).json/\1/p')
NUM_INPUTS := $(shell echo "$(GRID_SIDE) * $(GRID_SIDE)" | bc)
HL_NEURONS := $(shell grep -w "hl_neurons" $(INI_FILE) | awk '{print $$3}')
OL_NEURONS := $(shell grep -w "ol_neurons" $(INI_FILE) | awk '{print $$3}')
HL_SCI_ADDR_WIDTH := $(shell python3 -c "import math; print(math.ceil(math.log2($(NUM_INPUTS)+1)))")
OL_SCI_ADDR_WIDTH := $(shell python3 -c "import math; print(math.ceil(math.log2($(HL_NEURONS)+1)))")

# Optionals to be passed to COCOTB's Makefile
WAVES ?= 0

# Print configuration
show_config:
	@echo "cnfg: Network configuration"
	@echo "cnfg:    INI file: $(INI_FILE)"
	@echo "cnfg:    Fixed-point ($(FP_WIDTH),$(FP_FRAC))"
	@echo "cnfg:    Grid size: $(GRID_SIDE)"
	@echo "cnfg:    Number of inputs: $(NUM_INPUTS)"
	@echo "cnfg:    Number of outputs: $(NUM_OUTPUTS)"

# Available tests, each one has its own options
test_fixed_point_act_fun:
	$(MAKE) -C tests -f Makefile.verilator TOPLEVEL=FIXED_POINT_ACT_FUN WAVES=$(WAVES) EXTRA_ARGS+="-GWIDTH=$(FP_WIDTH) -GFRAC_BITS=$(FP_FRAC)"

test_hidden_neuron:
	$(MAKE) -C tests -f Makefile.verilator MODULE=test_neuron TOPLEVEL=HL_NEURON WAVES=$(WAVES) EXTRA_ARGS+="-GWIDTH=$(FP_WIDTH) -GFRAC_BITS=$(FP_FRAC) -GNUM_INPUTS=$(NUM_INPUTS)"

test_output_neuron:
	$(MAKE) -C tests -f Makefile.verilator MODULE=test_neuron TOPLEVEL=OL_NEURON WAVES=$(WAVES) EXTRA_ARGS+="-GWIDTH=$(FP_WIDTH) -GFRAC_BITS=$(FP_FRAC) -GNUM_INPUTS=$(HL_NEURONS)"

test_hl_sequencer:
	$(MAKE) -C tests -f Makefile.verilator TOPLEVEL=SEQUENCER WAVES=$(WAVES) EXTRA_ARGS+="-GWIDTH=$(FP_WIDTH) -GNUM_INPUTS=$(NUM_INPUTS)"

test_ol_sequencer:
	$(MAKE) -C tests -f Makefile.verilator TOPLEVEL=SEQUENCER WAVES=$(WAVES) EXTRA_ARGS+="-GWIDTH=$(FP_WIDTH) -GNUM_INPUTS=$(HL_NEURONS)"

test_wb2sci_bridge:
	$(MAKE) -C tests -f Makefile.verilator TOPLEVEL=WB2SCI_BRIDGE WAVES=$(WAVES) EXTRA_ARGS+="-GADDR_WIDTH=32 -GDATA_WIDTH=8 -GNUM_HL_NEURONS=$(HL_NEURONS) -GNUM_OL_NEURONS=$(OL_NEURONS) -GHL_ADDR_WIDTH=$(HL_SCI_ADDR_WIDTH) -GOL_ADDR_WIDTH=$(OL_SCI_ADDR_WIDTH)"

clean:
	$(MAKE) -C tests -f Makefile.verilator purge
	$(MAKE) -C tests -f Makefile.icarus purge
