import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from random import randint
import sys
import os
sys.path.append(os.path.relpath('../'))
from utils.my_utils import *

@cocotb.test()
async def test_sequencer(dut):
    width = int(dut.WIDTH.value)
    num_inputs = int(dut.NUM_INPUTS.value)

    # Run the clock asap
    clock = Clock(dut.CLK, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Defaults
    dut.VALID_IN.value = 0
    dut.TRIGGER.value = 0
    dut.RSTN.value = 0

    # Reset procedure
    for cycle in range(4):
        await RisingEdge(dut.CLK)
    dut.RSTN.value = 1

    # Shim delay
    for cycle in range(4):
        await RisingEdge(dut.CLK)

    # Recognizable input values
    values_in_str = ''
    for vdx in range(num_inputs):
        vdx_bin = format(vdx, f'0{width}b')
        values_in_str = f'{vdx_bin}{values_in_str}'

    # Run DUT
    await RisingEdge(dut.CLK)
    dut.VALUES_IN.value = int(values_in_str,2)
    dut.VALID_IN.value = 1
    await RisingEdge(dut.CLK)
    dut.VALID_IN.value = 0

    for vdx in range(num_inputs):
        # Wait random delay before triggering
        random_wait = randint(4, 10)
        for _ in range(random_wait):
            await RisingEdge(dut.CLK)
        dut.TRIGGER.value = 1
        await RisingEdge(dut.CLK)
        dut.TRIGGER.value = 0
        await FallingEdge(dut.CLK)
        assert int(dut.VALID_OUT.value) == 1
        assert int(dut.VALUE_OUT.value) == vdx
        for _ in range(10):
            await RisingEdge(dut.CLK)
