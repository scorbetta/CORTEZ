import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, with_timeout
import os
from fpbinary import FpBinary
from .golden_model import *

def dbug_print(print_flag, message):
    if print_flag == 1:
        print(f'{message}')

@cocotb.test()
async def test_layer(dut):
    # Config
    width = int(os.getenv("FP_WIDTH", "8"))
    frac_bits = int(os.getenv("FP_FRAC_WIDTH", "3"))
    num_inputs = int(os.getenv("NUM_INPUTS", "2"))
    num_outputs = int(os.getenv("NUM_OUTPUTS", "2"))
    verbose = int(os.getenv("VERBOSE", "0"))

    # Run the clock asap
    clock = Clock(dut.CLK, 10, units="ns")
    cocotb.start_soon(clock.start())

    # One golden model for every Neuron!
    goldens = []
    for odx in range(num_outputs):
        goldens.append(golden_model(width, frac_bits))
    for odx in range(num_outputs):
        goldens[odx].reset_values()

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

    for test in range(1000):
        dbug_print(verbose, f'test: ==== Begin: TEST #{test} ================')
        for odx in range(num_outputs):
            dbug_print(verbose, f'test: N#{odx}: {goldens[odx].to_str()}')

        # Generate random values
        random_values_in = []
        random_values_in_str = []
        for vdx in range(num_inputs):
            random_value,random_value_bit_str = get_random_fixed_point_value(width, frac_bits)
            value = FpBinary(int_bits=width-frac_bits, frac_bits=frac_bits, signed=True, value=random_value)
            random_values_in.append(value)
            random_values_in_str.append(random_value_bit_str)

        # Generate random weights
        random_weights_in = []
        random_weights_in_str = []
        for odx in range(num_outputs):
            temp = []
            temp_str = []
            for idx in range(num_inputs):
                random_value,random_value_bit_str = get_random_fixed_point_value(width, frac_bits)
                value = FpBinary(int_bits=width-frac_bits, frac_bits=frac_bits, signed=True, value=random_value)
                temp.append(value)
                temp_str.append(random_value_bit_str)
            random_weights_in.append(temp)
            random_weights_in_str.append(temp_str)

        # Generate random bias
        random_bias_in = []
        random_bias_in_str = []
        for odx in range(num_outputs):
            random_value,random_value_bit_str = get_random_fixed_point_value(width, frac_bits)
            value = FpBinary(int_bits=width-frac_bits, frac_bits=frac_bits, signed=True, value=random_value)
            random_bias_in.append(value)
            random_bias_in_str.append(random_value_bit_str)

        # Run golden model on all neurons
        for odx in range(num_outputs):
            # Multiplication
            neuron_muls = []
            for idx in range(num_inputs):
                neuron_muls.append(goldens[odx].do_op("mul", random_values_in[idx], random_weights_in[odx][idx]))
            dbug_print(verbose, f'gldn: N#{odx} after mul: {neuron_muls}')

            # Accumulator
            for idx in range(num_inputs):
                neuron_acc = goldens[odx].do_op("acc", neuron_muls[idx])
            neuron_acc = goldens[odx].do_op("acc", random_bias_in[odx])
            dbug_print(verbose, f'gldn: N#{odx} after acc: {neuron_acc}')

            # Activation function
            neuron_act_fun = goldens[odx].do_op("act_fun", neuron_acc)
            dbug_print(verbose, f'gldn: N#{odx} after act_fun: {neuron_act_fun}')

        # Run DUT
        await RisingEdge(dut.CLK)
        for idx in range(num_inputs):
            dut.VALUES_IN[idx].value = int(random_values_in_str[idx], 2)

        for odx in range(num_outputs):
            for idx in range(num_inputs):
                #dut.WEIGHTS_IN[odx][idx].value = int(random_weights_in_str[odx][idx], 2)
                dut.WEIGHTS_IN[odx*num_inputs+idx].value = int(random_weights_in_str[odx][idx], 2)

        for odx in range(num_outputs):
            dut.BIAS_IN[odx].value = int(random_bias_in_str[odx], 2)
        
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
                if int(dut.VALID_OUT.value[odx]) == 1 and fired[odx] == False:
                    fired[odx] = True
                    fired_count = fired_count + 1
                    # Values are valid only when the valid signal is asserted. Although they do not
                    # change until the next time valid is asserted, it is good habit sticking to the
                    # digital design!
                    values_out[odx] = dut.VALUES_OUT.value[odx].binstr

            # End condition
            if fired_count == num_outputs:
                flag = False

        # Verify w/ margins: exact values not expected. Use double-sided margins instead...
        margin = 0.05
        for odx in range(num_outputs):
            dut_result = bin2fp(values_out[odx], width, frac_bits)
            golden_result_lb = abs(goldens[odx].act_fun) * (1.0 - margin)
            golden_result_ub = abs(goldens[odx].act_fun) * (1.0 + margin)
            assert(abs(dut_result) >= abs(golden_result_lb) and abs(dut_result) <= abs(golden_result_ub)),print(f'Results mismatch: test={test},odx={odx},dut_result={dut_result},golden_result={goldens[odx].act_fun},golden_result_range=[{golden_result_lb},{golden_result_ub}]')

        # Shim delay
        for cycle in range(4):
            await RisingEdge(dut.CLK)

        dbug_print(verbose, f'test: ==== End: TEST #{test} ================')
