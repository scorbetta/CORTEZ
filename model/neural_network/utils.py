import numpy as np
from fpbinary import FpBinary

# Utilities to deal with  FpBinary  objects, but still using support from  numpy  library
def fp_create_matrix(shape, int_bits, frac_bits, is_signed, init_values):
    # Allocate space for matrix
    fp_matrix = np.full(shape, FpBinary(int_bits=int_bits, frac_bits=frac_bits, signed=is_signed))

    # Fill in with values
    if len(shape) == 1:
        for rdx in range(init_values.shape[0]):
            fp_matrix[rdx] = FpBinary(int_bits=int_bits, frac_bits=frac_bits, signed=is_signed, value=init_values[rdx])
    else:
        for rdx in range(init_values.shape[0]):
            for cdx in range(init_values.shape[1]):
                fp_matrix[rdx,cdx] = FpBinary(int_bits=int_bits, frac_bits=frac_bits, signed=is_signed, value=init_values[rdx,cdx])

    return fp_matrix

# Cast all elements of an array of FpBinary to float
def cast_all_to_float(matrix):
    for rdx in range(matrix.shape[0]):
        for cdx in range(matrix.shape[1]):
            matrix[rdx][cdx] = float(matrix[rdx][cdx])

    return matrix
