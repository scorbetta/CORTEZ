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

@cocotb.test()
async def test_fixed_point_abs(dut):
    # Config
    width = int(os.getenv("FP_WIDTH", "8"))
    frac_bits = int(os.getenv("FP_FRAC_WIDTH", "3"))

    # Run the clock asap
    clock = Clock(dut.CLK, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Golden model
    golden = golden_model(width, frac_bits)

    # Defaults
    dut.VALUE_IN.value = 0
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
        # Generate random values
        random_value_in_range,value_bit_string = get_random_fixed_point_value(width, frac_bits)
        value = FpBinary(int_bits=width-frac_bits, frac_bits=frac_bits, signed=True, value=random_value_in_range)

        # Golden model
        golden_result = golden.do_op("abs", value)

        # DUT
        await RisingEdge(dut.CLK)
        dut.VALUE_IN.value = int(value_bit_string, 2)
        dut.VALID_IN.value = 1
        await RisingEdge(dut.CLK)
        dut.VALID_IN.value = 0

        # Verify
        await FallingEdge(dut.VALID_OUT)
        dut_result = bin2fp(dut.VALUE_OUT.value.binstr, width, frac_bits)
        assert(dut_result == golden_result),print(f'Results mismatch: dut_result={dut_result},golden_result={golden_result},value={value}')

        # Shim delay
        for cycle in range(4):
            await RisingEdge(dut.CLK)