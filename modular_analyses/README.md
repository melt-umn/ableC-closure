# Modular analysis of language extensions

Silver and Copper provide two modular analyses that provide strong
composability guarantees to the programmer using a set of
independently-developed language extensions.

Specifically, any set of language extensions that pass the analyses
can be automatically composed to form a working compiler.

Each of these analysis are to be run by the extension developer on
their extension.  If the extension fails to pass the analysis, the
extension designer nned to modify the extension specification to make
it pass.

The first analysis is the *modular determinism analysis* and it
ensures that the composed specification of the lexical and
context-free syntax of ambiguities.

The second is the *modular well-definedness analysis*.  It ensures
that the composed attribute grammar is well-defined and thus the
semantic analysis and code generation phases will complete
successfully.

These directories provide scripts that allow the programmer to verify
that the extensions do in fact pass these modular analyses.

