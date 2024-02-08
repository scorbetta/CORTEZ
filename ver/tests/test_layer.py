import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from fxpmath import Fxp
import sys
import os
sys.path.append(os.path.relpath('../'))
from utils.my_utils import *
from utils.SCI import *
sys.path.append(os.path.relpath("../../model/neural_network"))
from activations import afun_test_primitive

@cocotb.test()
async def test_layer(dut):
    # Config
    width = int(dut.WIDTH.value)
    frac_bits = int(dut.FRAC_BITS.value)
    num_inputs = int(dut.NUM_INPUTS.value)
    num_outputs = int(dut.NUM_OUTPUTS.value)
    sci_addr_width = int(os.environ['SCI_ADDR_WIDTH'])
    verbose = 0

    fxp_lsb = fxp_get_lsb(width, frac_bits)
    fxp_quants = 2 ** width - 1
    sci_obj = SCI(num_outputs, sci_addr_width, width)

    # Run the clock asap
    clock = Clock(dut.CLK, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Defaults
    dut.VALID_IN.value = 0
    dut.RSTN.value = 0
    dut.CSN.value = int(f'{int(sci_obj.get_mask(-1),2)}')

    # Reset procedure
    for cycle in range(4):
        await RisingEdge(dut.CLK)
    dut.RSTN.value = 1

    # Shim delay
    for cycle in range(4):
        await RisingEdge(dut.CLK)

    rel_errs = []
    for test in range(100):
        dbug_print(verbose, f'\ntest: ==== Begin: TEST #{test} ================')

        # Generate random values
        random_values_in = []
        for vdx in range(num_inputs):
            random_value = fxp_generate_random(width, frac_bits)
            random_values_in.append(random_value)
        dbug_print(verbose, f'test: Input vector: {random_values_in}')

        # Generate random weights/bias and configure neurons
        random_weights_in = []
        for odx in range(num_outputs):
            temp = []
            temp_str = ""
            for idx in range(num_inputs):
                random_value = fxp_generate_random(width, frac_bits)
                temp.append(random_value)
                temp_str = f'{random_value.bin()}{temp_str}'
                await sci_obj.write(dut, odx, idx, random_value.bin())
            random_weights_in.append(temp)
        dbug_print(verbose, f'test: Input weights: {random_weights_in}')

        random_bias_in = []
        for odx in range(num_outputs):
            random_value = fxp_generate_random(width, frac_bits)
            random_bias_in.append(random_value)
            await sci_obj.write(dut, odx, num_inputs, random_value.bin())
        dbug_print(verbose, f'test: Input bias: {random_bias_in}')

        # Run golden model and DUT on all input values
        golden_muls = []
        for idx in range(num_inputs):
            temp = []
            for odx in range(num_outputs):
                temp.append(Fxp(0.0, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config()))
            golden_muls.append(temp)

        dut_muls = []
        for idx in range(num_inputs):
            temp = []
            for odx in range(num_outputs):
                temp.append(Fxp(0.0, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config()))
            dut_muls.append(temp)

        for idx in range(num_inputs):
            value_in = random_values_in[idx]

            # Multiplication
            dbug_print(verbose, f'---- Verifying multiplication #{idx}/{num_inputs-1} --------')
            for odx in range(num_outputs):
                golden_muls[idx][odx] = value_in * random_weights_in[odx][idx]
 
            await wait_for_value(dut.CLK, dut.READY, 1)
            await RisingEdge(dut.CLK)
            dut.VALID_IN.value = 1
            dut.VALUE_IN.value = int(value_in.hex(),16)
            await RisingEdge(dut.CLK)
            dut.VALID_IN.value = 0
            for odx in range(num_outputs):
                await wait_for_value(dut.CLK, dut.genblk1[odx].NEURON.mul_done, 1)
                dut_muls[idx][odx] = Fxp(val=f'0b{dut.genblk1[odx].NEURON.mul_value_out.value}', signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())

            dbug_print(verbose, f'gldn: mul: {[ [ x.hex() for x in line ] for line in golden_muls ]}')
            dbug_print(verbose, f' dut: mul: {[ [ x.hex() for x in line ] for line in dut_muls ]}')

            for odx in range(num_outputs):
                fxp_verify_in_range(golden_muls[idx][odx], dut_muls[idx][odx], width, frac_bits)

        # Accumulator
        dbug_print(verbose, f'---- Verifying accumulator --------')

        golden_accs = []
        for odx in range(num_outputs):
            golden_accs.append(Fxp(0.0, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config()))

        dut_accs = []
        for odx in range(num_outputs):
            dut_accs.append(Fxp(0.0, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config()))

        for odx in range(num_outputs):
            for idx in range(num_inputs):
                golden_accs[odx] += golden_muls[idx][odx]
            golden_accs[odx] += random_bias_in[odx]
        
        for odx in range(num_outputs):
            await wait_for_value(dut.CLK, dut.genblk1[odx].NEURON.bias_add_done, 1)
            dut_accs[odx] = Fxp(val=f'0b{dut.genblk1[odx].NEURON.biased_acc_out.value}', signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())

        dbug_print(verbose, f'gldn: acc: {[ x.hex() for x in golden_accs ]}')
        dbug_print(verbose, f' dut: acc: {[ x.hex() for x in dut_accs ]}')

        for odx in range(num_outputs):
            fxp_verify_in_range(golden_accs[odx], dut_accs[odx], width, frac_bits)

        # Activation function
        dbug_print(verbose, f'---- Verifying activation function --------')

        golden_acts = []
        for odx in range(num_outputs):
            retval = afun_test_primitive(golden_accs[odx].get_val())
            golden_acts.append(Fxp(val=retval, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config()))

        dut_acts = []
        for odx in range(num_outputs):
            dut_acts.append(Fxp(0.0, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config()))
        
        # Activation functions can fire at different times, so we cannot rely on a single point of
        # observation for the  act_done  signal
        fired = [ 0 for x in range(num_outputs) ]
        while sum(fired) < num_outputs:
            await RisingEdge(dut.CLK)
            await FallingEdge(dut.CLK)

            for odx in range(num_outputs):
                if int(dut.genblk1[odx].NEURON.act_done) == 1 and fired[odx] == 0:
                    fired[odx] = 1
                    dut_acts[odx] = Fxp(val=f'0b{dut.genblk1[odx].NEURON.VALUE_OUT.value}', signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())

        dbug_print(verbose, f'gldn: act: {[ x.hex() for x in golden_acts ]}')
        dbug_print(verbose, f' dut: act: {[ x.hex() for x in dut_acts ]}')

        for odx in range(num_outputs):
            fxp_verify_in_range(golden_acts[odx], dut_acts[odx], width, frac_bits)

        # Shim delay
        for cycle in range(4):
            await RisingEdge(dut.CLK)
