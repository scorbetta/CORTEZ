# Standard imports
import sys
import os
import json
import numpy as np

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

async def wishbone_write_data(dut, write_addr, write_data):
    assert(dut.RST == 0),print('Reset shall be released before forcing AXI transaction')
    await RisingEdge(dut.CLK)

    dut.CYC.value = 1
    dut.STB.value = 1
    dut.WE.value = 1
    dut.SEL.value = 0
    dut.ADDR.value = write_addr
    dut.WDATA.value = write_data

    while True:
        await RisingEdge(dut.CLK)
        if dut.STB.value == 1 and dut.ACK.value == 1:
            dut.STB.value = 0
            break

    await RisingEdge(dut.CLK)
    dut.CYC.value = 0
    dut.STB.value = 0

async def wishbone_read_data(dut, read_addr):
    assert(dut.RST == 0),print('Reset shall be released before forcing AXI transaction')
    await RisingEdge(dut.CLK)

    dut.CYC.value = 1
    dut.STB.value = 1
    dut.WE.value = 0
    dut.SEL.value = 0
    dut.ADDR.value = read_addr

    while True:
        await RisingEdge(dut.CLK)
        if dut.STB.value == 1 and dut.ACK.value == 1:
            dut.STB.value = 0
            read_data = dut.RDATA.value
            break

    await RisingEdge(dut.CLK)
    dut.CYC.value = 0
    dut.STB.value = 0

    return read_data

@cocotb.test()
async def test_network_top_wrapper(dut):
    # Static configuration
    num_inputs = 25
    num_hl_nodes = 16
    num_outputs = 5
    width = 24
    frac_bits = 21

    # Dynamic configuration
    verbose = int(os.getenv("VERBOSE", "0"))

    # Load weights and bias from the trained network results, and store them into the register pool
    weights_folder = '../model/neural_network/trained_network'
    weights_bundle = np.load(f'{weights_folder}/weights.npz', allow_pickle=True)
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
    boulder_folder = '../model/neural_network/inputs'
    with open(f'{boulder_folder}/noiseless_vowels_5x5.json') as fid:
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
    dut.RSTN.value = 0
    dut.RST.value = 1
    dut.CYC.value = 0
    dut.STB.value = 0

    # Reset procedure w/ shim delay
    for cycle in range(4):
        await RisingEdge(dut.CLK)
    dut.RSTN.value = 1
    dut.RST.value = 0
    for cycle in range(4):
        await RisingEdge(dut.CLK)

    # Weights and bias don't change
    write_addr = 0x0
    for odx in range(num_hl_nodes):
        for idx in range(num_inputs):
            await wishbone_write_data(dut, write_addr, int(get_bin_str(hl_weights_in[odx][idx], width, frac_bits), 2))
            write_addr = write_addr + 0x4

    write_addr = 0x680
    for odx in range(num_outputs):
        for idx in range(num_hl_nodes):
            await wishbone_write_data(dut, write_addr, int(get_bin_str(ol_weights_in[odx][idx], width, frac_bits), 2))
            write_addr = write_addr + 0x4

    write_addr = 0x640
    for odx in range(num_hl_nodes):
        await wishbone_write_data(dut, write_addr, int(get_bin_str(hl_bias_in[odx][0], width, frac_bits), 2))
        write_addr = write_addr + 0x4

    write_addr = 0x7c0
    for odx in range(num_outputs):
        await wishbone_write_data(dut, write_addr, int(get_bin_str(ol_bias_in[odx][0], width, frac_bits), 2))
        write_addr = write_addr + 0x4

    for test in range(100):
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
        write_addr = 0x7d4
        for idx in range(num_inputs):
            await wishbone_write_data(dut, write_addr, int(random_values_in_str[idx], 2))
            write_addr = write_addr + 0x4

        # Strobe values
        await RisingEdge(dut.CLK)
        write_addr = 0x84c
        await wishbone_write_data(dut, write_addr, 0x2)
        await wishbone_write_data(dut, write_addr, 0x0)

        # Wait for the network to fire
        read_addr = 0x850
        while True:
            read_data = await wishbone_read_data(dut, read_addr)
            if read_data == 1:
                break

        # Read solution from registers
        read_addr = 0x838
        solution = []
        for idx in range(num_outputs):
            read_data = await wishbone_read_data(dut, read_addr)
            read_data_str = str(read_data)
            # Remove 8 MSBs!
            solution.append(read_data_str[8:])
            read_addr = read_addr + 0x4

        # Reset 
        write_addr = 0x84c
        await wishbone_write_data(dut, write_addr, 0x1)
        await wishbone_write_data(dut, write_addr, 0x0)


        #---- VERIFICATION ------------------------------------------------------------------------

        margin = 0.05
        for odx in range(num_outputs):
            dut_result = bin2fp(solution[odx], width, frac_bits)
            diff = abs(dut_result - net_outputs[odx])
            abs_err = diff / 2.0
            assert(abs_err <= margin),print(f'Results mismatch: test={test},odx={odx},dut_result={dut_result},golden_result={net_outputs[odx]},diff={diff},abs_err={abs_err},margin={margin}')

        # Shim delay
        for cycle in range(4):
            await RisingEdge(dut.CLK)

        dbug_print(verbose, f'test: ==== End: TEST #{test} ================')
        dbug_print(verbose, '')
