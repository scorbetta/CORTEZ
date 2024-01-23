from fxpmath import *

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

