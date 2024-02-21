# Folders containing a testbench
TB_SUBDIRS := $(shell find . -name "*_tb" -type d)

all: $(TB_SUBDIRS)

$(TB_SUBDIRS):
	$(MAKE) -C $@

clean:
	find . -name "work" -type d -exec rm -fR {} \;
	find . -name "dump.*" -exec rm -f {} \;

.PHONY: $(TB_SUBDIRS) clean
