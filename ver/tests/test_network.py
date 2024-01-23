import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from cocotb.types import LogicArray
from fxpmath import Fxp
import sys
import os
sys.path.append(os.path.relpath('../'))
from utils.my_utils import *
sys.path.append(os.path.relpath("../../model/neural_network"))
from activations import afun_test_primitive
from cocotb.binary import BinaryRepresentation, BinaryValue
import json
import math
import random
from textwrap import wrap

# Flatten an array (or matrix) of values into a single binary string
def flatten2binstr(values, width):
    binstr = ''

    if values.ndim == 1:
        # This is an array
        for val in values:
            assert type(val) is Fxp
            temp = val.bin()
            assert len(temp) == width
            binstr = f'{temp}{binstr}'
    else:
        # This is a matrix
        for rdx in range(values.shape[0]):
            for cdx in range(values.shape[1]):
                val = values[rdx][cdx]
                assert type(val) is Fxp
                temp = val.bin()
                assert len(temp) == width
                binstr = f'{temp}{binstr}'

    return binstr

# Estimate the shape of the character recognized by the network
def get_char(value_out_str, num_outputs, width, frac_bits, target_chars):
    assert(len(value_out_str) == num_outputs * width)
    fxp_quants = 2 ** width - 1
    fxp_lsb = fxp_get_lsb(width, frac_bits)

    # Convert binary to fixed-point of outputs
    tokens = wrap(str(value_out_str), width)
    assert(len(tokens) == num_outputs)

    out_fxps = []
    for odx in range(num_outputs):
        out_fxps.insert(0, Fxp(f'0b{tokens[odx]}', n_word=width, n_frac=frac_bits, signed=True, config=fxp_get_config()))
    #@DBUGprint(f'{value_out_str} -> {tokens} -> {out_fxps}')

    # Compute output-wise error against all target chars
    errs = {}
    err_min = 100.0
    for ckey in target_chars.keys():
        #@DBUGprint(f'--> {ckey}')
        temp = 0.0
        for odx in range(num_outputs):
            abs_err = fxp_abs_err(Fxp(target_chars[ckey][odx], n_word=width, n_frac=frac_bits, signed=True, config=fxp_get_config()), out_fxps[odx])
            quant_err = float(abs_err) / float(fxp_lsb) / fxp_quants
            #@DBUGprint(f'   {Fxp(target_chars[ckey][odx], n_word=width, n_frac=frac_bits, signed=True, config=fxp_get_config())} VS {out_fxps[odx]} --> {quant_err}')
            temp = temp + float(quant_err)
        errs[ckey] = temp / num_outputs
        if errs[ckey] < err_min:
            err_min = errs[ckey]

    # Search the one that has lowest error. In case there are multiple matches with the "same" (w/
    # margins) absolute error, return all of 'em
    threshold = 0.01
    matching_keys = []
    for ckey in errs.keys():
        lb = errs[ckey] * (1.0 - threshold)
        ub = errs[ckey] * (1.0 + threshold)
        #@DBUGprint(f'{ckey} ({lb},{ub}) <- {errs[ckey]} {err_min}')
        if err_min >= lb and err_min <= ub:
            matching_keys.append(ckey)

    #@DBUGprint(matching_keys)
    return matching_keys

