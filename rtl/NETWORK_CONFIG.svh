`ifndef __NETWORK_CONFIG_SVH__
`define __NETWORK_CONFIG_SVH__

// Number of input nodes. This is determined by the problem we want to solve. For instance, for the
// 5x5 matrix vowel recognition, this is set to 25
`define NUM_INPUTS 9

// Number of nodes in the hidden layer. This is in general set to a number lower than the input
// layer (i.e., lower than  `NUM_INPUTS  ) and higher than the output layer (i.e., greater than
//  `NUM_OL_NODES  )
`define NUM_HL_NODES 6

// Number of nodes in the output layer. This is determined by the output representation. For the
// vowel recognition problem, since 5 vowels are to be recognizied, this value is set to 5. Vowels
// are one-hot encoded. Being the last layer, this is also the number of outputs
`define NUM_OL_NODES 3

// Fixed point configuration: word width, comprising both the integral part and the fractional part
`define FIXED_POINT_WORD_WIDTH  8
// Fixed point configuration: fractional part. The higher the value, the higher the resolution
`define FIXED_POINT_FRAC_BITS   5

`endif /* __NETWORK_CONFIG_SVH__ */
