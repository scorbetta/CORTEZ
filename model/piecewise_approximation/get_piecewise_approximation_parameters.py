#!/usr/bin/python3

# Generate the parameters of the piecewise approximation for the RTL design

from fxpmath import *
import numpy as np
import sys
import os
sys.path.append(os.path.relpath("../../ver/utils"))
from my_utils import *

def get_string(float_value, word_bits, frac_bits):
    value_fixed = Fxp(float_value, n_word=word_bits, n_frac=frac_bits, signed=True, config=fxp_get_config())
    hex_str = str(value_fixed.hex())
    value_fixed_str = f"{word_bits}'h{hex_str[2:]}"
    return value_fixed_str,str(value_fixed.get_val())

# Load template file
with open("PIECEWISE_APPROXIMATION_PARAMETERS.vh.template") as file:
    template = file.read()

# Number of bits for the integral and fractional parts
word_bits = int(sys.argv[1])
frac_bits = int(sys.argv[2])
int_bits = word_bits - frac_bits

template = template.replace("__WORD_WIDTH__", str(word_bits))
template = template.replace("__INT_BITS__", str(int_bits))
template = template.replace("__FRAC_BITS__", str(frac_bits))

# Convert desired float values to fixed-point representation, then convert them to binary string
# before writing their hexadecimale representation to file
target_value_float = 0.0
val_hex,val_fix = get_string(target_value_float, word_bits, frac_bits)
template = template.replace("__F0_X_HEX__", val_hex)
template = template.replace("__F0_X_FIXED__", val_fix)
template = template.replace("__F0_X_FLOAT__", str(target_value_float))

target_value_float = np.arctanh(np.sqrt(1.0/3.0))
val_hex,val_fix = get_string(target_value_float, word_bits, frac_bits)
template = template.replace("__Z3_X_HEX__", val_hex)
template = template.replace("__Z3_X_FIXED__", val_fix)
template = template.replace("__Z3_X_FLOAT__", str(target_value_float))

target_value_float = np.arctanh(np.sqrt(2.0/3.0))
val_hex,val_fix = get_string(target_value_float, word_bits, frac_bits)
template = template.replace("__Z4_X_HEX__", val_hex)
template = template.replace("__Z4_X_FIXED__", val_fix)
template = template.replace("__Z4_X_FLOAT__", str(target_value_float))

target_value_float = 2.0
val_hex,val_fix = get_string(target_value_float, word_bits, frac_bits)
template = template.replace("__FP_X_HEX__", val_hex)
template = template.replace("__FP_X_FIXED__", val_fix)
template = template.replace("__FP_X_FLOAT__", str(target_value_float))

target_value_float = 0.8768
val_hex,val_fix = get_string(target_value_float, word_bits, frac_bits)
template = template.replace("__LINE_M_F0_Z3_HEX__", val_hex)
template = template.replace("__LINE_M_F0_Z3_FIXED__", val_fix)
template = template.replace("__LINE_M_F0_Z3_FLOAT__", str(target_value_float))

target_value_float = 0.0
val_hex,val_fix = get_string(target_value_float, word_bits, frac_bits)
template = template.replace("__LINE_QP_F0_Z3_HEX__", val_hex)
template = template.replace("__LINE_QP_F0_Z3_FIXED__", val_fix)
template = template.replace("__LINE_QP_F0_Z3_FLOAT__", str(target_value_float))

target_value_float = 0.4903
val_hex,val_fix = get_string(target_value_float, word_bits, frac_bits)
template = template.replace("__LINE_M_Z3_Z4_HEX__", val_hex)
template = template.replace("__LINE_M_Z3_Z4_FIXED__", val_fix)
template = template.replace("__LINE_M_Z3_Z4_FLOAT__", str(target_value_float))

target_value_float = 0.2545
val_hex,val_fix = get_string(target_value_float, word_bits, frac_bits)
template = template.replace("__LINE_QP_Z3_Z4_HEX__", val_hex)
template = template.replace("__LINE_QP_Z3_Z4_FIXED__", val_fix)
template = template.replace("__LINE_QP_Z3_Z4_FLOAT__", str(target_value_float))

target_value_float = 0.2149
val_hex,val_fix = get_string(target_value_float, word_bits, frac_bits)
template = template.replace("__LINE_M_Z4_FP_HEX__", val_hex)
template = template.replace("__LINE_M_Z4_FP_FIXED__", val_fix)
template = template.replace("__LINE_M_Z4_FP_FLOAT__", str(target_value_float))

target_value_float = 0.5702
val_hex,val_fix = get_string(target_value_float, word_bits, frac_bits)
template = template.replace("__LINE_QP_Z4_FP_HEX__", val_hex)
template = template.replace("__LINE_QP_Z4_FP_FIXED__", val_fix)
template = template.replace("__LINE_QP_Z4_FP_FLOAT__", str(target_value_float))

target_value_float = 0.0
val_hex,val_fix = get_string(target_value_float, word_bits, frac_bits)
template = template.replace("__LINE_M_FP_INF_HEX__", val_hex)
template = template.replace("__LINE_M_FP_INF_FIXED__", val_fix)
template = template.replace("__LINE_M_FP_INF_FLOAT__", str(target_value_float))

target_value_float = 1.0
val_hex,val_fix = get_string(target_value_float, word_bits, frac_bits)
template = template.replace("__LINE_QP_FP_INF_HEX__", val_hex)
template = template.replace("__LINE_QP_FP_INF_FIXED__", val_fix)
template = template.replace("__LINE_QP_FP_INF_FLOAT__", str(target_value_float))

with open("PIECEWISE_APPROXIMATION_PARAMETERS.vh", "w") as file:
    file.write(template)
