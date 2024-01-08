#!/usr/bin/bash

# This script performs the entire CORTEZ design flow using configuration constants defined in this
# script:
#
#   1. A Neural Network model is created, trained and validated using Python (assets from the
#    model/neural_network/  folder)
#   2. A proper piecewise approximation of the tanh() function is selected (assets from the
#    model/piecewise_approximation/  folder)
#   3. The top-level RTL code is created.


#---- CONFIGURATION -------------------------------------------------------------------------------

# Network architecture. The value of  OL_NEURONS  determines the number of characters to recognize
HL_NEURONS=10
OL_NEURONS=5

# Fixed-point
FP_WIDTH=8
FP_FRAC=5

# Input problem grid size (one side)
GRID_SIZE=5

# Network training configuration
MAX_NOISY_PIXELS=3
TRAINING_LEN=100
TEST_LEN=200
EPOCHS=1000
ALPHA=0.01

# Base address of register map, over AXI4 Lite bus (use Verilog syntax)
AXI_BASE_ADDR="32'h3000_0000"

# Miscellanea, don't touch!
BLUE='\033[0;34m'
NONE='\033[0m'
input_size=$(( $GRID_SIZE * $GRID_SIZE ))


#---- NEURAL NETWORK ------------------------------------------------------------------------------

pushd model/neural_network >/dev/null
    # Create ini file
    echo -e "${BLUE}info: Generating configuration file${NONE}"
    cp config.ini.template config.ini
    sed -i "s/__HL_NEURONS__/$HL_NEURONS/g" config.ini
    sed -i "s/__OL_NEURONS__/$OL_NEURONS/g" config.ini
    sed -i "s/__FP_WIDTH__/$FP_WIDTH/g" config.ini
    sed -i "s/__FP_FRAC__/$FP_FRAC/g" config.ini
    sed -i "s/__GRID_SIZE__/$GRID_SIZE/g" config.ini
    sed -i "s/__MAX_NOISY_PIXELS__/$MAX_NOISY_PIXELS/g" config.ini
    sed -i "s/__TRAINING_LEN__/$TRAINING_LEN/g" config.ini
    sed -i "s/__TEST_LEN__/$TEST_LEN/g" config.ini
    sed -i "s/__EPOCHS__/$EPOCHS/g" config.ini
    sed -i "s/__ALPHA__/$ALPHA/g" config.ini

    # Run training
    echo -e "${BLUE}info: Training the network${NONE}"
    ./bpn.py --train-network | tee bpn.train.log

    # Run testing
    echo -e "${BLUE}info: Testing the network${NONE}"
    ./bpn.py --test-network | tee bpn.test.log

    # Copy files to deploy folder
    cp config.ini trained_network
    cp hidden_layer_bias_fp_hex.txt trained_network
    cp hidden_layer_bias_fp.txt trained_network
    cp hidden_layer_bias.txt trained_network
    cp hidden_layer_weights_fp_hex.txt trained_network
    cp hidden_layer_weights_fp.txt trained_network
    cp hidden_layer_weights.txt trained_network
    cp output_layer_bias_fp_hex.txt trained_network
    cp output_layer_bias_fp.txt trained_network
    cp output_layer_bias.txt trained_network
    cp output_layer_weights_fp_hex.txt trained_network
    cp output_layer_weights_fp.txt trained_network
    cp output_layer_weights.txt trained_network
    cp *.png trained_network
    cp weights.npz trained_network

    # Generate init code
    pushd trained_network >/dev/null
        ./generate_init_code.py
    popd >/dev/null
popd >/dev/null


#---- TANH() FUNCTION -----------------------------------------------------------------------------

pushd model/piecewise_approximation >/dev/null
    if [ -e "fp_${FP_WIDTH}_${FP_FRAC}" ]
    then
        # Reuse existing tanh()
        echo -e "${BLUE}info: Reusing existing approximation of tanh()${NONE}"
        cp fp_${FP_WIDTH}_${FP_FRAC}/PIECEWISE_APPROXIMATION_PARAMETERS.vh . 
    else
        # Generate tanh()
        echo -e "${BLUE}info: Generating approximation of tanh()${NONE}"
        ./get_piecewise_approximation_parameters.py ${FP_WIDTH} ${FP_FRAC}

        # Add to existing list
        mkdir fp_${FP_WIDTH}_${FP_FRAC}
        mv PIECEWISE_APPROXIMATION_PARAMETERS.vh fp_${FP_WIDTH}_${FP_FRAC}
    fi
