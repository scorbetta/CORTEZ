# Introduction

CORTEZ1 is the first run of the CORTEZ chip.

The CORTEZ chip contains a back-propagation neural network that recognizes vowels in a 5x5 noisy
input grid. The neural network architecture consists of one hidden layer and one output layer. The
training is based on the back-propagation algorithm using the hyperbolic tangent function as
activation layer. The digital design is based on fixed-point rather than floating-point to simplify
the design and reduce costs (area).

# Contents

- `model/neural_network/`, the Python model of the neural network;
- `model/pievewise_approximation/`, the Python and Matlab approximation of the `tanh()` function, to
  be used in the digital design. It also contains script to generate synthesizable RTL code.
