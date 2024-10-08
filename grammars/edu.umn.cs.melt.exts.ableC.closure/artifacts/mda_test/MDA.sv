grammar edu:umn:cs:melt:exts:ableC:closure:artifacts:mda_test;

{- This Silver specification does not generate a useful working 
   compiler, it only serves as a grammar for running the modular
   determinism analysis.
 -}

import edu:umn:cs:melt:ableC:host;

copper_mda testLambdaExpr(ablecParser) {
  edu:umn:cs:melt:exts:ableC:closure:concretesyntax:lambdaExpr;
}

copper_mda testTypeExpr(ablecParser) {
  edu:umn:cs:melt:exts:ableC:closure:concretesyntax:typeExpr;
}