#!/usr/bin/env python3

import jinja2 as jj
from jinja2 import Environment, FileSystemLoader
import numpy as np
import csv

# Create JINJA environment
jj_env = jj.Environment(loader=jj.FileSystemLoader('./'))

# Load weights as strings, from trained network output
hl_weights = []
with open('hidden_layer_weights_fp_hex.txt', 'r') as fid:
    csv_reader = csv.reader(fid, delimiter=',')
    for row in csv_reader:
        new_row = []
        for col in row:
            new_row.append(col)
        hl_weights.append(new_row)

hl_bias = []
with open('hidden_layer_bias_fp_hex.txt', 'r') as fid:
    csv_reader = csv.reader(fid, delimiter=',')
    for col in csv_reader:
        hl_bias.append(col)

ol_weights = []
with open('output_layer_weights_fp_hex.txt', 'r') as fid:
    csv_reader = csv.reader(fid, delimiter=',')
    for row in csv_reader:
        new_row = []
        for col in row:
            new_row.append(col)
        ol_weights.append(new_row)

ol_bias = []
with open('output_layer_bias_fp_hex.txt', 'r') as fid:
    csv_reader = csv.reader(fid, delimiter=',')
    for col in csv_reader:
        ol_bias.append(col)

# Build Jinja template context
context = {
    "template_file": "cortez_init.template",
    "num_inputs" : 9,
    "num_hl_nodes": 6,
    "num_outputs": 3,
    "hl_weights" : hl_weights,
    "hl_bias" : hl_bias,
    "ol_weights" : ol_weights,
    "ol_bias" : ol_bias
}

# Write out design
template = jj_env.get_template("cortez_init.template")
stream = template.stream(context)
stream.dump("cortez_init.i")
