.PHONY: clean sim comp comp_vhd comp_sv

# List of (System)Verilog sources
SV_SOURCES = $(shell cat rtl_sources.list | grep -v "^#" | grep -v "^$$" | grep -E "\.[s]*v$$" | sed 's/^/\.\.\/\.\.\/rtl\//g' | tr '\n' ' ')

# List of VHDL sources
VHD_SOURCES = $(shell cat rtl_sources.list | grep -v "^#" | grep -v "^$$" | grep -E "\.vhd$$" | sed 's/^/\.\.\/\.\.\/rtl\//g' | tr '\n' ' ')

all: sim

sim: comp
	vsim -32 -batch -do "run -all; quit" ootbtb

comp: comp_vhd comp_sv
	
comp_sv: $(SV_SOURCES) ootbtb.sv
	vlog -32 -noincr -sv -sv17compat +incdir+../../rtl +incdir+../../grogu/grogu.gen/CORTEZ_REGPOOL/rtl +incdir+../../grogu -timescale=1ns/100ps $?

comp_vhd: $(VHD_SOURCES)
	vcom -32 -2008 $?

show:
	gtkwave -a ootbtb.gtkw -f ootbtb.vcd

clean:
	rm -fR *.vcd work/
