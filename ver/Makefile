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
	$(MAKE) -C tests TOPLEVEL=FIXED_POINT_ACT_FUN WAVES=$(WAVES) EXTRA_ARGS+="-GWIDTH=$(FP_WIDTH) -GFRAC_BITS=$(FP_FRAC)"

test_hidden_neuron:
	$(MAKE) -C tests TOPLEVEL=NEURON WAVES=$(WAVES) EXTRA_ARGS+="-GWIDTH=$(FP_WIDTH) -GFRAC_BITS=$(FP_FRAC) -GNUM_INPUTS=$(NUM_INPUTS)"

test_output_neuron:
	$(MAKE) -C tests TOPLEVEL=NEURON WAVES=$(WAVES) EXTRA_ARGS+="-GWIDTH=$(FP_WIDTH) -GFRAC_BITS=$(FP_FRAC) -GNUM_INPUTS=$(HL_NEURONS)"

test_hidden_layer:
	$(MAKE) -C tests TOPLEVEL=LAYER WAVES=$(WAVES) EXTRA_ARGS+="-GWIDTH=$(FP_WIDTH) -GFRAC_BITS=$(FP_FRAC) -GNUM_INPUTS=$(NUM_INPUTS) -GNUM_OUTPUTS=$(HL_NEURONS)"

test_output_layer:
	$(MAKE) -C tests TOPLEVEL=LAYER WAVES=$(WAVES) EXTRA_ARGS+="-GWIDTH=$(FP_WIDTH) -GFRAC_BITS=$(FP_FRAC) -GNUM_INPUTS=$(HL_NEURONS) -GNUM_OUTPUTS=$(OL_NEURONS)"

test_network:
	$(MAKE) -C tests TOPLEVEL=NETWORK WAVES=$(WAVES) EXTRA_ARGS+="-GFP_WIDTH=$(FP_WIDTH) -GFP_FRAC=$(FP_FRAC) -GNUM_INPUTS=$(NUM_INPUTS) -GHL_NEURONS=$(HL_NEURONS) -GOL_NEURONS=$(OL_NEURONS)"

test_network_top:
	$(MAKE) -C tests TOPLEVEL=NETWORK_TOP WAVES=$(WAVES) EXTRA_ARGS+="-GWIDTH=$(FP_WIDTH) -GFRAC_BITS=$(FP_FRAC)"

clean:
	$(MAKE) -C tests purge
