import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, with_timeout
import os
from fpbinary import FpBinary
from .golden_model import *
import json
import numpy as np

def dbug_print(print_flag, message):
    if print_flag == 1:
        print(f'{message}')

def get_bin_str(float_value, width, frac_bits):
    # Convert to fixed-point first
    fp_value = FpBinary(int_bits=width-frac_bits, frac_bits=frac_bits, signed=True, value=float_value)
    fp_value_hex = hex(fp_value)
    return bin(int(fp_value_hex, 16))

# Convert a list of floating-point values to a list of fixed-point values
def fp_create_list(int_bits, frac_bits, is_signed, init_values):
    # Allocate space
    fp_list = []

    # Fill in with values
    for idx in range(len(init_values)):
        fp_list.append(FpBinary(int_bits=int_bits, frac_bits=frac_bits, signed=is_signed, value=init_values[idx]))

    return fp_list

# Convert a matrix of floating-point values to a matrix of fixed-point values
def fp_create_matrix(shape, int_bits, frac_bits, is_signed, init_values):
    # Allocate space for matrix
    fp_matrix = np.full(shape, FpBinary(int_bits=int_bits, frac_bits=frac_bits, signed=is_signed))

    # Fill in with values
    if len(shape) == 1:
        for rdx in range(init_values.shape[0]):
            fp_matrix[rdx] = FpBinary(int_bits=int_bits, frac_bits=frac_bits, signed=is_signed, value=init_values[rdx])
    else:
        for rdx in range(init_values.shape[0]):
            for cdx in range(init_values.shape[1]):
                fp_matrix[rdx,cdx] = FpBinary(int_bits=int_bits, frac_bits=frac_bits, signed=is_signed, value=init_values[rdx,cdx])

    return fp_matrix

def create_noisy_data(num_inputs, num_outputs, chars_in, chars_out, num_noisy_pixels, width, frac_bits):
    # Pick either
    char_select = random.choice(list(chars_in.keys()))
    noisy_vector = chars_in[char_select].copy()

    # Add up to a number of noisy pixels to noise-less input
    noisy_pixels = []
    positions = list(range(len(noisy_vector)))
    for ndx in range(num_noisy_pixels):
        noisy_pixel = random.choice(positions)
        positions.remove(noisy_pixel)
        noisy_vector[noisy_pixel] = -noisy_vector[noisy_pixel]
        noisy_pixels.append(noisy_pixel)

    # Save as fixed-point
    x = fp_create_list(width, frac_bits, True, noisy_vector)
    y = fp_create_list(width, frac_bits, True, chars_out[char_select])

    # Send binary strings as well
    x_str = []
    for xdx in range(len(x)):
        x_str.append(fp2bin(x[xdx], width, frac_bits))

    return x,x_str,y

@cocotb.test()
async def test_network_top(dut):
    # Static configuration
    num_inputs = 25
    num_hl_nodes = 16
    num_outputs = 5

    # Dynamic configuration
    width = int(os.getenv("FP_WIDTH", "8"))
    frac_bits = int(os.getenv("FP_FRAC_WIDTH", "3"))
    verbose = int(os.getenv("VERBOSE", "0"))

    # Load weights and bias
    weights_bundle = np.load("weights.npz", allow_pickle=True)
    temp = np.matrix.transpose(weights_bundle['fixed_w_hl'])
    hl_weights_in = fp_create_matrix(temp.shape, width, frac_bits, True, temp)
    print(f'info: Hidden layer weights matrix loaded with shape {hl_weights_in.shape}')

    temp = np.matrix.transpose(weights_bundle['fixed_b_hl'])
    hl_bias_in = fp_create_matrix(temp.shape, width, frac_bits, True, temp)
    print(f'info: Hidden layer bias vector loaded with shape {hl_bias_in.shape}')

    temp = np.matrix.transpose(weights_bundle['fixed_w_ol'])
    ol_weights_in = fp_create_matrix(temp.shape, width, frac_bits, True, temp)
    print(f'info: Output layer weights matrix loaded with shape {ol_weights_in.shape}')

    temp = np.matrix.transpose(weights_bundle['fixed_b_ol'])
    ol_bias_in = fp_create_matrix(temp.shape, width, frac_bits, True, temp)
    print(f'info: Output layer bias matrix loaded with shape {ol_bias_in.shape}')

    # Load boulder specs
    with open('inputs/noiseless_vowels_5x5.json') as fid:
        boulder_data = json.load(fid)

    chars_in = boulder_data["training"]
    chars_out = boulder_data["target"]

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

    # Weights and bias don't change
    for odx in range(num_hl_nodes):
        for idx in range(num_inputs):
            dut.HL_WEIGHTS_IN[odx*num_inputs+idx].value = int(get_bin_str(hl_weights_in[odx][idx], width, frac_bits), 2)

    for odx in range(num_outputs):
        for idx in range(num_hl_nodes):
            dut.OL_WEIGHTS_IN[odx*num_hl_nodes+idx].value = int(get_bin_str(ol_weights_in[odx][idx], width, frac_bits), 2)

    for odx in range(num_hl_nodes):
        dut.HL_BIAS_IN[odx].value = int(get_bin_str(hl_bias_in[odx][0], width, frac_bits), 2)

    for odx in range(num_outputs):
        dut.OL_BIAS_IN[odx].value = int(get_bin_str(ol_bias_in[odx][0], width, frac_bits), 2)

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

        # Generate random problem
        random_values_in,random_values_in_str,target_values = create_noisy_data(num_inputs, num_outputs, chars_in, chars_out, 0, width, frac_bits)


        #---- GOLDEN MODEL RUN --------------------------------------------------------------------

        # Run golden model on hidden layer
        hl_outputs = []
        for odx in range(num_hl_nodes):
            # Multiplication
            hl_neuron_muls = []
            for idx in range(num_inputs):
                hl_neuron_muls.append(hl_goldens[odx].do_op("mul", random_values_in[idx], hl_weights_in[odx][idx]))
            dbug_print(verbose, f'gldn: HL/N#{odx} after mul: {hl_neuron_muls}')

            # Accumulator
            for idx in range(num_inputs):
                hl_neuron_acc = hl_goldens[odx].do_op("acc", hl_neuron_muls[idx])
            hl_neuron_acc = hl_goldens[odx].do_op("acc", hl_bias_in[odx][0])
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
                ol_neuron_muls.append(ol_goldens[odx].do_op("mul", hl_outputs[idx], ol_weights_in[odx][idx]))
            dbug_print(verbose, f'gldn: OL/N#{odx} after mul: {ol_neuron_muls}')

            # Accumulator
            for idx in range(num_hl_nodes):
                ol_neuron_acc = ol_goldens[odx].do_op("acc", ol_neuron_muls[idx])
            ol_neuron_acc = ol_goldens[odx].do_op("acc", ol_bias_in[odx][0])
            dbug_print(verbose, f'gldn: OL/N#{odx} after acc: {ol_neuron_acc}')

            # Activation function
            ol_neuron_act_fun = ol_goldens[odx].do_op("act_fun", ol_neuron_acc)
            dbug_print(verbose, f'gldn: OL/N#{odx} after act_fun: {ol_neuron_act_fun}')
            
            # Save result
            net_outputs.append(ol_neuron_act_fun)


        #---- DESIGN RUN --------------------------------------------------------------------------

        await RisingEdge(dut.CLK)

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
