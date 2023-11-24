.PHONY: conv ir syn clean

# Prefix for change of hierarchy. Do *not* modify this line!
SOURCES = $(shell grep -E "\.[s]*v$$" rtl_sources.list | sed 's/^/\.\.\/rtl\//g' )

# Select top-level module to synthesize
TOPLEVEL ?= NETWORK_TOP_WRAPPER

# Shall we generate DOT graph?
PLOT_DOT ?= 0

# Library of cells
SKY130_LIB = $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# YOSYS scripts
YOSYS_IR_SCRIPT=read_verilog -sv -noassert -noassume -norestrict verilogs.v; proc; opt
YOSYS_SYN_SCRIPT=read_verilog -sv -noassert -noassume -norestrict verilogs.v; synth -top $(TOPLEVEL); dfflibmap -liberty $(SKY130_LIB) ; abc -liberty $(SKY130_LIB); sta; clean; write_verilog $(TOPLEVEL).synth.v
YOSYS_SHOW_SCRIPT=read_verilog $(TOPLEVEL).synth.v; show -prefix $(TOPLEVEL) -signed $(TOPLEVEL)

ifeq ($(PLOT_DOT),1)
YOSYS_IR_SCRIPT+=; show -colors 2 -width -signed -stretch -prefix $(TOPLEVEL)
endif

verilogs.v: $(SOURCES)
	sv2v -DDISABLE_TASKS --incdir=../grogu/grogu.gen/CORTEZ_REGPOOL/rtl --incdir=../grogu $^ > verilogs.v

conv: verilogs.v

ir: verilogs.v
	yosys -p "$(YOSYS_IR_SCRIPT)"

$(TOPLEVEL).synth.v: syn

syn: verilogs.v
	yosys -l $(TOPLEVEL).log -p "$(YOSYS_SYN_SCRIPT)"

show: $(TOPLEVEL).synth.v
	yosys -p "$(YOSYS_SHOW_SCRIPT)"

clean:
	rm -Rf *.dot *.dot.pid verilogs.v *.synth.v *.log conv_rtl/
