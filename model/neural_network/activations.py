import numpy as np
import sys

all_data = []

# activation function and its derivative
def tanh(x):
    for vdx in range(len(x)):
        all_data.append(x[0][vdx])
    return np.tanh(x);

def tanh_prime(x):
    return 1-np.tanh(x)**2;

def afun_test_primitive(x):
    # (-inf,-2]
    if x <= -2:
        return -1.0
    # [-2,arctanh(-sqrt(2/3))]
    elif x >= -2.0 and x <= np.arctanh(-np.sqrt(2.0/3)):
        return 0.2149 * x - 0.5702
    # [arctanh(-sqrt(2/3)),arctanh(-sqrt(1/3))]
    elif x >= np.arctanh(-np.sqrt(2.0/3.0)) and x <= np.arctanh(-np.sqrt(1.0/3.0)):
        return 0.4903 * x - 0.2545
    # [arctanh(sqrt(-1/3)),0]
    elif x >= np.arctanh(-np.sqrt(1.0/3.0)) and x <= 0:
        return 0.8768 * x
    # [0,arctanh(sqrt(1/3))]
    elif x >= 0 and x <= np.arctanh(np.sqrt(1.0/3.0)):
        return 0.8768 * x
    # [arctanh(sqrt(1/3)),arctanh(sqrt(2/3))]
    elif x >= np.arctanh(np.sqrt(1.0/3.0)) and x <= np.arctanh(np.sqrt(2.0/3.0)):
        return 0.4903 * x + 0.2545
    # [arctanh(sqrt(2/3)),2]
    elif x >= np.arctanh(np.sqrt(2.0/3.0)) and x <= 2.0:
        return 0.2149 * x + 0.5702
    # [2,+inf)
    elif x >= 2:
        return 1.0

def afun_test(x):
    foovec = np.vectorize(afun_test_primitive)
    return foovec(x)

def afun_test_prime_primitive(x):
    # (-inf,-2]
    if x <= -2:
        return 1e-4
    # [-2,arctanh(-sqrt(2/3))]
    elif x >= -2.0 and x <= np.arctanh(-np.sqrt(2.0/3)):
        return 0.2149
    # [arctanh(-sqrt(2/3)),arctanh(-sqrt(1/3))]
    elif x >= np.arctanh(-np.sqrt(2.0/3.0)) and x <= np.arctanh(-np.sqrt(1.0/3.0)):
        return 0.4903
    # [arctanh(sqrt(-1/3)),0]
    elif x >= np.arctanh(-np.sqrt(1.0/3.0)) and x <= 0:
        return 0.8768
    # [0,arctanh(sqrt(1/3))]
    elif x >= 0 and x <= np.arctanh(np.sqrt(1.0/3.0)):
        return 0.8768
    # [arctanh(sqrt(1/3)),arctanh(sqrt(2/3))]
    elif x >= np.arctanh(np.sqrt(1.0/3.0)) and x <= np.arctanh(np.sqrt(2.0/3.0)):
        return 0.4903
    # [arctanh(sqrt(2/3)),2]
    elif x >= np.arctanh(np.sqrt(2.0/3.0)) and x <= 2.0:
        return 0.2149
    # [2,+inf)
    elif x >= 2:
        return 1e-4

def afun_test_prime(x):
    foovec = np.vectorize(afun_test_prime_primitive)
    return foovec(x)
