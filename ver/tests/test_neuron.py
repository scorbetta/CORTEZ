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
async def test_neuron(dut):
    width = int(dut.WIDTH.value)
    frac_bits = int(dut.FRAC_BITS.value)
    num_inputs = int(dut.NUM_INPUTS.value)
    fxp_lsb = fxp_get_lsb(width, frac_bits)
    fxp_quants = 2 ** width - 1
    verbose = 0

    # Run the clock asap
    clock = Clock(dut.CLK, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Defaults
    dut.VALID_IN.value = 0
    dut.RSTN.value = 0
    dut.CSN.value = 1
    dut.SIN.value = 0

    # Reset procedure
    for cycle in range(4):
        await RisingEdge(dut.CLK)
    dut.RSTN.value = 1

    # Shim delay
    for cycle in range(4):
        await RisingEdge(dut.CLK)

    overflow_cnt = 0
    rel_errs = []
    runs = 100
    for test in range(runs):
        # Generate random values
        random_values_in = []
        for vdx in range(num_inputs):
            random_value = fxp_generate_random(width, frac_bits)
            random_values_in.append(random_value)

        # Generate random weights
        random_weights_in = []
        for vdx in range(num_inputs):
            random_value = fxp_generate_random(width, frac_bits)
            random_weights_in.append(random_value)
        dbug_print(verbose, f'random_weights={random_weights_in}')

        # Generate random bias
        random_bias_in = fxp_generate_random(width, frac_bits)
        dbug_print(verbose, f'random_bias={random_bias_in}')

        # Configure the neuron weights through the SCI interface
        for vdx in range(num_inputs):
            # Select peripheral and send Write op
            await RisingEdge(dut.CLK)
            dut.CSN.value = 0
            dut.SIN.value = 1

            # Send address, data pairs
            curr_addr = format(vdx, f'05b')
            curr_data = random_weights_in[vdx].bin()

            for bit in reversed(curr_addr):
                await RisingEdge(dut.CLK)
                dut.SIN.value = int(bit)

            for bit in reversed(curr_data):
                await RisingEdge(dut.CLK)
                dut.SIN.value = int(bit)

            await RisingEdge(dut.CLK)
            dut.CSN.value = 1

        # Configure the neuron bias
        await RisingEdge(dut.CLK)
        dut.CSN.value = 0
        dut.SIN.value = 1
        curr_addr = format(num_inputs, f'05b')
        curr_data = random_bias_in.bin()
        for bit in reversed(curr_addr):
            await RisingEdge(dut.CLK)
            dut.SIN.value = int(bit)
        for bit in reversed(curr_data):
            await RisingEdge(dut.CLK)
            dut.SIN.value = int(bit)
        await RisingEdge(dut.CLK)
        dut.CSN.value = 1

        # Run parallel multiplications on golden model
        golden_model_muls = []
        for vdx in range(num_inputs):
            golden_model_muls.append(random_values_in[vdx] * random_weights_in[vdx])
            dbug_print(verbose, f'gldn: MUL[{vdx}] {random_values_in[vdx].hex()}*{random_weights_in[vdx].hex()}={golden_model_muls[-1].hex()}')

        # Run accumulator on golden model
        golden_model_acc = Fxp(0.0, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())
        for vdx in range(num_inputs):
            golden_model_acc += golden_model_muls[vdx]
        golden_model_acc += random_bias_in
        dbug_print(verbose, f'gldn: ACC {golden_model_acc.hex()}')

        # Run activation function on golden model
        retval = afun_test_primitive(golden_model_acc.get_val())
        golden_result = Fxp(val=retval, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())
        dbug_print(verbose, f'gldn: ACT {golden_result.hex()}')

        # Run DUT
        for vdx in range(num_inputs):
            await RisingEdge(dut.CLK)
            dut.VALUE_IN.value = int(random_values_in[vdx].bin(),2)
            dut.VALID_IN.value = 1
            await RisingEdge(dut.CLK)
            dut.VALID_IN.value = 0

            await RisingEdge(dut.add_done)
            for _ in range(2):
                await RisingEdge(dut.CLK)

        for _ in range(10):
            await RisingEdge(dut.CLK)
        
        if dut.OVERFLOW.value == 0:
            threshold = 0.10

            # Verify accumulator
            dut_result = Fxp(val=f'0b{str(dut.biased_acc_out.value.binstr)}', signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())
            abs_err = fxp_abs_err(golden_model_acc, dut_result)
            quant_err = float(abs_err) / float(fxp_lsb) / fxp_quants
            assert(quant_err <= threshold),print(f'Results for ACC differ more than {threshold*100}% LSBs: dut_result={dut_result},golden_result={golden_model_acc},abs_err={abs_err},quant_error={quant_err}')
            #@DBUGprint(f'acc: {dut_result}/{dut_result.hex()},{golden_model_acc},{abs_err},{quant_err}')

            # Verify output
            dut_result = Fxp(val=f'0b{str(dut.VALUE_OUT.value.binstr)}', signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())
            abs_err = fxp_abs_err(golden_result, dut_result)
            quant_err = float(abs_err) / float(fxp_lsb) / fxp_quants
            assert(quant_err <= threshold),print(f'Results for ACT differ more than {threshold*100}% LSBs: dut_result={dut_result},golden_result={golden_result},abs_err={abs_err},quant_error={quant_err}')
            #@DBUGprint(f'act: {dut_result}/{dut_result.hex()},{golden_result},{abs_err},{quant_err}')
        else:
            overflow_cnt = overflow_cnt + 1

        # Shim delay
        for cycle in range(4):
            await RisingEdge(dut.CLK)
    
    print(f'warn: Number of unchecked outputs due to overflow: {overflow_cnt} ({overflow_cnt*1.0/runs*100}%)')
