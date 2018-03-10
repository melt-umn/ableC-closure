grammar edu:umn:cs:melt:exts:ableC:closure:abstractsyntax;
  
aspect function ovrld:getCallOverloadProd
Maybe<(Expr ::= Expr Exprs Location)> ::= t::Type env::Decorated Env
{
  overloads <- [pair("edu:umn:cs:melt:exts:ableC:closure:closure", applyExpr(_, _, location=_))];
}

abstract production applyExpr
top::Expr ::= fn::Expr args::Exprs
{
  propagate substituted;
  top.pp = parens(ppConcat([fn.pp, parens(ppImplode(cat(comma(), space()), args.pps))]));
  
  forwards to applyTransExpr(fn, args, closureTypeExpr, location=top.location);
}

global applyExprFwrd::Expr = parseExpr(s"""
({proto_typedef __closure_type__;
  __closure_type__ _temp_closure = __fn__;
  _temp_closure._fn(_temp_closure._env, __args__);})""");

abstract production applyTransExpr
top::Expr ::= fn::Expr args::Exprs closureTypeExpr::(BaseTypeExpr ::= Qualifiers Parameters TypeName)
{
  propagate substituted;
  top.pp = parens(ppConcat([fn.pp, parens(ppImplode(cat(comma(), space()), args.pps))]));
  
  local localErrors :: [Message] =
    (if isClosureType(fn.typerep)
     then args.argumentErrors
     else [err(fn.location, s"Cannot apply non-closure (got ${showType(fn.typerep)})")]) ++
    fn.errors ++ args.errors;
  
  args.argumentPosition = 1;
  args.callExpr = fn;
  args.callVariadic = false;
  args.expectedTypes = closureParamTypes(fn.typerep, top.env);
  
  local fwrd::Expr =
    substExpr(
      [typedefSubstitution(
         "__closure_type__",
         closureTypeExpr(
           nilQualifier(),
           argTypesToParameters(args.expectedTypes),
           typeName(directTypeExpr(closureResultType(fn.typerep, top.env)), baseTypeExpr()))),
       declRefSubstitution("__fn__", fn),
       exprsSubstitution("__args__", args)],
      applyExprFwrd);

  forwards to mkErrorCheck(localErrors, fwrd);
}
