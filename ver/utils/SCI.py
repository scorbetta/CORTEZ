import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Combine
from cocotb.types import LogicArray
import sys
import os
sys.path.append(os.path.relpath('./'))
from .my_utils import *

# Serial Control Interface class
class SCI:
    # Initialize. When sharing the chip-select signal with multiple peripherals (each with its own
    # address and data specs), just be sure to count  num_peripherals  properly
    def __init__(self, dut, num_peripherals=1, addr_width=4, data_width=8, prefix=''):
        # Default naming for AXI4 Lite signals
        self.name = {}
        self.name['clock'] = f'CLK'
        self.name['reset'] = f'RSTN'
        self.name['csn'] = f'{prefix}CSN'
        self.name['sin'] = f'{prefix}SIN'
        self.name['sout'] = f'{prefix}SOUT'
        self.name['sack'] = f'{prefix}SACK'
        self.dut = dut
        self.num_peripherals = num_peripherals
        self.addr_width = addr_width
        self.data_width = data_width

    # Get the CSN mask for the selected peripheral
    def get_mask(self, pid):
        # Initialize to all 1's
        mask = '1' * self.num_peripherals

        if pid >= 0 and pid < self.num_peripherals:
            real_pid = stringify(pid, self.num_peripherals)
            mask = mask[:real_pid] + '0' + mask[real_pid+1:]

        return mask

    # Put the interface in idle mode
    def set_idle(self):
        self.dut._id(self.name['csn'],extended=False).value = LogicArray(self.get_mask(-1))
        self.dut._id(self.name['sin'],extended=False).value = 0

    # Standard reset procedure
    async def reset(self):
        self.dut._id(self.name['reset'],extended=False).value = 0
        for cycle in range(4):
            await RisingEdge(self.dut._id(self.name['clock'],extended=False))
        self.dut._id(self.name['reset'],extended=False).value = 1

        # Shim delay
        for cycle in range(4):
            await RisingEdge(self.dut._id(self.name['clock'],extended=False))

    # Write data
    async def write(self, pid, addr, data):
        addr_str = addr
        if type(addr) is not str:
            assert type(addr) is int
            addr_str = format(addr, f'0{self.addr_width}b')

        data_str = data
        if type(data) is not str:
            assert type(data) is int
            data_str = format(data, f'0{self.data_width}b')

        #print(f'dbug: SCI Write @+{hex(int(addr_str,2))} data={hex(int(data_str,2))} csn={LogicArray(self.get_mask(pid))}')

        await RisingEdge(self.dut._id(self.name['clock'],extended=False))
        self.dut._id(self.name['csn'],extended=False).value = LogicArray(self.get_mask(pid))
        self.dut._id(self.name['sin'],extended=False).value = 1

        for bit in reversed(addr_str):
            await RisingEdge(self.dut._id(self.name['clock'],extended=False))
            self.dut._id(self.name['csn'],extended=False).value = LogicArray(self.get_mask(pid))
            self.dut._id(self.name['sin'],extended=False).value = int(bit)

        for bit in reversed(data_str):
            await RisingEdge(self.dut._id(self.name['clock'],extended=False))
            self.dut._id(self.name['csn'],extended=False).value = LogicArray(self.get_mask(pid))
            self.dut._id(self.name['sin'],extended=False).value = int(bit)

        await RisingEdge(self.dut._id(self.name['clock'],extended=False))
        self.dut._id(self.name['csn'],extended=False).value = LogicArray(self.get_mask(-1))
