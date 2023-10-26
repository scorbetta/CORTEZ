#!/usr/bin/python3

# The back propagation neural network with an hidden layer and an output layer. Compared to the
# simpler Madaline networks, the activation function is differentiable, thus an analytic version of
# the back propagation algorithm can be used instead of the Madaline rules I through III

# Standard imports
import numpy as np
import random
import sys
import argparse
import json
import matplotlib.pyplot as plt
from numpy import sqrt
import string
import configparser

# Neural network imports
from network import Network
from fc_layer import FCLayer
from activation_layer import ActivationLayer
from activations import tanh, tanh_prime, afun_test, afun_test_prime, all_data
from losses import mse, mse_prime
from utils import fp_create_matrix, cast_all_to_float

# Plot character
def plot_char(matrix, title, fname):
    plt.matshow(matrix, cmap='Greys')
    plt.title(title)
    plt.savefig(fname)
    plt.close()

# Create noisy vectors from noise-less data, with specified max number of inverted pixels
def create_noisy_data(training_len, grid_size, output_size, chars_in, chars_out, max_noisy_pixels, save_fig):
    # Input set
    x = np.zeros((training_len, 1, grid_size))
    # Target vector
    y = np.zeros((training_len, 1, output_size))

    for idx in range(training_len):
        # Pick either
        char_select = random.choice(list(chars_in.keys()))
        noisy_vector = chars_in[char_select].copy()
        #@DBUGprint(f'dbug: char_select={char_select}')
        #@DBUGprint(f'dbug:    noise_less_vector={noisy_vector}')

        # Pick number of noisy pixels
        num_noisy_pixels = random.choice(range(max_noisy_pixels+1))
        #@DBUGprint(f'dbug:    num_noisy_pixels={num_noisy_pixels}')
    
        # Add up to a number of noisy pixels to noise-less input
        noisy_pixels = []
        positions = list(range(len(noisy_vector)))
        for ndx in range(num_noisy_pixels):
            noisy_pixel = random.choice(positions)
            positions.remove(noisy_pixel)
            noisy_vector[noisy_pixel] = -noisy_vector[noisy_pixel]
            noisy_pixels.append(noisy_pixel)
        #@DBUGprint(f'dbug:    noisy_pixels={noisy_pixels}')
        #@DBUGprint(f'dbug:    noisy_vector={noisy_vector}')

        # Sanity check
        assert(len(noisy_pixels) >= 0)
        assert(len(noisy_pixels) <= max_noisy_pixels)

        # Save
        x[idx,0,:] = noisy_vector
        y[idx,0,:] = chars_out[char_select]

        # Save picture if required
        if save_fig == 1:
            grid_side = int(sqrt(grid_size))
            vdx = x[idx,0,:].reshape(grid_side, grid_side)
            sha = ''.join(random.choices(string.ascii_uppercase + string.digits, k=8))
            plot_char(vdx, f'{grid_side}x{grid_side} w/ {num_noisy_pixels} noisy pixels: {char_select}', f'train_{sha}.png') 

    return x,y

# Dump matrices to file
def dump_to_file(matrix, file):
    original_stdout = sys.stdout

    with open(file, 'w') as fid:
        sys.stdout = fid

        for row in range(matrix.shape[0]):
            print(*matrix[row], sep=',')
    sys.stdout = original_stdout

def sim_network(network, x, y):
    out = network.predict(x)

    # Compute mean-square error
    mse_test = 0.0
    for edx in range(len(out)):
        mse_test = mse_test + (out[edx] - y[edx]) ** 2
    mse_test = mse_test / len(out)

    # Compute prediction precision
    out_sign = np.sign(out)
    num_failures = 0
    for edx in range(len(out_sign)):
        if not (out_sign[edx] == y[edx]).all():
            num_failures += 1

    # Return values
    mse_value = np.mean(mse_test)
    precision = (1.0 - (num_failures / len(out_sign))) * 100
    return mse_value,num_failures,precision

# Test network comparing floating-point weights against fixed-point approximation
def test_fixed_point_approximation(network, x, fixed_w_hl, fixed_b_hl, fixed_w_ol, fixed_b_ol):
    # Compute output of nominal network
    float_out = network.predict(x)

    # Adjust weights and compute output of modified network
    network_copy = network
    network_copy.layers[0].weights = fixed_w_hl
    network_copy.layers[0].bias = fixed_b_hl
    network_copy.layers[2].weights = fixed_w_ol
    network_copy.layers[2].bias = fixed_b_ol
    fixed_out = network_copy.predict(x)

    # Compute absolute error (MSE)
    mse_value = 0.0
    for idx in range(len(float_out)):
        for jdx in range(len(float_out[idx][0])):
            mse_value = mse_value + (float_out[idx][0][jdx] - fixed_out[idx][0][jdx]) ** 2
    mse_value = mse_value / len(float_out)

    # Compute relative error stats
    relative_err = []
    for idx in range(len(float_out)):
        for jdx in range(len(float_out[idx][0])):
            relative_err.append(float(abs(fixed_out[idx][0][jdx] - float_out[idx][0][jdx]) / abs(float_out[idx][0][jdx])))

    return mse_value,relative_err

