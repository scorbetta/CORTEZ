import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, with_timeout
import os
from fpbinary import FpBinary
from .golden_model import *

@cocotb.test()
async def test_neuron(dut):
    # Config
    width = int(os.getenv("FP_WIDTH", "8"))
    frac_bits = int(os.getenv("FP_FRAC_WIDTH", "3"))
    num_inputs = int(os.getenv("NUM_INPUTS", "1"))

    # Run the clock asap
    clock = Clock(dut.CLK, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Golden model for fixed-point operations
    golden = golden_model(width, frac_bits)
    golden.reset_values()

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

    for test in range(1000):
        # Generate random values
        random_values_in = []
        random_values_in_str = []
        for vdx in range(num_inputs):
            random_value,random_value_bit_str = get_random_fixed_point_value(width, frac_bits)
            value = FpBinary(int_bits=width-frac_bits, frac_bits=frac_bits, signed=True, value=random_value)
            random_values_in.append(value)
            random_values_in_str.append(random_value_bit_str)

        # Generate random weights
        random_weights_in = []
        random_weights_in_str = []
        for vdx in range(num_inputs):
            random_value,random_value_bit_str = get_random_fixed_point_value(width, frac_bits)
            value = FpBinary(int_bits=width-frac_bits, frac_bits=frac_bits, signed=True, value=random_value)
            random_weights_in.append(value)
            random_weights_in_str.append(random_value_bit_str)

        # Generate random bias
        random_value,random_value_bit_str = get_random_fixed_point_value(width, frac_bits)
        random_bias_in = FpBinary(int_bits=width-frac_bits, frac_bits=frac_bits, signed=True, value=random_value)
        random_bias_in_str = random_value_bit_str

        # Run parallel multiplications on golden model
        golden_model_muls = []
        for vdx in range(num_inputs):
            golden_model_muls.append(golden.do_op("mul", random_values_in[vdx], random_weights_in[vdx]))

        # Run accumulator on golden model
        for vdx in range(num_inputs):
            golden_model_acc = golden.do_op("acc", golden_model_muls[vdx])

        # Add bias
        golden_model_acc = golden.do_op("acc", random_bias_in)

        # Run activation function on golden model
        golden_model_act_fun = golden.do_op("act_fun", golden_model_acc)

        # We are verifying the output of the activation function
        golden_result = golden_model_act_fun

        # Run DUT
        await RisingEdge(dut.CLK)
        for vdx in range(num_inputs):
            dut.VALUES_IN[vdx].value = int(random_values_in_str[vdx], 2)
            dut.WEIGHTS_IN[vdx].value = int(random_weights_in_str[vdx], 2)
        dut.BIAS_IN.value = int(random_bias_in_str, 2)
        
        await RisingEdge(dut.CLK)
        dut.VALID_IN.value = 1
        await RisingEdge(dut.CLK)
        dut.VALID_IN.value = 0

        # Verify
        await RisingEdge(dut.VALID_OUT)
        await FallingEdge(dut.CLK)
        dut_result = bin2fp(dut.VALUE_OUT.value.binstr, width, frac_bits)
        # Exact values not expected. Use double-sided margins instead...
        margin = 0.05
        golden_result_lb = abs(golden_result) * (1.0 - margin)
        golden_result_ub = abs(golden_result) * (1.0 + margin)
        assert(abs(dut_result) >= abs(golden_result_lb) and abs(dut_result) <= abs(golden_result_ub)),print(f'Results mismatch: test={test},dut_result={dut_result},golden_result={golden_result},golden_result_range=[{golden_result_lb},{golden_result_ub}]')

        # Shim delay
        for cycle in range(4):
            await RisingEdge(dut.CLK)
