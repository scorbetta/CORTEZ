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
HL_NEURONS=24
OL_NEURONS=5

# Fixed-point
FP_WIDTH=8
FP_FRAC=5

# Input problem grid size (one side)
GRID_SIZE=6

# Network training configuration
MAX_NOISY_PIXELS=5
TRAINING_LEN=500
TEST_LEN=250
EPOCHS=1200
ALPHA=0.01

# Miscellanea, don't touch!
AXI_BASE_ADDR="32'h3000_0000"
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
    cp hidden_layer_*.txt trained_network
    cp output_layer_*.txt trained_network
    cp weights.npz trained_network

    # Generate init code
    pushd trained_network >/dev/null
        echo -e "${BLUE}info: Generating init code${NONE}"
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
    echo -e "${BLUE}info: Launching grogu${NONE}"
    source sourceme ${input_size} ${OL_NEURONS} ${HL_NEURONS}
popd >/dev/null


#@DEPRECATED#---- RTL GENERATION ------------------------------------------------------------------------------
#@DEPRECATED
#@DEPRECATEDpushd rtl >/dev/null
#@DEPRECATED    echo -e "${BLUE}info: Generating RTL design files set${NONE}"
#@DEPRECATED
#@DEPRECATED    # Copy piecewise approximation
#@DEPRECATED    cp ../model/piecewise_approximation/PIECEWISE_APPROXIMATION_PARAMETERS.vh .
#@DEPRECATED
#@DEPRECATED    # Generate top-level instances for generic NETWORK_TOP (deprecated) and Caravel's Core (ASIC
#@DEPRECATED    # only(
#@DEPRECATED    tfiles=( NETWORK_TOP.v.template CORE_TOP.v.template )
#@DEPRECATED    for tfile in ${tfiles[@]}
#@DEPRECATED    do
#@DEPRECATED        # Remove  .template  substring
#@DEPRECATED        target=${tfile::-9}
#@DEPRECATED        cp $tfile $target
#@DEPRECATED        sed -i "s/__FP_WIDTH__/$FP_WIDTH/g" $target
#@DEPRECATED        sed -i "s/__FP_FRAC__/$FP_FRAC/g" $target
#@DEPRECATED        sed -i "s/__INPUT_SIZE__/$input_size/g" $target
#@DEPRECATED        sed -i "s/__HL_NEURONS__/$HL_NEURONS/g" $target
#@DEPRECATED        sed -i "s/__OL_NEURONS__/$OL_NEURONS/g" $target
#@DEPRECATED        sed -i "s/__AXI_BASE_ADDR__/$AXI_BASE_ADDR/g" $target
#@DEPRECATED
#@DEPRECATED        # Hidden layer weights
#@DEPRECATED        replacement=""
#@DEPRECATED        for hdx in $( seq 1 1 ${HL_NEURONS} )
#@DEPRECATED        do
#@DEPRECATED            ndx=$(( $hdx - 1 ))
#@DEPRECATED
#@DEPRECATED            if [ $hdx -gt 1 ]
#@DEPRECATED            then
#@DEPRECATED                replacement="${replacement}\n        "
#@DEPRECATED            fi
#@DEPRECATED            replacement="${replacement}.HWIF_OUT_HL_WEIGHTS_${ndx}      (hl_weights[${ndx}*${input_size}*${FP_WIDTH} +: ${input_size}*${FP_WIDTH}]),"
#@DEPRECATED        done
#@DEPRECATED        sed -i "s/__HL_WEIGHTS__/$replacement/g" $target
#@DEPRECATED
#@DEPRECATED        # Hidden layer bias
#@DEPRECATED        replacement=""
#@DEPRECATED        for hdx in $( seq 1 1 ${HL_NEURONS} )
#@DEPRECATED        do
#@DEPRECATED            ndx=$(( $hdx - 1 ))
#@DEPRECATED
#@DEPRECATED            if [ $hdx -gt 1 ]
#@DEPRECATED            then
#@DEPRECATED                replacement="${replacement}\n        "
#@DEPRECATED            fi
#@DEPRECATED            replacement="${replacement}.HWIF_OUT_HL_BIAS_${ndx}         (hl_bias[${ndx}*${FP_WIDTH} +: ${FP_WIDTH}]),"
#@DEPRECATED        done
#@DEPRECATED        sed -i "s/__HL_BIAS__/$replacement/g" $target
#@DEPRECATED
#@DEPRECATED        # Output layer weights
#@DEPRECATED        replacement=""
#@DEPRECATED        for odx in $( seq 1 1 ${OL_NEURONS} )
#@DEPRECATED        do
#@DEPRECATED            ndx=$(( $odx - 1 ))
#@DEPRECATED
#@DEPRECATED            if [ $odx -gt 1 ]
#@DEPRECATED            then
#@DEPRECATED                replacement="${replacement}\n        "
#@DEPRECATED            fi
#@DEPRECATED            replacement="${replacement}.HWIF_OUT_OL_WEIGHTS_${ndx}      (ol_weights[${ndx}*${HL_NEURONS}*${FP_WIDTH} +: ${HL_NEURONS}*${FP_WIDTH}]),"
#@DEPRECATED        done
#@DEPRECATED        sed -i "s/__OL_WEIGHTS__/$replacement/g" $target
#@DEPRECATED
#@DEPRECATED        # Output layer bias
#@DEPRECATED        replacement=""
#@DEPRECATED        for odx in $( seq 1 1 ${OL_NEURONS} )
#@DEPRECATED        do
#@DEPRECATED            ndx=$(( $odx - 1 ))
#@DEPRECATED
#@DEPRECATED            if [ $odx -gt 1 ]
#@DEPRECATED            then
#@DEPRECATED                replacement="${replacement}\n        "
#@DEPRECATED            fi
#@DEPRECATED            replacement="${replacement}.HWIF_OUT_OL_BIAS_${ndx}         (ol_bias[${ndx}*${FP_WIDTH} +: ${FP_WIDTH}]),"
#@DEPRECATED        done
#@DEPRECATED        sed -i "s/__OL_BIAS__/$replacement/g" $target
#@DEPRECATED
#@DEPRECATED        # Input problem
#@DEPRECATED        replacement=""
#@DEPRECATED        for idx in $( seq 1 1 ${input_size} )
#@DEPRECATED        do
#@DEPRECATED            bdx=$(( $idx - 1 ))
#@DEPRECATED
#@DEPRECATED            if [ $idx -gt 1 ]
#@DEPRECATED            then
#@DEPRECATED                replacement="${replacement}\n        "
#@DEPRECATED            fi
#@DEPRECATED            replacement="${replacement}.HWIF_OUT_INPUT_GRID_${bdx}      (values_in[${bdx}*${FP_WIDTH} +: ${FP_WIDTH}]),"
#@DEPRECATED        done
#@DEPRECATED        sed -i "s/__INPUT_GRID__/$replacement/g" $target
#@DEPRECATED
#@DEPRECATED        # Output solution
#@DEPRECATED        replacement=""
#@DEPRECATED        for odx in $( seq 1 1 ${OL_NEURONS} )
#@DEPRECATED        do
#@DEPRECATED            ndx=$(( $odx - 1 ))
#@DEPRECATED
#@DEPRECATED            if [ $odx -gt 1 ]
#@DEPRECATED            then
#@DEPRECATED                replacement="${replacement}\n        "
#@DEPRECATED            fi
#@DEPRECATED            replacement="${replacement}.HWIF_IN_OUTPUT_SOLUTION_${ndx}  (values_out[${ndx}*${FP_WIDTH} +: ${FP_WIDTH}]),"
#@DEPRECATED        done
#@DEPRECATED        sed -i "s/__OUTPUT_SOLUTION__/$replacement/g" $target
#@DEPRECATED    done
#@DEPRECATEDpopd >/dev/null
#@DEPRECATED
#@DEPRECATED
#@DEPRECATED#---- SIMULATION ----------------------------------------------------------------------------------
#@DEPRECATED
#@DEPRECATEDpushd sim >/dev/null
#@DEPRECATED    pushd ootbtb >/dev/null
#@DEPRECATED        echo -e "${BLUE}info: Running simple OOTBTB simulation${NONE}"
#@DEPRECATED        make clean
#@DEPRECATED        make DATA_WIDTH=${FP_WIDTH} NUM_INPUTS=${input_size} NUM_HL_NODES=${HL_NEURONS} NUM_OL_NODES=${OL_NEURONS}
#@DEPRECATED        echo -e "info: Waves available, open with: gtkwave ootbtb.vcd ootbtb.gtkw"
#@DEPRECATED    popd >/dev/null
#@DEPRECATEDpopd >/dev/null