def prepare_boulder(config):
    # Load problem specs from from file
    with open(config['boulder']) as fid:
        boulder_data = json.load(fid)

    chars_in = boulder_data["training"]
    chars_out = boulder_data["target"]

    # Sanity checks: for each key (i.e., for each character we want to represent) the number of
    # inputs must be the same
    lens = []
    for key in list(chars_in.keys()):
        lens.append(len(chars_in[key]))
    all_equals = all( item == lens[0] for item in lens )
    assert all_equals

    # Grid size is given by the boulder specs
    grid_size = lens[0]

    lens = []
    for key in list(chars_out.keys()):
        lens.append(len(chars_out[key]))
    all_equals = all( item == lens[0] for item in lens )
    assert all_equals

    # Print vanilla training characters
    for key in list(chars_in.keys()):
        vanilla_vector = chars_in[key]
        grid_side = int(sqrt(grid_size))
        vdx = np.reshape(vanilla_vector, (grid_side, grid_side))
        plot_char(vdx, f'Noise-less character: {key}', f'vanilla_{key}.png')

    return grid_size,chars_in,chars_out

def create_network(config, grid_size, chars_in, chars_out):
    net = Network()
    net.add(FCLayer(grid_size, int(config['hl_neurons'])))
    #net.add(ActivationLayer(tanh, tanh_prime))
    net.add(ActivationLayer(afun_test, afun_test_prime))
    net.add(FCLayer(int(config['hl_neurons']), int(config['ol_neurons'])))
    #net.add(ActivationLayer(tanh, tanh_prime))
    net.add(ActivationLayer(afun_test, afun_test_prime))

    return net

def train_network(config, net, grid_size, chars_in, chars_out):
    # Create noisy arrays from noise-less for training data
    x_train,y_train = create_noisy_data(int(config['training_len']), grid_size, int(config['ol_neurons']), chars_in, chars_out, int(config['max_noisy_pixels']), int(config['plot_png']))

    # Train network
    net.use(mse, mse_prime)
    net.fit(x_train, y_train, epochs=int(config['epochs']), learning_rate=float(config['alpha']))
    
    # Cast float to fixed and dump them as well
    w = net.layers[0].weights
    wcast_hl = fp_create_matrix(w.shape, int(config['fp_width'])-int(config['fp_frac']), int(config['fp_frac']), True, w)
    b = net.layers[0].bias
    bcast_hl = fp_create_matrix(b.shape, int(config['fp_width'])-int(config['fp_frac']), int(config['fp_frac']), True, b)

    w = net.layers[2].weights
    wcast_ol = fp_create_matrix(w.shape, int(config['fp_width'])-int(config['fp_frac']), int(config['fp_frac']), True, w)
    b = net.layers[2].bias
    bcast_ol = fp_create_matrix(b.shape, int(config['fp_width'])-int(config['fp_frac']), int(config['fp_frac']), True, b)
 
    # Dump weights and biases from all layers
    dump_to_file(net.layers[0].weights, "hidden_layer_weights.txt")
    dump_to_file(net.layers[0].bias, "hidden_layer_bias.txt")
    dump_to_file(net.layers[2].weights, "output_layer_weights.txt")
    dump_to_file(net.layers[2].bias, "output_layer_bias.txt")
    dump_to_file(wcast_hl, "hidden_layer_weights_fp.txt")
    dump_to_file(bcast_hl, "hidden_layer_bias_fp.txt")
    dump_to_file(wcast_ol, "output_layer_weights_fp.txt")
    dump_to_file(bcast_ol, "output_layer_bias_fp.txt")

    # Cast to float, otherwise testing the network will fail (numpy matrices require float)
    wcast_hl = cast_all_to_float(wcast_hl)
    bcast_hl = cast_all_to_float(bcast_hl)
    wcast_ol = cast_all_to_float(wcast_ol)
    bcast_ol = cast_all_to_float(bcast_ol)

    # Save for later use
    np.savez("weights.npz",
        float_w_hl=net.layers[0].weights, float_b_hl=net.layers[0].bias,
        float_w_ol=net.layers[2].weights, float_b_ol=net.layers[2].bias,
        fixed_w_hl=wcast_hl, fixed_b_hl=bcast_hl,
        fixed_w_ol=wcast_ol, fixed_b_ol=bcast_ol
    )

    # Test network with training data
    mse_value,num_failures,precision = sim_network(net, x_train, y_train)
    print(f'info: Overall MSE w/ train data: {mse_value}')
    print(f'info:    Num failures: {num_failures}')
    print(f'info:    Precision: {precision}%')

