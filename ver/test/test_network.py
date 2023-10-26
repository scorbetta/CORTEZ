# Standard imports
import sys
import os

# COCOTB imports
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles

# Golden model
from utils.golden_model import golden_model
from utils.my_utils import *

# Additional imports
from fpbinary import FpBinary

def dbug_print(print_flag, message):
    if print_flag == 1:
        print(f'{message}')

def generate_random_weights(num_outputs, num_inputs, fp_width, fp_frac_bits):
    weights = []
    weights_str = []

    for odx in range(num_outputs):
        temp = []
        temp_str = []
        for idx in range(num_inputs):
            random_value,random_value_bit_str = get_random_fixed_point_value(fp_width, fp_frac_bits)
            value = FpBinary(int_bits=fp_width-fp_frac_bits, frac_bits=fp_frac_bits, signed=True, value=random_value)
            temp.append(value)
            temp_str.append(random_value_bit_str)

        weights.append(temp)
        weights_str.append(temp_str)

    return weights,weights_str

def generate_random_bias(num_nodes, fp_width, fp_frac_bits):
    bias = []
    bias_str = []

    for odx in range(num_nodes):
        random_value,random_value_bit_str = get_random_fixed_point_value(fp_width, fp_frac_bits)
        value = FpBinary(int_bits=fp_width-fp_frac_bits, frac_bits=fp_frac_bits, signed=True, value=random_value)
        bias.append(value)
        bias_str.append(random_value_bit_str)

    return bias,bias_str

def truncate_value(value, num_decimal_points):
    return round(value, num_decimal_points)

