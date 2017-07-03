
# Path from current directory to top level ableC repository
ABLEC_BASE?=../../ableC
# Path from current directory to top level extensions directory
EXTS_BASE?=../../extensions

MAKEOVERRIDES=ABLEC_BASE=$(abspath $(ABLEC_BASE)) EXTS_BASE=$(abspath $(EXTS_BASE))

all: examples analyses test

build:
	cd examples && $(MAKE) ableC.jar 

examples:
	cd examples && $(MAKE) -j

analyses: mda mwda

mda:
	cd modular_analyses && $(MAKE) mda

mwda:
	cd modular_analyses && $(MAKE) mwda

test:
	cd test && $(MAKE) -kj
clean:
	rm -f *~ 
	cd examples && $(MAKE) clean
	cd modular_analyses && $(MAKE) clean
	cd test && $(MAKE) clean

.PHONY: all build examples analyses mda mwda test clean
.NOTPARALLEL: # Avoid running multiple Silver builds in parallel