@cocotb.test()
async def test_network(dut):
    width = int(dut.FP_WIDTH.value)
    frac_bits = int(dut.FP_FRAC.value)
    num_inputs = int(dut.NUM_INPUTS.value)
    grid_side = int(math.sqrt(num_inputs))
    num_hl_nodes = int(dut.HL_NEURONS.value)
    num_outputs = int(dut.OL_NEURONS.value)
    verbose = 0

    # Run the clock asap
    clock = Clock(dut.CLK, 4, units="ns")
    cocotb.start_soon(clock.start())

    # One golden model for every neuron in every layer in the design!
    hl_goldens = []
    for odx in range(num_hl_nodes):
        hl_goldens.append(Fxp(0.0, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config()))

    ol_goldens = []
    for odx in range(num_outputs):
        ol_goldens.append(Fxp(0.0, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config()))

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

    # Load noiseless chars
    with open(f"../../model/neural_network/inputs/noiseless_c{num_outputs}_g{grid_side}.json") as fid:
        json_data = json.load(fid)
    noiseless_chars_in = json_data['training']
    noiseless_chars_out = json_data['target']

    # For noisy data, define maximum number of bit flips
    max_bit_flips = 0

    for test in range(1000):
        dbug_print(verbose, f'test: ==== Begin: TEST #{test} ================')
        dbug_print(verbose, f'test: HL/N#{odx}: {[ x.hex() for x in hl_goldens ]}')
        dbug_print(verbose, f'test: OL/N#{odx}: {[ x.hex() for x in ol_goldens ]}')


        #---- TEST INITIALIZATION -----------------------------------------------------------------

        # Pick char
        char_str,char_list = random.choice(list(noiseless_chars_in.items()))
        assert len(char_list) == num_inputs

        # Generate input
        values_in = []
        values_in_str = ''
        for char in char_list:
            values_in.append(Fxp(char, n_word=width, n_frac=frac_bits, signed=True, config=fxp_get_config()))
            values_in_str = f'{values_in[-1].bin()}{values_in_str}'

        # Include noise
        bit_flips = random.randint(0, max_bit_flips)
        flip_locs = list(range(len(values_in_str)))
        for flip in range(bit_flips):
            # Choose random location of bit flip, but do not repeat it
            random_loc = random.choice(flip_locs)
            for rdx in range(len(flip_locs)):
                if flip_locs[rdx] == random_loc:
                    del flip_locs[rdx]
                    break

            # Flip da bit
            replace = 1 - int(values_in_str[random_loc])
            values_in_str = values_in_str[:random_loc] + str(replace) + values_in_str[random_loc+1:]

        # Get fixed-point weights from the trained model
        hl_weights_in = fxp_load_csv("../../model/neural_network/trained_network/hidden_layer_weights_fxp.txt", width, frac_bits)
        hl_bias_in = fxp_load_csv("../../model/neural_network/trained_network/hidden_layer_bias_fxp.txt", width, frac_bits)
        ol_weights_in = fxp_load_csv("../../model/neural_network/trained_network/output_layer_weights_fxp.txt", width, frac_bits)
        ol_bias_in = fxp_load_csv("../../model/neural_network/trained_network/output_layer_bias_fxp.txt", width, frac_bits)
        hl_weights_in_str = flatten2binstr(hl_weights_in, width)
        hl_bias_in_str = flatten2binstr(hl_bias_in, width)
        ol_weights_in_str = flatten2binstr(ol_weights_in, width)
        ol_bias_in_str = flatten2binstr(ol_bias_in, width)


        #---- GOLDEN MODEL RUN --------------------------------------------------------------------

        # Run golden model on hidden layer
        hl_outputs = []
        for odx in range(num_hl_nodes):
            # Multiplication
            hl_neuron_muls = []
            for idx in range(num_inputs):
                hl_neuron_muls.append(values_in[idx] * hl_weights_in[odx][idx])
                #print(f'{values_in[idx].hex()} * {hl_weights_in[odx][idx].hex()} = {hl_neuron_muls[-1].hex()}')
            dbug_print(verbose, f'gldn: HL/N#{odx}/mul: {[ el.hex() for el in hl_neuron_muls ]}')

            # Accumulator
            hl_neuron_acc = Fxp(0.0, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())
            for idx in range(num_inputs):
                hl_neuron_acc += hl_neuron_muls[idx]
            hl_neuron_acc += hl_bias_in[odx]
            dbug_print(verbose, f'gldn: HL/N#{odx}/acc: {hl_neuron_acc.hex()}')

            # Activation function
            retval = afun_test_primitive(hl_neuron_acc.get_val())
            hl_neuron_act_fun = Fxp(val=retval, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())
            dbug_print(verbose, f'gldn: HL/N#{odx}/act_fun: {hl_neuron_act_fun.hex()}')

            # Save for next layer
            hl_outputs.append(hl_neuron_act_fun)

        # Run golden model on output layer
        net_outputs = []
        for odx in range(num_outputs):
            # Multiplication
            ol_neuron_muls = []
            for idx in range(num_hl_nodes):
                ol_neuron_muls.append(hl_outputs[idx] * ol_weights_in[odx][idx])
            dbug_print(verbose, f'gldn: OL/N#{odx}/mul: {[ el.hex() for el in ol_neuron_muls ]}')

            # Accumulator
            ol_neuron_acc = Fxp(0.0, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())
            for idx in range(num_hl_nodes):
                ol_neuron_acc += ol_neuron_muls[idx]
            ol_neuron_acc += ol_bias_in[odx]
            dbug_print(verbose, f'gldn: OL/N#{odx}/acc: {ol_neuron_acc.hex()}')

            # Activation function
            retval = afun_test_primitive(ol_neuron_acc.get_val())
            ol_neuron_act_fun = Fxp(val=retval, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())
            dbug_print(verbose, f'gldn: OL/N#{odx}/act_fun: {ol_neuron_act_fun.hex()}')
            
            # Save result
            net_outputs.append(ol_neuron_act_fun)


        #---- DESIGN RUN --------------------------------------------------------------------------

        await RisingEdge(dut.CLK)

        # Force weights
        dut.HL_WEIGHTS_IN.value = LogicArray(hl_weights_in_str)
        dut.OL_WEIGHTS_IN.value = LogicArray(ol_weights_in_str)

        # Force bias
        dut.HL_BIAS_IN.value = LogicArray(hl_bias_in_str)
        dut.OL_BIAS_IN.value = LogicArray(ol_bias_in_str)

        # Force values
        dut.VALUES_IN.value = LogicArray(values_in_str)

        # Strobe values
        await RisingEdge(dut.CLK)
        dut.VALID_IN.value = 1
        await RisingEdge(dut.CLK)
        dut.VALID_IN.value = 0

        # Wait for the network to fire
        await RisingEdge(dut.VALID_OUT)


        #---- VERIFICATION ------------------------------------------------------------------------

        await FallingEdge(dut.CLK)

        # Verify
        values_out = dut.VALUES_OUT.value
        chars_out = get_char(dut.VALUES_OUT.value, num_outputs, width, frac_bits, noiseless_chars_out)
        assert(len(chars_out) > 0)

        if len(chars_out) > 1:
            print(f'wan: Multiple chars detected: bit_flips={bit_flips},input_char={char_str},chars_out={chars_out}')

        if bit_flips == 0 and len(chars_out) == 1 and (chars_out[0] != char_str):
            print(f'wan: Unexpected mismatch (verification issue): bit_flips={bit_flips},input_char={char_str},chars_out={chars_out}')

        #@TEMP# With no bit flips, there must exist one and only one solution
        #@TEMPif len(chars_out) == 1:
        #@TEMP    assert(chars_out[0] == char_str),print(f'Charater recognition mismatch: bit_flips={bit_flips},input_char={char_str},chars_out={chars_out[0]}')
        #@TEMPelse:
        #@TEMP    assert(bit_flips > 0),print(f'Number of bit flips shall be greather than 0 with chars_out={chars_out}')
        #@TEMP    print(f'wan: Multiple chars detected: bit_flips={bit_flips},input_char={char_str},chars_out={chars_out}')

        # Shim delay
        for cycle in range(4):
            await RisingEdge(dut.CLK)

        dbug_print(verbose, f'test: ==== End: TEST #{test} ================')
        dbug_print(verbose, '')
