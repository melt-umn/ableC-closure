grammar edu:umn:cs:melt:exts:ableC:closure:artifacts:compiler;

{- This Silver specification does litte more than list the desired
   extensions, albeit in a somewhat stylized way.

   Files like this can easily be generated automatically from a simple
   list of the desired extensions.
 -}

import edu:umn:cs:melt:ableC:concretesyntax as cst;
import edu:umn:cs:melt:ableC:drivers:compile;


parser extendedParser :: cst:Root {
  edu:umn:cs:melt:ableC:concretesyntax;
  edu:umn:cs:melt:exts:ableC:closure;
  edu:umn:cs:melt:exts:ableC:allocation;
} 

fun main IO<Integer> ::= args::[String] = driver(args, extendedParser);
