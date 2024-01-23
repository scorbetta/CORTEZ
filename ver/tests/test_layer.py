import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from fxpmath import Fxp
import sys
import os
sys.path.append(os.path.relpath('../'))
from utils.my_utils import *
sys.path.append(os.path.relpath("../../model/neural_network"))
from activations import afun_test_primitive

@cocotb.test()
async def test_layer(dut):
    # Config
    width = int(dut.WIDTH.value)
    frac_bits = int(dut.FRAC_BITS.value)
    num_inputs = int(dut.NUM_INPUTS.value)
    num_outputs = int(dut.NUM_OUTPUTS.value)
    verbose = 0

    fxp_quants = 2 ** width - 1

    # Run the clock asap
    clock = Clock(dut.CLK, 10, units="ns")
    cocotb.start_soon(clock.start())

    # One golden model for every Neuron!
    goldens = []
    for odx in range(num_outputs):
        goldens.append(Fxp(0.0, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config()))

    # Defaults
    dut.VALID_IN.value = 0
    dut.RSTN.value = 0

    # Reset procedure
    for cycle in range(4):
        await RisingEdge(dut.CLK)
    dut.RSTN.value = 1

    # Shim delay
    for cycle in range(4):
        await RisingEdge(dut.CLK)

    rel_errs = []
    for test in range(1000):
        dbug_print(verbose, f'test: ==== Begin: TEST #{test} ================')
        for odx in range(num_outputs):
            dbug_print(verbose, f'test: N#{odx}: {goldens[odx].hex()}')

        # Generate random values
        random_values_in = []
        random_values_in_str = ""
        for vdx in range(num_inputs):
            random_value = fxp_generate_random(width, frac_bits)
            random_values_in.append(random_value)
            random_values_in_str = f'{random_value.bin()}{random_values_in_str}'
        dbug_print(verbose, f'test: Input vector: {random_values_in}')

        # Generate random weights
        random_weights_in = []
        random_weights_in_str = ""
        for odx in range(num_outputs):
            temp = []
            temp_str = ""
            for idx in range(num_inputs):
                random_value = fxp_generate_random(width, frac_bits)
                temp.append(random_value)
                temp_str = f'{random_value.bin()}{temp_str}'
            random_weights_in.append(temp)
            random_weights_in_str = f'{temp_str}{random_weights_in_str}'
        dbug_print(verbose, f'test: Input weights: {random_weights_in}')

        # Generate random bias
        random_bias_in = []
        random_bias_in_str = ""
        for odx in range(num_outputs):
            random_value = fxp_generate_random(width, frac_bits)
            random_bias_in.append(random_value)
            random_bias_in_str = f'{random_value.bin()}{random_bias_in_str}'
        dbug_print(verbose, f'test: Input bias: {random_bias_in}')

        # Sanity checks
        assert(len(random_values_in_str) == 8*num_inputs)
        assert(len(random_weights_in_str) == 8*num_inputs*num_outputs)
        assert(len(random_bias_in_str) == 8*num_outputs)

        # Run golden model on all neurons
        for odx in range(num_outputs):
            # Multiplication
            neuron_muls = []
            neuron_muls_str = []
            for idx in range(num_inputs):
                neuron_muls.append(random_values_in[idx] * random_weights_in[odx][idx])
            dbug_print(verbose, f'gldn: N#{odx}/mul: {[ x.hex() for x in neuron_muls ]}')

            # Accumulator
            neuron_acc = Fxp(0.0, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())
            for idx in range(num_inputs):
                neuron_acc += neuron_muls[idx]
            neuron_acc += random_bias_in[odx]
            dbug_print(verbose, f'gldn: N#{odx}/acc: {neuron_acc.hex()}')

            # Activation function
            retval = afun_test_primitive(neuron_acc.get_val())
            goldens[odx] = Fxp(val=retval, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())
            dbug_print(verbose, f'gldn: N#{odx}/act_fun: {goldens[odx].hex()}')

        # Run DUT
        await RisingEdge(dut.CLK)
        dut.WEIGHTS_IN.value = int(random_weights_in_str,2)
        dut.BIAS_IN.value = int(random_bias_in_str,2)
        await RisingEdge(dut.CLK)
        dut.VALUES_IN.value = int(random_values_in_str,2)

        await RisingEdge(dut.CLK)
        dut.VALID_IN.value = 1
        await RisingEdge(dut.CLK)
        dut.VALID_IN.value = 0

        # Wait for all neurons to fire
        fired = []
        for odx in range(num_outputs):
            fired.append(False)

        flag = True
        fired_count = 0
        values_out = [ 0xdeadbeef ] * num_outputs
        while flag:
            await FallingEdge(dut.CLK)
            # Check who's fired
            for odx in range(num_outputs):
                if int(dut.VALIDS_OUT.value[odx]) == 1 and fired[odx] == False:
                    fired[odx] = True
                    fired_count = fired_count + 1
                    # Values are valid only when the valid signal is asserted. Although they do not
                    # change until the next time valid is asserted, it is good habit sticking to the
                    # digital design!
                    strlen = width * num_outputs
                    lsb = odx * width
                    msb = lsb + width - 1
                    lmc = stringify(msb, strlen)
                    rmc = stringify(lsb, strlen)
                    values_out[odx] = Fxp(val=f'0b{dut.VALUES_OUT.value[lmc:rmc]}', signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())

            # End condition
            if fired_count == num_outputs:
                flag = False

        # Verify results are within margins
        threshold = 0.05
        for odx in range(num_outputs):
            abs_err = fxp_abs_err(goldens[odx], values_out[odx])
            quant_err = float(abs_err) / float(fxp_lsb) / fxp_quants
            assert(quant_err <= threshold),print(f'Results differ more than {threshold*100}% LSBs: dut_result={values_out[odx]},golden_result={goldens[odx]},abs_err={abs_err},quant_error={quant_err}')

        # Shim delay
        for cycle in range(4):
            await RisingEdge(dut.CLK)

        dbug_print(verbose, f'test: ==== End: TEST #{test} ================')
