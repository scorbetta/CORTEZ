# Introduction
The CORTEZ repository contains design files and tools for the CORTEZ chip. This is a digital
implementation of a simple Neural Network for characters recognition. The CORTEZ chip is meant to be
used as a testbed for MPW-driven ASICs.

## Design versions
Different design versions solve different problems, called boulders. The following table reports the
available versions, the target shuttle and the implementation status. Design version matches the tag
within this repository.

| DESIGN VERSION | BOULDER | SHUTTLE | STATUS |
|-|-|-|-|
| `v1.0` | `o`, `u` and `i` recognition on a 3x3 grid | [GFMPW-1](https://repositories.efabless.com/scorbetta/CORTEZ1_GFMPW1) | Submitted |
| `v1.1` | `c` and `f` recognition on a 3x3 grid | None | Deprecated |
| `v1.2` | Vowels recognition on a 5x5 grid | TT06 | Work in progress |

## Design overview
The CORTEZ design implements a back-propagation neural network that recognizes vowels in a noisy
input. The general architecture consists of one hidden layer and one output layer. The training is
based on the back-propagation algorithm using a piece-wise approximation of the hyperbolic tangent
function as activation layer.  The digital design is based on fixed-point rather than floating-point
to simplify the design and reduce costs (area).

## Contents
- `grogu/`, register map design files based on [`grogu`](https://github.com/scorbetta/grogu);
- `model/neural_network/`, the Python model of the neural network;
- `model/piecewise_approximation/`, the Python and Matlab files of the `tanh()` approximation;
- `rtl/`, the RTL design;
- `sim/`, out-of-the-box-testbench for bring-up simulation;
- `ver/`, the verification environment;
- `generate_design.sh`, the main script to run the design customization flow.

## How-to: design customization
The `generate_design.sh` script can be used to run the network customization flow from model to RTL.
The script will run through the following steps:

- Model training;
- Model testing;
- Piecewise approximation generation;
- Top-level RTL design generation;
- Simple simulation.

Before running the flow, open `generate_design.sh` and modify the following constants according to
your desired network architecture and input problem:

| CONSTANT | BRIEF |
|-|-|
| `HL_NEURONS` | Number of neurons in the hidden layer |
| `OL_NEURONS` | Number of neurons in the output layer |
| `FP_WIDTH` | Fixed-point width |
| `FP_FRAC` | Fixed-point fractional portion |
| `GRID_SIZE` | Input problem size (one dimension) |
| `MAX_NOISY_PIXELS` | Number of noisy pixels to use for training |
| `TRAINING_LEN` | Number of training vectors |
| `TEST_LEN` | Number of test vectors |
| `EPOCHS` | Number of training epochs |
| `ALPHA` | Learning rate |

At this point, run the flow:

```bash
./generate_design.sh
```

Logs are created for each step, look for any `*.log` file in the subfolders.