popd >/dev/null


#---- GROGU GENERATION ----------------------------------------------------------------------------

pushd grogu >/dev/null
    # Create grogu input
    echo -e "${BLUE}info: Creating register map${NONE}"
    cp regpool.rdl.template regpool.rdl

    # Hidden layer weights
    replacement=""
    for hdx in $( seq 1 1 ${HL_NEURONS} )
    do
        ndx=$(( $hdx - 1 ))

        if [ $hdx -gt 1 ]
        then
            replacement="${replacement}\n    "
        fi
        replacement="${replacement}\`REF_MULTI_CGPREG(GP, HL_WEIGHTS_${ndx}, \"Weights for neuron ${ndx} of the hidden layer\", ${input_size})"
    done
    sed -i "s/__HL_WEIGHTS__/$replacement/g" regpool.rdl

    # Hidden layer bias
    replacement=""
    for hdx in $( seq 1 1 ${HL_NEURONS} )
    do
        ndx=$(( $hdx - 1 ))

        if [ $hdx -gt 1 ]
        then
            replacement="${replacement}\n    "
        fi
        replacement="${replacement}\`REF_CGPREG(GP, HL_BIAS_${ndx}, \"Bias for neuron ${ndx} of the hidden layer'\")"
    done
    sed -i "s/__HL_BIAS__/$replacement/g" regpool.rdl

    # Output layer weights
    replacement=""
    for odx in $( seq 1 1 ${OL_NEURONS} )
    do
        ndx=$(( $odx - 1 ))

        if [ $odx -gt 1 ]
        then
            replacement="${replacement}\n    "
        fi
        replacement="${replacement}\`REF_MULTI_CGPREG(GP, OL_WEIGHTS_${ndx}, \"Weights for neuron ${ndx} of the output layer\", ${HL_NEURONS})"
    done
    sed -i "s/__OL_WEIGHTS__/$replacement/g" regpool.rdl

    # Output layer bias
    replacement=""
    for odx in $( seq 1 1 ${OL_NEURONS} )
    do
        ndx=$(( $odx - 1 ))

        if [ $odx -gt 1 ]
        then
            replacement="${replacement}\n    "
        fi
        replacement="${replacement}\`REF_CGPREG(GP, OL_BIAS_${ndx}, \"Bias for neuron ${ndx} of the output layer\")"
    done
    sed -i "s/__OL_BIAS__/$replacement/g" regpool.rdl

    # Input problem
    replacement=""
    for gdx in $( seq 1 1 $input_size )
    do
        idx=$(( $gdx - 1 ))

        if [ $gdx -gt 1 ]
        then
            replacement="${replacement}\n    "
        fi
        replacement="${replacement}\`REF_CGPREG(GP, INPUT_GRID_${idx}, \"Pixel ${idx} of the input character\")"
    done
    sed -i "s/__INPUT_GRID__/$replacement/g" regpool.rdl

    # Output solution
    replacement=""
    for odx in $( seq 1 1 ${OL_NEURONS} )
    do
        ddx=$(( $odx - 1 ))

        if [ $odx -gt 1 ]
        then
            replacement="${replacement}\n    "
        fi
        replacement="${replacement}\`REF_SGPREG(GP, OUTPUT_SOLUTION_${ddx}, \"Digit ${ddx} of the output solution\")"
    done
    sed -i "s/__OUTPUT_SOLUTION__/$replacement/g" regpool.rdl

    # Launch grogu!
    echo -e "${BLUE}info: Launching grogu${NONE}"
    source sourceme
popd >/dev/null


#---- RTL GENERATION ------------------------------------------------------------------------------

