# Folders containing a testbench
TB_SUBDIRS := $(shell find . -name *_tb -type d)

all clean: $(TB_SUBDIRS)

$(TB_SUBDIRS):
	$(MAKE) -C $@ $(MAKECMDGOALS)

.PHONY: $(TB_SUBDIRS) clean
