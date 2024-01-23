import random
from fxpmath import *
import numpy as np


#---- FXP LIBRARY RELATED -------------------------------------------------------------------------

# Return a well-known FXP configuration object to be used to create Fxp() instances
def fxp_get_config():
    fxp_config = Config()
    fxp_config.overflow = 'wrap'#'saturate'
    fxp_config.rounding = 'trunc'
    fxp_config.shifting = 'expand'
    fxp_config.op_method = 'raw'
    fxp_config.op_input_size = 'same'
    fxp_config.op_sizing = 'same'
    fxp_config.const_op_sizing = 'same'
    return fxp_config

# Return a random fixed-point number
def fxp_generate_random(width, frac_bits):
    word_str = ''.join(random.choice(['0','1']) for bit in range(width))
    value = Fxp(val=f'0b{word_str}', signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())
    return value

# Return the fixed-point range
def fxp_get_range(width, frac_bits):
    # Minimum value
    frac_part_str = '0' * frac_bits
    int_part_str = '1' + '0' * (width - frac_bits - 1)
    fp_str = int_part_str + frac_part_str
    fxp_min = Fxp(val=f'0b{fp_str}', signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())

    # Maximum value
    frac_part_str = '1' * frac_bits
    int_part_str = '0' + '1' * (width - frac_bits - 1)
    fp_str = int_part_str + frac_part_str
    fxp_max = Fxp(val=f'0b{fp_str}', signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())

    return fxp_min,fxp_max

# Compute the absolute distance between a reference quantity and a measured quantity
def fxp_abs_err(ref_value, test_value):
    #@RELreturn abs( ((ref_value * 1.0001) - test_value) / (ref_value * 1.0001) )
    return abs(ref_value - test_value)

# Get the resolution of a given fixed-point configuration. Resolution depends on number of bits in
# the fractional part. Resolution is the number given by a binary string that has only the LSB set
def fxp_get_lsb(width, frac_bits):
    resolution_bin_str = f"0b{'0' * (width-frac_bits)}{'0' * (frac_bits-1)}1"
    lsb = Fxp(val=resolution_bin_str, signed=True, n_word=width, n_frac=frac_bits, config=fxp_get_config())
    return lsb

# Load data from a CSV file containing float numbers
def fxp_load_csv(ifile, width, frac_bits, delimiter=','):
    load_in = np.loadtxt(ifile, delimiter=delimiter)
    fxp_matrix = Fxp(load_in, n_word=width, n_frac=frac_bits, signed=True, config=fxp_get_config())
    return fxp_matrix


#---- GENERIC -------------------------------------------------------------------------------------

def dbug_print(print_flag, message):
    if print_flag == 1:
        print(f'{message}')

# Convert binary position to string position:
#   0 (lsb) becomes strlen-1
#   ...
#   strlen-1 (msb) becomes 0
def stringify(bin_pos, strlen):
    return (strlen - 1 - bin_pos)
