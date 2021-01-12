grammar edu:umn:cs:melt:exts:ableC:closure:abstractsyntax;

import silver:util:treemap as tm;

-- Construct an environment in which all non-global values have been made const
function capturedEnv
Decorated Env ::= env::Decorated Env
{
  return
    addEnv(
      map(
        \ n::String -> valueDef(n, captureValueItem(head(lookupValue(n, env)))),
        flattenScope(init(env.values))),
      openScopeEnv(globalEnv(env)));
}

-- Generate the list of all names in scopes
function flattenScope
[String] ::= s::Scopes<a>
{
  return nub(map(fst, flatMap(tm:toList, s)));
}

-- Wrap a ValueItem, making it const
abstract production captureValueItem
top::ValueItem ::= captured::ValueItem
{
  top.pp = pp"captured ${captured.pp}";
  top.typerep = addQualifiers([constQualifier(location=builtin)], captured.typerep.defaultFunctionArrayLvalueConversion);
  top.sourceLocation = captured.sourceLocation;
  top.isItemValue = captured.isItemValue;
}
