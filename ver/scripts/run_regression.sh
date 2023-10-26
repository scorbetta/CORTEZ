#!/usr/bin/bash

# CORTEZ design regression


#---- PREAMBLE ------------------------------------------------------------------------------------

# Output folder contains it all
OFOLDER=${PWD}/outdir

# Clean cache
rm -fR $OFOLDER

# Re-create cache
mkdir ${OFOLDER}
mkdir -p ${OFOLDER}/logs


#---- PARAMETRIC TESTS ----------------------------------------------------------------------------

# DUTs
DUTS=( FIXED_POINT_ABS FIXED_POINT_ACC FIXED_POINT_ADD FIXED_POINT_CHANGE_SIGN FIXED_POINT_COMP FIXED_POINT_MUL )

# Fixed point widths
#WIDTHS=( 8 10 12 14 16 18 20 22 24 )
WIDTHS=( 24 )

# Number of repetitions (seed changes across iterations)
NUM_ITERS=1

# Tests of fixed-point modules library with different configurations
for width in ${WIDTHS[@]}
do
    # Reserve 3 bits to the integral part
    frac_bits=$(( $width - 3 ))
    for dut in ${DUTS[@]}
    do
        for iter in $( seq 1 ${NUM_ITERS} )
        do
            seed=$( date +%N )
            logname=${OFOLDER}/logs/${dut}_${width}_${frac_bits}_${iter}.runlog
            cmd="FP_WIDTH=${width} FP_FRAC_WIDTH=${frac_bits} make -j 4 TOPLEVEL=${dut} WIDTH=${width} FRAC_BITS=${frac_bits} RANDOM_SEED=${seed}"
            echo "# ${cmd}" > ${logname}

            # Run test in proper folder
            pushd ../ >/dev/null
                make clean
                eval ${cmd} 2>&1 | tee -a ${logname}
            popd >/dev/null
        done
    done
    
done


#---- SINGLETON TESTS -----------------------------------------------------------------------------

# DUTs
DUTS=( FIXED_POINT_ACT_FUN NEURON LAYER NETWORK NETWORK_TOP )

# Fixed-point number width
FP_WIDTH=24

# Fixed-point width of fraction bits
FP_FRAC_BITS=21

# Tests for a particular fixed-point configuration
for dut in ${DUTS[@]}
do
    # Log file name
    seed=$( date +%N )
    logname=${OFOLDER}/logs/${dut}_${width}_${frac_bits}.runlog
    cmd="FP_WIDTH=${FP_WIDTH} FP_FRAC_WIDTH=${FP_FRAC_BITS} make -j 4 TOPLEVEL=${dut} WIDTH=${FP_WIDTH} FRAC_BITS=${FP_FRAC_BITS} RANDOM_SEED=${seed}"
    echo "# ${cmd}" > ${logname}

    pushd ../ >/dev/null
        make clean
        eval ${cmd} 2>&1 | tee -a ${logname}
    popd >/dev/null
done


#---- POST PROCESSING -----------------------------------------------------------------------------

OFILE=${OFOLDER}/../Summary.txt

# Check all run tests
failing_tests=()
pushd ${OFOLDER}/logs >/dev/null
    echo -n "" > ${OFILE}

    for logfile in $( ls *.runlog )
    do
        run=$( basename ${logfile} .runlog )
        result_line=$( grep -Eo "TESTS=[0-9]+\sPASS=[0-9]+\sFAIL=[0-9]+\sSKIP=[0-9]+" ${logfile} )
        pass=$( echo ${result_line} | sed -rn 's/.*PASS=([0-9]+).*/\1/p' )
        fail=$( echo ${result_line} | sed -rn 's/.*FAIL=([0-9]+).*/\1/p' )

        if [[ "${pass}" == "1" && "${fail}" == "0" ]]
        then
            echo "${run}: PASS" >> ${OFILE}
        elif [[ "${pass}" == "0" && "${fail}" == "1" ]]
        then
            echo "${run}: FAIL" >> ${OFILE}
            failing_tests[${#failing_tests[@]}]="${run}"
        else
            echo "${run}: UNKNOWN" >> ${OFILE}
        fi
    done
popd >/dev/null

# Inform user about results
num_tests=$( wc -l ${OFILE} | awk '{print $1}' )
num_pass=$( grep -w "PASS" ${OFILE} | wc -l )
num_fail=$( grep -w "FAIL" ${OFILE} | wc -l )
num_other=$( grep -w "UNKNOWN" ${OFILE} | wc -l )

echo ""
echo "rslt: Total number of tests: ${num_tests}"
echo "rslt:    Pass: ${num_pass}"
echo "rslt:    Fail: ${num_fail}"
if [ ${num_fail} -gt 0 ]
then
    echo -n "rslt:        --> Failing tests: { "
    for elem in "${failing_tests[@]}"
    do
        echo -n "${elem} "
    done
    echo "}"
fi
echo "rslt:    Unknown: ${num_other}"
