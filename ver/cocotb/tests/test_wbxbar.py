import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from cocotb.types import LogicArray
from random import randint
import sys
import os
sys.path.append(os.path.relpath('../'))
from utils.my_utils import *
from utils.Wishbone import *

@cocotb.test()
async def test_wbxbar(dut):
    pad15 = ''.join([ '0' for _ in range(15) ])

    # Run the clock asap
    clock = Clock(dut.CLK, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Wishbone Master and Slaves
    wbm_obj = Wishbone(dut, prefix='WBM_')
    wbs0_obj = Wishbone(dut, prefix='WBS0_')
    wbs1_obj = Wishbone(dut, prefix='WBS1_')

    # Defaults
    dut.RSTN.value = 0
    wbm_obj.set_idle()

    # Reset procedure
    for cycle in range(4):
        await RisingEdge(dut.CLK)
    dut.RSTN.value = 1

    # Shim delay
    for cycle in range(4):
        await RisingEdge(dut.CLK)

    # Start Slaves
    cocotb.start_soon(wbs0_obj.start_slave())
    cocotb.start_soon(wbs1_obj.start_slave())

    for _ in range(1000):
        # Select slave
        random_slave_select = randint(0, 1)
        random_offset = ''.join([ str(randint(0,1)) for _ in range(16) ])
        random_addr = f"{pad15}{random_slave_select}{random_offset}"
        random_data = ''.join([ str(randint(0,1)) for _ in range(8) ])

        # Write
        await RisingEdge(dut.CLK)
        await wbm_obj.send_data(int(random_addr,2), int(random_data,2))
        for _ in range(4):
            await RisingEdge(dut.CLK)

        # Read
        await RisingEdge(dut.CLK)
        rdata = await wbm_obj.recv_data(int(random_addr,2))
        for _ in range(4):
            await RisingEdge(dut.CLK)

        # Verify data
        assert rdata == random_data

        for _ in range(10):
            await RisingEdge(dut.CLK)
