#!/usr/bin/bash

# Fixed point widths
WIDTHS=( 16 18 20 22 24 )
# Number of repetitions (seed changes across iterations)
NUM_ITERS=250
# DUT to test
TOP=NETWORK

rm -fR logs
mkdir logs

# Run all configurations on all tests
for width in ${WIDTHS[@]}
do
    # Exactly 3 bits reserved to the integral part
    frac_bits=$(( $width - 3 ))

    pushd src >/dev/null
        ln -sf ../../nn/piecewise_approximation/fp_${width}_${frac_bits}/PIECEWISE_APPROXIMATION_PARAMETERS.svh
        ln -sf NETWORK_CONFIG_${width}_${frac_bits}.svh NETWORK_CONFIG.svh
    popd >/dev/null
    
    # Clean first time only
    make clean

    # Run multiple times, change seed at every iteration
    for iter in $( seq 1 ${NUM_ITERS} )
    do
        seed=$( date +%N )
        logname=logs/${TOP}_${width}_${frac_bits}_${iter}.runlog
        cmd="FP_WIDTH=${width} FP_FRAC_WIDTH=${frac_bits} make -j 4 TOPLEVEL=${TOP} WIDTH=${width} FRAC_BITS=${frac_bits} RANDOM_SEED=${seed}"
        echo ${cmd} > ${logname}

        # Run test
        eval ${cmd} 2>&1 | tee -a ${logname}
    done
    
done
