.PHONY: clean sim comp

# List of sources
SV_SOURCES = $(shell cat rtl_sources.list | grep -v "^#" | grep -v "^$$" | grep -E "\.[s]*v$$" | sed 's/^/\.\.\/\.\.\/rtl\//g' | tr '\n' ' ')

all: sim

sim: comp
	vsim -32 -batch -do "run -all; quit" ootbtb

comp: $(SV_SOURCES) ootbtb.sv
	vlog -32 -noincr -sv -sv17compat +incdir+../../rtl +incdir+../../grogu/grogu.gen/CORTEZ_REGPOOL/rtl +incdir+../../grogu -timescale=1ns/100ps $?

clean:
	rm -fR *.vcd work/ *.wlf transcript
