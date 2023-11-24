# Standard imports
import sys
import random
import time
import os

# Fixed-point and binary utils libraries
from fpbinary import FpBinary
from bitstring import BitArray

# (Foreign) reference activation function from the train model
sys.path.append(os.path.relpath("../model/neural_network"))
from activations import afun_test_primitive

# Utilities
from .my_utils import *

# The  golden_model  class is a container useful to verify fixed-point arithmetic operations done in
# hardware
class golden_model:
    def __init__(self, total_bits, frac_bits):
        self.format = (total_bits-frac_bits, frac_bits)
        self.reset_values()

    def reset_values(self):
        self.mul = FpBinary(int_bits=self.format[0], frac_bits=self.format[1], signed=True, value=0.0)
        self.acc = FpBinary(int_bits=self.format[0], frac_bits=self.format[1], signed=True, value=0.0)
        self.add = FpBinary(int_bits=self.format[0], frac_bits=self.format[1], signed=True, value=0.0)
        self.abs = FpBinary(int_bits=self.format[0], frac_bits=self.format[1], signed=True, value=0.0)
        self.act_fun = FpBinary(int_bits=self.format[0], frac_bits=self.format[1], signed=True, value=0.0)
        self.gt = 0
        self.eq = 0
        self.lt = 0

    def check(self, value):
        if value == None:
            return
        if not type(value) is FpBinary:
            print(f'erro: Unexpected operand type: {type(value)} (expected: FpBinary)')
            sys.exit()

    def do_op(self, op, value_a, value_b = None):
        # Preamble
        self.check(value_a)
        self.check(value_b)

        # Do operation
        match op:
            case "mac":
                self.mul = value_a * value_b
                self.mul = self.mul.resize(self.format)
                self.acc += self.mul
                self.acc = self.acc.resize(self.format)
                return self.acc
            
            case "add":
                self.add = value_a + value_b
                self.add = self.add.resize(self.format)
                return self.add

            case "mul":
                self.mul = value_a * value_b
                self.mul = self.mul.resize(self.format)
                return self.mul

            case "comp":
                self.gt = int(value_a > value_b)
                self.eq = int(value_a == value_b)
                self.lt = int(value_a < value_b)
                return self.gt,self.eq,self.lt

            case "acc":
                #temp1 = f'--> {self.acc}+{value_a}='
                self.acc = self.acc + value_a
                self.acc = self.acc.resize(self.format)
                #temp2 = f'{self.acc}'
                #print(f'{temp1}{temp2}')
                return self.acc

            case "act_fun":
                temp = afun_test_primitive(value_a)
                self.act_fun = FpBinary(int_bits=self.format[0], frac_bits=self.format[1], signed=True, value=temp)
                return self.act_fun

            case "abs":
                # The lowest negative number is a special case...
                if value_a == get_fixed_point_min_value(self.format[0]+self.format[1], self.format[1]):
                    self.abs = value_a
                elif value_a >= 0.0:
                    self.abs = value_a
                else:
                    self.abs = value_a * -1.0
                return self.abs

            case _:
                print(f'erro: Operation {op} not supported')
                sys.exit()

    def to_str(self):
        return f'gldn: Contents: mul={self.mul},acc={self.acc},add={self.add},abs={self.abs},gt={self.gt},eq={self.eq},lt={self.lt}'
