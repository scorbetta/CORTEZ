# Standard imports
import sys
import os
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

@cocotb.test()
async def test_fixed_point_act_fun(dut):
    # Config
    width = int(os.getenv("FP_WIDTH", "8"))
    frac_bits = int(os.getenv("FP_FRAC_WIDTH", "3"))

    # Run the clock asap
    clock = Clock(dut.CLK, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Golden model
    golden = golden_model(width, frac_bits)

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

    # Generate ramp of values within the arctan(x) domain of [-4:+4]
    ramp_values = np.arange(-4.0, 4.0, 0.001);

    for rdx in range(len(ramp_values)):
        value_a = FpBinary(int_bits=width-frac_bits, frac_bits=frac_bits, signed=True, value=ramp_values[rdx])
        value_a_bit_str = str(bin(value_a))[2:]
        golden_result = golden.do_op("act_fun", value_a)

        # DUT
        await RisingEdge(dut.CLK)
        dut.VALUE_IN.value = int(value_a_bit_str, 2)
        dut.VALID_IN.value = 1
        await RisingEdge(dut.CLK)
        dut.VALID_IN.value = 0
        await RisingEdge(dut.VALID_OUT)

        # Verify
        await FallingEdge(dut.CLK)
        dut_result = bin2fp(dut.VALUE_OUT.value.binstr, width, frac_bits)
        # Exact values not expected. Use double-sided margins instead...
        margin = 0.05
        golden_result_lb = abs(golden_result) * (1.0 - margin)
        golden_result_ub = abs(golden_result) * (1.0 + margin)
        assert(abs(dut_result) >= abs(golden_result_lb) and abs(dut_result) <= abs(golden_result_ub)),print(f'Results mismatch: rdx={rdx},value_in={value_a},dut_result={dut_result},golden_result={golden_result},golden_result_range=[{golden_result_lb},{golden_result_ub}]')

        # Shim delay
        for cycle in range(4):
            await RisingEdge(dut.CLK)
