import sys
import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Combine
from cocotb.types import LogicArray
from random import *

# Wishbone class
class Wishbone:
    # Initialize
    def __init__(self, dut, prefix=''):
        self.dut = dut
        # Default naming for Wishbone signals
        self.name = {}
        self.name['cyc'] = f'{prefix}CYC'
        self.name['stb'] = f'{prefix}STB'
        self.name['we'] = f'{prefix}WE'
        self.name['addr'] = f'{prefix}ADDR'
        self.name['wdata'] = f'{prefix}WDATA'
        self.name['sel'] = f'{prefix}SEL'
        self.name['stall'] = f'{prefix}STALL'
        self.name['ack'] = f'{prefix}ACK'
        self.name['rdata'] = f'{prefix}RDATA'
        self.name['err'] = f'{prefix}ERR'
        self.name['clock'] = f'CLK'
        self.name['reset'] = f'RSTN'
        # Attached memory
        self.mem = {}
        self.prefix = prefix

    def overwrite_name(self, old, new):
        self.name[old] = new

    # Put interface idle
    def set_idle(self):
        self.dut._id(self.name['cyc'],extended=False).value = 0
        self.dut._id(self.name['stb'],extended=False).value = 0

    # Write request
    async def send_data(self, addr, data):
        await RisingEdge(self.dut._id(self.name['clock'],extended=False))
        self.dut._id(self.name['cyc'],extended=False).value = 1
        self.dut._id(self.name['stb'],extended=False).value = 1
        self.dut._id(self.name['we'],extended=False).value = 1
        self.dut._id(self.name['addr'],extended=False).value = addr
        self.dut._id(self.name['wdata'],extended=False).value = data
        self.dut._id(self.name['sel'],extended=False).value = 0

        while 1:
            await FallingEdge(self.dut._id(self.name['clock'],extended=False))
            if int(self.dut._id(self.name['ack'],extended=False).value) == 1:
                break
            await RisingEdge(self.dut._id(self.name['clock'],extended=False))
        
        await RisingEdge(self.dut._id(self.name['clock'],extended=False))
        self.set_idle()

    # Read request
    async def recv_data(self, addr):
        await RisingEdge(self.dut._id(self.name['clock'],extended=False))
        self.dut._id(self.name['cyc'],extended=False).value = 1
        self.dut._id(self.name['stb'],extended=False).value = 1
        self.dut._id(self.name['we'],extended=False).value = 0
        self.dut._id(self.name['addr'],extended=False).value = addr
        self.dut._id(self.name['sel'],extended=False).value = 0

        while 1:
            await FallingEdge(self.dut._id(self.name['clock'],extended=False))
            if int(self.dut._id(self.name['ack'],extended=False).value) == 1:
                break
            await RisingEdge(self.dut._id(self.name['clock'],extended=False))
        
        await RisingEdge(self.dut._id(self.name['clock'],extended=False))
        self.set_idle()
        return str(self.dut._id(self.name['rdata'],extended=False))

    # Simple Slave model
    async def start_slave(self):
        while 1:
            #@DBUGprint(f'dbug: [{self.prefix}] Waiting for start of transaction')
            while 1:
                await RisingEdge(self.dut._id(self.name['clock'],extended=False))
                await FallingEdge(self.dut._id(self.name['clock'],extended=False))
                if self.dut._id(self.name['cyc'],extended=False).value == 1 and self.dut._id(self.name['stb'],extended=False).value == 1:
                    break

            # Write or Read
            #@DBUGprint(f'dbug: [{self.prefix}] New transaction')
            if self.dut._id(self.name['we'],extended=False).value == 1:
                self.mem[str(self.dut._id(self.name['addr'],extended=False).value)] = self.dut._id(self.name['wdata'],extended=False).value
                #@DBUGprint(f"dbug: [{self.prefix}] After Write --> {self.mem}")
                await RisingEdge(self.dut._id(self.name['clock'],extended=False))
                self.dut._id(self.name['ack'],extended=False).value = 1
                await RisingEdge(self.dut._id(self.name['clock'],extended=False))
                self.dut._id(self.name['ack'],extended=False).value = 0
            else:
                #@DBUGprint(f"dbug: [{self.prefix}] Before Read --> {self.mem}")
                assert str(self.dut._id(self.name['addr'],extended=False)) in self.mem
                data = self.mem[str(self.dut._id(self.name['addr'],extended=False))]
                await RisingEdge(self.dut._id(self.name['clock'],extended=False))
                self.dut._id(self.name['ack'],extended=False).value = 1
                self.dut._id(self.name['rdata'],extended=False).value = data
                await RisingEdge(self.dut._id(self.name['clock'],extended=False))
                self.dut._id(self.name['ack'],extended=False).value = 0

