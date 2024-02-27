import numpy as np
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from fxpmath import *
import sys
import os
sys.path.append(os.path.relpath('../'))
from utils.my_utils import *
sys.path.append(os.path.relpath("../../../model/neural_network"))
from activations import afun_test_primitive

@cocotb.test()
async def test_fixed_point_act_fun(dut):
    width = int(dut.WIDTH.value)
    frac_bits = int(dut.FRAC_BITS.value)

    fxp_min,fxp_max = fxp_get_range(width, frac_bits)
    fxp_lsb = fxp_get_lsb(width, frac_bits)
    fxp_quants = 2 ** width - 1

    # Run the clock asap
    clock = Clock(dut.CLK, 10, units="ns")
    cocotb.start_soon(clock.start())

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

    # Generate ramp of values within the arctan(x) domain supported by the current fixed-point
    # configuration. Step is chosen lower than the fixed-point LSB to test roundings as well
    ramp_values = np.arange(fxp_min.get_val(), fxp_max.get_val(), fxp_lsb.get_val());

    rel_err = 0.0
    for rdx in range(len(ramp_values)):
        value_a = Fxp(val=ramp_values[rdx], signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())

        # Model
        retval = afun_test_primitive(value_a.get_val())
        golden_result = Fxp(val=retval, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())

        # DUT
        await RisingEdge(dut.CLK)
        dut.VALUE_IN.value = int(value_a.hex(),16)
        dut.VALID_IN.value = 1
        await RisingEdge(dut.CLK)
        dut.VALID_IN.value = 0

        await RisingEdge(dut.VALID_OUT)
        await FallingEdge(dut.CLK)
        dut_result = Fxp(val=f'0b{dut.VALUE_OUT.value}', signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())

        # Verify result is within margins
        threshold = 0.01
        abs_err = fxp_abs_err(golden_result, dut_result)
        quant_err = float(abs_err) / float(fxp_lsb) / fxp_quants
        assert(quant_err <= threshold),print(f'Results differ more than {threshold*100}% LSBs: dut_result={dut_result},golden_result={golden_result},abs_err={abs_err},quant_error={quant_err}')

        # Shim delay
        for cycle in range(4):
            await RisingEdge(dut.CLK)
