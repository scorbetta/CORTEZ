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
WIDTHS=( 8 10 12 14 16 18 20 22 24 )

# Number of repetitions (seed changes across iterations)
NUM_ITERS=25

# Tests of fixed-point modules library with different configurations
for width in ${WIDTHS[@]}
do
    # Reserve 3 bits to the integral part
    frac_bits=$(( $width - 3 ))
    for dut in ${DUTS[@]}
    do
        for iter in $( seq 1 ${NUM_ITERS} )
        do
            # Run test in proper folder
            pushd ../ >/dev/null
                # Seed
                seed=$( date +%N )

                # Log name
                logname=${OFOLDER}/logs/${dut}_${width}_${frac_bits}_${iter}.runlog
                cmd="make -j 4 TOPLEVEL=${dut} RANDOM_SEED=${seed} WIDTH=${width} FRAC_BITS=${frac_bits}"
                echo "# ${cmd}" > ${logname}

                # Prepare INI file
                cp config.ini.template config.ini
                sed -i "s/__FP_WIDTH__/${width}/g" config.ini
                sed -i "s/__FRAC_BITS__/${frac_bits}/g" config.ini
                sed -i "s/__NUM_INPUTS__/\"UNUSED\"/g" config.ini
                sed -i "s/__NUM_OUTPUTS__/\"UNUSED\"/g" config.ini

                # Clean before simulating
                make clean
                eval ${cmd} 2>&1 | tee -a ${logname}
            popd >/dev/null
        done
    done  
done


#@TBD#---- SINGLETON TESTS -----------------------------------------------------------------------------
#@TBD
#@TBD# FIXED_POINT_ACT_FUN
#@TBDdut=FIXED_POINT_ACT_FUN
#@TBDwidth=8
#@TBDfrac_bits=5
#@TBDseed=$( date +%N )
#@TBDlogname=${OFOLDER}/logs/${dut}_${width}_${frac_bits}.runlog
#@TBDcmd="make -j 4 TOPLEVEL=${dut} RANDOM_SEED=${seed} WIDTH=${width} FRAC_BITS=${frac_bits}"
#@TBDecho "# ${cmd}" > ${logname}
#@TBDpushd ../ >/dev/null
#@TBD    make clean
#@TBD    eval ${cmd} 2>&1 | tee -a ${logname}
#@TBDpopd >/dev/null
#@TBD
#@TBD
#---- POST PROCESSING -----------------------------------------------------------------------------

OFILE=${OFOLDER}/Summary.txt

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
