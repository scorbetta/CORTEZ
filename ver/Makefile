.PHONY: show_config clean

# Reference network configuration file specs
INI_FILE = ../model/neural_network/trained_network/config.ini

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
	$(MAKE) -C tests -f Makefile.verilator TOPLEVEL=NEURON WAVES=$(WAVES) EXTRA_ARGS+="-GWIDTH=$(FP_WIDTH) -GFRAC_BITS=$(FP_FRAC) -GNUM_INPUTS=$(NUM_INPUTS)"

test_output_neuron:
	$(MAKE) -C tests -f Makefile.verilator TOPLEVEL=NEURON WAVES=$(WAVES) EXTRA_ARGS+="-GWIDTH=$(FP_WIDTH) -GFRAC_BITS=$(FP_FRAC) -GNUM_INPUTS=$(HL_NEURONS)"

test_hidden_layer:
	$(MAKE) -C tests -f Makefile.icarus MODULE=test_layer TOPLEVEL=HIDDEN_LAYER COMPILE_ARGS+="-PHIDDEN_LAYER.WIDTH=$(FP_WIDTH) -PHIDDEN_LAYER.FRAC_BITS=$(FP_FRAC) -PHIDDEN_LAYER.NUM_INPUTS=$(NUM_INPUTS) -PHIDDEN_LAYER.NUM_OUTPUTS=$(HL_NEURONS)" SCI_ADDR_WIDTH=$(HL_SCI_ADDR_WIDTH)

test_output_layer:
	$(MAKE) -C tests -f Makefile.icarus MODULE=test_layer TOPLEVEL=OUTPUT_LAYER COMPILE_ARGS+="-POUTPUT_LAYER.WIDTH=$(FP_WIDTH) -POUTPUT_LAYER.FRAC_BITS=$(FP_FRAC) -POUTPUT_LAYER.NUM_INPUTS=$(HL_NEURONS) -POUTPUT_LAYER.NUM_OUTPUTS=$(OL_NEURONS)" SCI_ADDR_WIDTH=$(OL_SCI_ADDR_WIDTH)

test_network:
	$(MAKE) -C tests -f Makefile.icarus TOPLEVEL=NETWORK WAVES=$(WAVES) COMPILE_ARGS+="-PNETWORK.FP_WIDTH=$(FP_WIDTH) -PNETWORK.FP_FRAC=$(FP_FRAC) -PNETWORK.NUM_INPUTS=$(NUM_INPUTS) -PNETWORK.HL_NEURONS=$(HL_NEURONS) -PNETWORK.OL_NEURONS=$(OL_NEURONS)" HL_SCI_ADDR_WIDTH=$(HL_SCI_ADDR_WIDTH) OL_SCI_ADDR_WIDTH=$(OL_SCI_ADDR_WIDTH)

test_hl_sequencer:
	$(MAKE) -C tests -f Makefile.verilator TOPLEVEL=SEQUENCER WAVES=$(WAVES) EXTRA_ARGS+="-GWIDTH=$(FP_WIDTH) -GNUM_INPUTS=$(NUM_INPUTS)"

test_ol_sequencer:
	$(MAKE) -C tests -f Makefile.verilator TOPLEVEL=SEQUENCER WAVES=$(WAVES) EXTRA_ARGS+="-GWIDTH=$(FP_WIDTH) -GNUM_INPUTS=$(HL_NEURONS)"

clean:
	$(MAKE) -C tests -f Makefile.verilator purge
	$(MAKE) -C tests -f Makefile.icarus purge