def network_overwrite(net, w_hl, b_hl, w_ol, b_ol):
    for rdx in range(net.layers[0].weights.shape[0]):
        for cdx in range(net.layers[0].weights.shape[1]):
            net.layers[0].weights[rdx][cdx] = w_hl[rdx][cdx]

    for rdx in range(net.layers[0].bias.shape[0]):
        for cdx in range(net.layers[0].bias.shape[1]):
            net.layers[0].bias[rdx][cdx] = b_hl[rdx][cdx]

    for rdx in range(net.layers[2].weights.shape[0]):
        for cdx in range(net.layers[2].weights.shape[1]):
            net.layers[2].weights[rdx][cdx] = w_ol[rdx][cdx]

    for rdx in range(net.layers[2].bias.shape[0]):
        for cdx in range(net.layers[2].bias.shape[1]):
            net.layers[2].bias[rdx][cdx] = b_ol[rdx][cdx]

    return net

def test_network(config, net, weights_file):
    # Load weights from file
    weights_bundle = np.load("weights.npz", allow_pickle=True)

    # Overwrite weights in network
    net = network_overwrite(net, weights_bundle['fixed_w_hl'], weights_bundle['fixed_b_hl'], weights_bundle['fixed_w_ol'], weights_bundle['fixed_b_ol'])

    # Compute absolute error (MSE)
    print(f'info: Network tests')
 
    # Create test data and test network with test data
    x_test,y_test = create_noisy_data(int(config['test_len']), grid_size, int(config['ol_neurons']), chars_in, chars_out, int(config['max_noisy_pixels']), 0)
    mse_value,num_failures,precision = sim_network(net, x_test, y_test)
    print(f'info: Network w/ floating-point weights')
    print(f'info:    Overall MSE: {mse_value}')
    print(f'info:    Number of failures: {num_failures}')
    print(f'info:    Precision: {precision}%')

    # Test the network with the fixed-point weights. While running the network, a simple model is
    # used that compares the values using fixed-point weights against the values using
    # floating-point weights
    mse_value,rel_err = test_fixed_point_approximation(net, x_test, weights_bundle['fixed_w_hl'], weights_bundle['fixed_b_hl'], weights_bundle['fixed_w_ol'], weights_bundle['fixed_b_ol'])
    print(f'info: Network w/ fiexd-point weights')
    print(f'info:    Overall MSE: {mse_value}')
    print(f'info:    Average relative error: {np.mean(rel_err)}')

    # For the next plots, remove values that are exactly 0.0. The plots focus on those cases where
    # there is an error, still it is expected to be low
    rel_err = list(filter(lambda num: num != 0, rel_err))

    # Plot error
    fig = plt.figure()
    ax1 = fig.add_subplot(211)
    ax1.semilogy(rel_err)
    ax1.set_xlabel('Sample')
    ax1.set_ylabel('Relative error (log)')
    ax1.set_title(f"Global MSE={mse_value}")
    ax1.grid()
    # Plot error CDF
    rel_err_sorted = np.sort(rel_err)
    p = 1. * np.arange(len(rel_err_sorted)) / (len(rel_err_sorted) - 1)
    ax2 = fig.add_subplot(223)
    ax2.semilogx(rel_err_sorted, p)
    ax2.set_xlabel('Relative error (log)')
    ax2.set_ylabel('CDF')
    ax2.grid()
    # Plot error histogram
    ax3 = fig.add_subplot(224)
    ax3.hist(rel_err_sorted,bins=100)
    ax3.set_xlabel('Relative error (log)')
    ax3.set_ylabel('Occurrences')
    ax3.set_xscale('log')
    ax3.grid()
    plt.savefig('error.png')
    plt.close()

if __name__ == "__main__":
    # Command line parser
    cmd_parser = argparse.ArgumentParser(description="Neural Network design and test utility")
    cmd_parser.add_argument("--train-network", required=False, action='store_true', help="Create a new network and train it")
    cmd_parser.add_argument("--test-network", required=False, action='store_true', help="Test network using pre-computed weights stored in file")

    # Parse arguments
    args = cmd_parser.parse_args()
    if not(args.train_network or args.test_network):
        cmd_parser.print_help()
        sys.exit()

    # Load configuration
    config = configparser.ConfigParser()
    config.read("config.ini")
    config = dict(config.items('default'))

    # Boulder problem setup
    grid_size,chars_in,chars_out = prepare_boulder(config)

    # Create network
    net = create_network(config, grid_size, chars_in, chars_out)

    # Train network
    if args.train_network:
        train_network(config, net, grid_size, chars_in, chars_out)

    # Test network
    if args.test_network:
        test_network(config, net, "weights.npz")
