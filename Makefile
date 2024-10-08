# To build and/or test the extension, run one of the following commands:
#
# `make`: build the artifact and run all tests
#
# `make build`: build the artifact
#
# `make examples`: compile and run the example uses of the extension
#
# `make analyses`: run the modular analyses that provide strong composability
#                  guarantees
#
# `make mda`: run the modular determinism analysis that ensures that the
#             composed specification of the lexical and context-free syntax is
#             free of ambiguities
#
# `make mwda`: run the modular well-definedness analysis that ensures that the
#              composed attribute grammar is well-defined and thus the semantic
#              analysis and code generation phases will complete successfully
#
# `make test`: run the extension's test suite
#
# note: the modular analyses and tests will not be rerun if no changes to the
#       source have been made. To force the tests to run, use make's -B option,
#       e.g. `make -B analyses`, `make -B mwda`, etc.
#

EXT_NAME=ableC-closure
EXT_GRAMMAR=edu:umn:cs:melt:exts:ableC:closure
EXT_DEPS=ableC-allocation
USE_CUSTOM_SILVER=true

# Path from current directory to top level ableC repository
ABLEC_BASE?=../../ableC

include $(ABLEC_BASE)/extension.mk
