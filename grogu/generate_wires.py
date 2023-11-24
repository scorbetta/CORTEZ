#!/usr/bin/env python3

import jinja2 as jj
from jinja2 import Environment, FileSystemLoader

# Create JINJA environment
jj_env = jj.Environment(loader=jj.FileSystemLoader('./'))

# Build Jinja template context
context = {
    "template_file": "CSR_BUNDLE_WIRES.template",
    "num_inputs" : 9,
    "num_hl_nodes": 6,
    "num_outputs": 3
}

# Write out design
template = jj_env.get_template("CSR_BUNDLE_WIRES.template")
stream = template.stream(context)
stream.dump("CSR_BUNDLE_WIRES.svh")