@cocotb.test()
async def test_network(dut):
    # Static configuration
    num_inputs = 25
    num_hl_nodes = 16
    num_outputs = 5
    # Dynamic configuration
    width = int(os.getenv("FP_WIDTH", "8"))
    frac_bits = int(os.getenv("FP_FRAC_WIDTH", "3"))
    verbose = int(os.getenv("VERBOSE", "0"))

    # Run the clock asap
    clock = Clock(dut.CLK, 4, units="ns")
    cocotb.start_soon(clock.start())

    # One golden model for every neuron in every layer in the design!
    hl_goldens = []
    for odx in range(num_hl_nodes):
        hl_goldens.append(golden_model(width, frac_bits))
    for odx in range(num_hl_nodes):
        hl_goldens[odx].reset_values()

    ol_goldens = []
    for odx in range(num_outputs):
        ol_goldens.append(golden_model(width, frac_bits))
    for odx in range(num_outputs):
        ol_goldens[odx].reset_values()

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
        for odx in range(num_hl_nodes):
            dbug_print(verbose, f'test: HL/N#{odx}: {hl_goldens[odx].to_str()}')
        for odx in range(num_outputs):
            dbug_print(verbose, f'test: OL/N#{odx}: {ol_goldens[odx].to_str()}')


        #---- TEST INITIALIZATION -----------------------------------------------------------------

        # Generate random values
        random_values_in = []
        random_values_in_str = []
        for vdx in range(num_inputs):
            random_value,random_value_bit_str = get_random_fixed_point_value(width, frac_bits)
            value = FpBinary(int_bits=width-frac_bits, frac_bits=frac_bits, signed=True, value=random_value)
            random_values_in.append(value)
            random_values_in_str.append(random_value_bit_str)

        # Generate random weights and random bias for hidden layer
        hl_random_weights_in,hl_random_weights_in_str = generate_random_weights(num_hl_nodes, num_inputs, width, frac_bits)
        hl_random_bias_in,hl_random_bias_in_str = generate_random_bias(num_hl_nodes, width, frac_bits)

        # Generate random weights and random bias for output layer
        ol_random_weights_in,ol_random_weights_in_str = generate_random_weights(num_outputs, num_hl_nodes, width, frac_bits)
        ol_random_bias_in,ol_random_bias_in_str = generate_random_bias(num_outputs, width, frac_bits)


        #---- GOLDEN MODEL RUN --------------------------------------------------------------------

        # Run golden model on hidden layer
        hl_outputs = []
        for odx in range(num_hl_nodes):
            # Multiplication
            hl_neuron_muls = []
            for idx in range(num_inputs):
                hl_neuron_muls.append(hl_goldens[odx].do_op("mul", random_values_in[idx], hl_random_weights_in[odx][idx]))
            dbug_print(verbose, f'gldn: HL/N#{odx} after mul: {hl_neuron_muls}')

            # Accumulator
            for idx in range(num_inputs):
                hl_neuron_acc = hl_goldens[odx].do_op("acc", hl_neuron_muls[idx])
            hl_neuron_acc = hl_goldens[odx].do_op("acc", hl_random_bias_in[odx])
            dbug_print(verbose, f'gldn: HL/N#{odx} after acc: {hl_neuron_acc}')

            # Activation function
            hl_neuron_act_fun = hl_goldens[odx].do_op("act_fun", hl_neuron_acc)
            dbug_print(verbose, f'gldn: HL/N#{odx} after act_fun: {hl_neuron_act_fun}')

            # Save for next layer
            hl_outputs.append(hl_neuron_act_fun)

        # Run golden model on output layer
        net_outputs = []
        for odx in range(num_outputs):
            # Multiplication
            ol_neuron_muls = []
            for idx in range(num_hl_nodes):
                ol_neuron_muls.append(ol_goldens[odx].do_op("mul", hl_outputs[idx], ol_random_weights_in[odx][idx]))
            dbug_print(verbose, f'gldn: OL/N#{odx} after mul: {ol_neuron_muls}')

            # Accumulator
            for idx in range(num_hl_nodes):
                ol_neuron_acc = ol_goldens[odx].do_op("acc", ol_neuron_muls[idx])
            ol_neuron_acc = ol_goldens[odx].do_op("acc", ol_random_bias_in[odx])
            dbug_print(verbose, f'gldn: OL/N#{odx} after acc: {ol_neuron_acc}')

            # Activation function
            ol_neuron_act_fun = ol_goldens[odx].do_op("act_fun", ol_neuron_acc)
            dbug_print(verbose, f'gldn: OL/N#{odx} after act_fun: {ol_neuron_act_fun}')
            
            # Save result
            net_outputs.append(ol_neuron_act_fun)


        #---- DESIGN RUN --------------------------------------------------------------------------

        await RisingEdge(dut.CLK)

        # Force weights
        for odx in range(num_hl_nodes):
            for idx in range(num_inputs):
                dut.HL_WEIGHTS_IN[odx*num_inputs+idx].value = int(hl_random_weights_in_str[odx][idx], 2)

        for odx in range(num_outputs):
            for idx in range(num_hl_nodes):
                dut.OL_WEIGHTS_IN[odx*num_hl_nodes+idx].value = int(ol_random_weights_in_str[odx][idx], 2)

        # Force bias
        for odx in range(num_hl_nodes):
            dut.HL_BIAS_IN[odx].value = int(hl_random_bias_in_str[odx], 2)

        for odx in range(num_outputs):
            dut.OL_BIAS_IN[odx].value = int(ol_random_bias_in_str[odx], 2)

        # Force values
        for idx in range(num_inputs):
            dut.VALUES_IN[idx].value = int(random_values_in_str[idx], 2)

        # Strobe values
        await RisingEdge(dut.CLK)
        dut.VALID_IN.value = 1
        await RisingEdge(dut.CLK)
        dut.VALID_IN.value = 0

        # Wait for the network to fire
        await RisingEdge(dut.VALID_OUT)


        #---- VERIFICATION ------------------------------------------------------------------------

        await FallingEdge(dut.CLK)

        # Verify w/ margins: exact values not expected. Use double-sided margins instead...
        #
        # WARNING While testing single modules, the double-sided margin is safe. However, when
        # testing the whole network, the margin shall be selected according to the value we are
        # checking. For instance, for very low values (~ <1e-2), the margin shall be kept high; for
        # higher values the margin might be increased. This is due to the fact that the whole
        # netowkr accumulates error and although the final result is approximately correct, the
        # margin might not be able to capture it. For this reason, and for test only, the margin is
        # computed one-side, considering the absolute relative error of the two results, compared to
        # the full domain swing, i.e. 2, since domain is [-1.0,1.0]
        margin = 0.05
        for odx in range(num_outputs):
            dut_result = bin2fp(dut.VALUES_OUT[odx].value.binstr, width, frac_bits)
            diff = abs(dut_result - net_outputs[odx])
            abs_err = diff / 2.0
            assert(abs_err <= margin),print(f'Results mismatch: test={test},odx={odx},dut_result={dut_result},golden_result={net_outputs[odx]},diff={diff},abs_err={abs_err},margin={margin}')

        # Shim delay
        for cycle in range(4):
            await RisingEdge(dut.CLK)

        dbug_print(verbose, f'test: ==== End: TEST #{test} ================')
        dbug_print(verbose, '')
