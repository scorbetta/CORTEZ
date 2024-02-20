import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from cocotb.types import LogicArray
from random import randint
import sys
import os
sys.path.append(os.path.relpath('../'))
from utils.my_utils import *

@cocotb.test()
async def test_wb2sci_bridge(dut):
    num_hl_neurons = int(dut.NUM_HL_NEURONS.value)
    num_ol_neurons = int(dut.NUM_OL_NEURONS.value)
    hl_addr_width = int(dut.HL_ADDR_WIDTH.value)
    ol_addr_width = int(dut.OL_ADDR_WIDTH.value)
    num_hl_regs = (2 ** hl_addr_width) - 1
    num_ol_regs = (2 ** ol_addr_width) - 1
    addr_width = max([ hl_addr_width, ol_addr_width ])
    pad16 = ''.join([ '0' for _ in range(16) ])

    # Run the clock asap
    clock = Clock(dut.CLK, 10, units="ns")
    cocotb.start_soon(clock.start())

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

    for _ in range(1):
        # Select layer, neuron and register
        random_layer_select = randint(0, 1)
        if random_layer_select == 0:
            random_neuron_select = randint(0, num_hl_neurons)
            random_reg_select = randint(0, num_hl_regs)
        else:
            random_neuron_select = randint(0, num_ol_neurons)
            random_reg_select = randint(0, num_ol_regs)
        random_addr = f"{pad16}{random_layer_select}{random_neuron_select:07b}{random_reg_select:08b}"
        random_data = ''.join([ str(randint(0,1)) for _ in range(int(dut.DATA_WIDTH.value)) ])
        print(f'dbug: random_layer_select={random_layer_select},random_neuron_select={random_neuron_select},random_reg_select={random_reg_select} --> random_addr={random_addr}')

        # Random data
        #random_data = 

        # Write
        await RisingEdge(dut.CLK)
        dut.WB_CYC.value = 1
        dut.WB_STB.value = 1
        dut.WB_WE.value = 1
        dut.WB_ADDR.value = LogicArray(random_addr)
        dut.WB_WDATA.value = LogicArray(random_data)

        while 1:
            await FallingEdge(dut.CLK)
            if int(dut.WB_ACK.value) == 1:
                break
            await RisingEdge(dut.CLK)
        
        await RisingEdge(dut.CLK)
        dut.WB_CYC.value = 0
        dut.WB_STB.value = 0

        for _ in range(100):
            await RisingEdge(dut.CLK)
