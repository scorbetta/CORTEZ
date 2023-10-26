#!/usr/bin/bash

# CORTEZ design regression


#---- PREAMBLE ------------------------------------------------------------------------------------

# Output folder contains it all
OFOLDER=outdir

# Clean cache
rm -fR $OFOLDER
mkdir $OFOLDER


#---- PARAMETRIC TESTS ----------------------------------------------------------------------------

# DUTs
DUTS=( FIXED_POINT_ABS FIXED_POINT_ACC FIXED_POINT_ADD FIXED_POINT_CHANGE_SIGN FIXED_POINT_COMP FIXED_POINT_MUL )

# Fixed point widths
WIDTHS=( 8 10 12 14 16 18 20 22 24 )

# Number of repetitions (seed changes across iterations)
NUM_ITERS=2

# Run all configurations on all tests
for width in ${WIDTHS[@]}
do
    # Reserve 3 bits to the integral part
    frac_bits=$(( $width - 3 ))
    for dut in ${DUTS[@]}
    do
        for iter in $( seq 1 ${NUM_ITERS} )
        do
            seed=$( date +%N )
            logname=logs/${dut}_${width}_${frac_bits}_${iter}.runlog
            cmd="FP_WIDTH=${width} FP_FRAC_WIDTH=${frac_bits} make -j 4 TOPLEVEL=${dut} WIDTH=${width} FRAC_BITS=${frac_bits} RANDOM_SEED=${seed}"
            echo ${cmd} > ${logname}

            # Run test
            make clean
            eval ${cmd} 2>&1 | tee -a ${logname}
        done
    done
    
done


#---- SINGLETON TESTS -----------------------------------------------------------------------------

# DUTs
DUTS=( FIXED_POINT_ACT_FUN NEURON LAYER NETWORK NETWORK_TOP )

# Tests for a particular fixed-point configuration
for dut in ${DUTS[@]}
do
    # Log file name
    seed=$( date +%N )
    logname=logs/${dut}_${width}_${frac_bits}.runlog
    cmd="FP_WIDTH=24 FP_FRAC_WIDTH=21 make -j 4 TOPLEVEL=${dut} WIDTH=24 FRAC_BITS=21 RANDOM_SEED=${seed}"
    echo ${cmd} > ${logname}
    make clean
    eval ${cmd} 2>&1 | tee -a ${logname}
done


#---- POST PROCESSING -----------------------------------------------------------------------------

pushd logs >/dev/null
    echo -n "" > summary

    for logfile in $( ls *.runlog )
    do
        run=$( basename ${logfile} .runlog )
        result_line=$( grep -Eo "TESTS=[0-9]+\sPASS=[0-9]+\sFAIL=[0-9]+\sSKIP=[0-9]+" ${logfile} )
        pass=$( echo ${result_line} | sed -rn 's/.*PASS=([0-9]+).*/\1/p' )
        fail=$( echo ${result_line} | sed -rn 's/.*FAIL=([0-9]+).*/\1/p' )

        if [[ "${pass}" == "1" && "${fail}" == "0" ]]
        then
            echo "${run}: PASS" >> summary
        elif [[ "${pass}" == "0" && "${fail}" == "1" ]]
        then
            echo "${run}: FAIL" >> summary
        else
            echo "${run}: UNKNOWN" >> summary
        fi
    done
popd >/dev/null

# Inform user about results
num_tests=$( wc -l logs/summary | awk '{print $1}' )
num_pass=$( grep -w "PASS" logs/summary | wc -l )
num_fail=$( grep -w "FAIL" logs/summary | wc -l )
num_other=$( grep -w "UNKNOWN" logs/summary | wc -l )

echo ""
echo "rslt: Total number of tests: ${num_tests}"
echo "rslt:    Pass: ${num_pass}"
echo "rslt:    Fail: ${num_fail}"
echo "rslt:    Unknown: ${num_other}"
