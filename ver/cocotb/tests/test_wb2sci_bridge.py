import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from cocotb.types import LogicArray
from random import randint
import sys
import os
sys.path.append(os.path.relpath('../'))
from utils.my_utils import *
from utils.SCI import *

@cocotb.test()
async def test_wb2sci_bridge(dut):
    num_hl_neurons = int(dut.NUM_HL_NEURONS.value)
    num_ol_neurons = int(dut.NUM_OL_NEURONS.value)
    hl_addr_width = int(dut.HL_ADDR_WIDTH.value)
    ol_addr_width = int(dut.OL_ADDR_WIDTH.value)
    num_hl_regs = 17
    num_ol_regs = 9
    pad16 = ''.join([ '0' for _ in range(16) ])

    # Prepare address and data length vectors. Map HL neurons on the lower indexes
    addr_widths = [ hl_addr_width ] * num_hl_neurons
    addr_widths.extend([ ol_addr_width ] * num_ol_neurons)
    data_widths = [ int(dut.DATA_WIDTH.value) ] * (num_hl_neurons + num_ol_neurons)

    # Run the clock asap
    clock = Clock(dut.CLK, 10, units="ns")
    cocotb.start_soon(clock.start())

    # SCI Slave starts asap
    sci_obj = SCI(num_hl_neurons+num_ol_neurons, prefix='SCI_')
    cocotb.start_soon(sci_obj.start_slave(dut, addr_widths, data_widths))

    # Defaults
    dut.RSTN.value = 0
    dut.RST.value = 1
    dut.WB_CYC.value = 0
    dut.WB_STB.value = 0
    dut.WB_WE.value = 0

    # Reset procedure
    for cycle in range(4):
        await RisingEdge(dut.CLK)
    dut.RSTN.value = 1
    dut.RST.value = 0

    # Shim delay
    for cycle in range(4):
        await RisingEdge(dut.CLK)

    for _ in range(1000):
        # Select layer, neuron and register
        random_layer_select = randint(0, 1)
        if random_layer_select == 0:
            random_neuron_select = randint(0, num_hl_neurons-1)
            random_reg_select = randint(0, num_hl_regs-1)
        else:
            random_neuron_select = randint(0, num_ol_neurons-1)
            random_reg_select = randint(0, num_ol_regs-1)
        random_addr = f"{pad16}{random_layer_select}{random_neuron_select:07b}{random_reg_select:08b}"
        random_data = ''.join([ str(randint(0,1)) for _ in range(int(dut.DATA_WIDTH.value)) ])

        # Write
        await RisingEdge(dut.CLK)
        dut.WB_CYC.value = 1
        dut.WB_STB.value = 1
        dut.WB_WE.value = 1
        dut.WB_ADDR.value = LogicArray(random_addr)
        dut.WB_WDATA.value = LogicArray(random_data)
        await RisingEdge(dut.WB_ACK)
        await RisingEdge(dut.CLK)
        dut.WB_CYC.value = 0
        dut.WB_STB.value = 0
        for _ in range(4):
            await RisingEdge(dut.CLK)

        # Read
        await RisingEdge(dut.CLK)
        dut.WB_CYC.value = 1
        dut.WB_STB.value = 1
        dut.WB_WE.value = 0
        dut.WB_ADDR.value = LogicArray(random_addr)
        await RisingEdge(dut.WB_ACK)
        await RisingEdge(dut.CLK)
        dut.WB_CYC.value = 0
        dut.WB_STB.value = 0

        # Verify data
        await FallingEdge(dut.CLK)
        assert str(dut.WB_RDATA.value) == random_data

        for _ in range(10):
            await RisingEdge(dut.CLK)