pushd rtl >/dev/null
    echo -e "${BLUE}info: Generating RTL design files set${NONE}"

    # Copy piecewise approximation
    cp ../model/piecewise_approximation/PIECEWISE_APPROXIMATION_PARAMETERS.vh .

    # Generate top-level instances
    cp NETWORK_TOP.v.template NETWORK_TOP.v
    sed -i "s/__FP_WIDTH__/$FP_WIDTH/g" NETWORK_TOP.v
    sed -i "s/__FP_FRAC__/$FP_FRAC/g" NETWORK_TOP.v
    sed -i "s/__INPUT_SIZE__/$input_size/g" NETWORK_TOP.v
    sed -i "s/__HL_NEURONS__/$HL_NEURONS/g" NETWORK_TOP.v
    sed -i "s/__OL_NEURONS__/$OL_NEURONS/g" NETWORK_TOP.v
    sed -i "s/__AXI_BASE_ADDR__/$AXI_BASE_ADDR/g" NETWORK_TOP.v

    # Hidden layer weights
    replacement=""
    for hdx in $( seq 1 1 ${HL_NEURONS} )
    do
        ndx=$(( $hdx - 1 ))

        if [ $hdx -gt 1 ]
        then
            replacement="${replacement}\n        "
        fi
        replacement="${replacement}.HWIF_OUT_HL_WEIGHTS_${ndx}      (hl_weights[${ndx}*${input_size}*${FP_WIDTH} +: ${input_size}*${FP_WIDTH}]),"
    done
    sed -i "s/__HL_WEIGHTS__/$replacement/g" NETWORK_TOP.v

    # Hidden layer bias
    replacement=""
    for hdx in $( seq 1 1 ${HL_NEURONS} )
    do
        ndx=$(( $hdx - 1 ))

        if [ $hdx -gt 1 ]
        then
            replacement="${replacement}\n        "
        fi
        replacement="${replacement}.HWIF_OUT_HL_BIAS_${ndx}         (hl_bias[${ndx}*${FP_WIDTH} +: ${FP_WIDTH}]),"
    done
    sed -i "s/__HL_BIAS__/$replacement/g" NETWORK_TOP.v

    # Output layer weights
    replacement=""
    for odx in $( seq 1 1 ${OL_NEURONS} )
    do
        ndx=$(( $odx - 1 ))

        if [ $odx -gt 1 ]
        then
            replacement="${replacement}\n        "
        fi
        replacement="${replacement}.HWIF_OUT_OL_WEIGHTS_${ndx}      (ol_weights[${ndx}*${HL_NEURONS}*${FP_WIDTH} +: ${HL_NEURONS}*${FP_WIDTH}]),"
    done
    sed -i "s/__OL_WEIGHTS__/$replacement/g" NETWORK_TOP.v

    # Output layer bias
    replacement=""
    for odx in $( seq 1 1 ${OL_NEURONS} )
    do
        ndx=$(( $odx - 1 ))

        if [ $odx -gt 1 ]
        then
            replacement="${replacement}\n        "
        fi
        replacement="${replacement}.HWIF_OUT_OL_BIAS_${ndx}         (ol_bias[${ndx}*${FP_WIDTH} +: ${FP_WIDTH}]),"
    done
    sed -i "s/__OL_BIAS__/$replacement/g" NETWORK_TOP.v

    # Input problem
    replacement=""
    for idx in $( seq 1 1 ${input_size} )
    do
        bdx=$(( $idx - 1 ))

        if [ $idx -gt 1 ]
        then
            replacement="${replacement}\n        "
        fi
        replacement="${replacement}.HWIF_OUT_INPUT_GRID_${bdx}      (values_in[${bdx}*${FP_WIDTH} +: ${FP_WIDTH}]),"
    done
    sed -i "s/__INPUT_GRID__/$replacement/g" NETWORK_TOP.v

    # Output solution
    replacement=""
    for odx in $( seq 1 1 ${OL_NEURONS} )
    do
        ndx=$(( $odx - 1 ))

        if [ $odx -gt 1 ]
        then
            replacement="${replacement}\n        "
        fi
        replacement="${replacement}.HWIF_IN_OUTPUT_SOLUTION_${ndx}  (values_out[${ndx}*${FP_WIDTH} +: ${FP_WIDTH}]),"
    done
    sed -i "s/__OUTPUT_SOLUTION__/$replacement/g" NETWORK_TOP.v
popd >/dev/null


#---- SIMULATION ----------------------------------------------------------------------------------

pushd sim >/dev/null
    pushd ootbtb >/dev/null
        echo -e "${BLUE}info: Running simple OOTBTB simulation${NONE}"
        make clean
        make DATA_WIDTH=${FP_WIDTH} NUM_INPUTS=${input_size} NUM_HL_NODES=${HL_NEURONS} NUM_OL_NODES=${OL_NEURONS}
        echo -e "info: Waves available, open with: gtkwave ootbtb.vcd ootbtb.gtkw"
    popd >/dev/null
popd >/dev/null
