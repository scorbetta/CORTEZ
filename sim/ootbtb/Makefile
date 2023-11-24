.PHONY: clean sim comp

# List of sources
SOURCES = $(shell cat rtl_sources.list | sed 's/^/\.\.\/\.\.\/rtl\//g' | tr '\n' ' ')

# Launch GUI and control simulation interactively
INTERACTIVE ?= 0

VSIM_ARGS = -32
ifeq ($(INTERACTIVE),0)
VSIM_ARGS += -batch -do "run -all; quit"
endif

all: sim

sim: comp
	vsim $(VSIM_ARGS) ootbtb

comp: $(SOURCES) ootbtb.sv
	vlog -32 -noincr -sv -sv17compat +incdir+../../rtl +incdir+../../grogu/grogu.gen/CORTEZ_REGPOOL/rtl +incdir+../../grogu -timescale=1ns/100ps $?

clean:
	rm -fR *.vcd work/
