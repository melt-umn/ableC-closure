grammar edu:umn:cs:melt:exts:ableC:closure:abstractsyntax;

abstract production applyExpr
top::Expr ::= fn::Expr args::Exprs
{
  propagate substituted;
  top.pp = parens(ppConcat([fn.pp, parens(ppImplode(cat(comma(), space()), args.pps))]));
  
  local localErrors :: [Message] =
    (if isClosureType(fn.typerep)
     then args.argumentErrors
     else [err(fn.location, s"Cannot apply non-closure (got ${showType(fn.typerep)})")]) ++
    fn.errors ++ args.errors;
  
  local paramTypes::[Type] = closureParamTypes(fn.typerep);
  local resultType::Type = closureResultType(fn.typerep);
  
  args.argumentPosition = 1;
  args.callExpr = fn;
  args.callVariadic = false;
  args.expectedTypes = paramTypes;
  
  local structName::String = closureStructName(paramTypes, resultType);
  local fwrd::Expr =
    ableC_Expr {
      ({$BaseTypeExpr{
          closureTypeExpr(
            nilQualifier(),
            argTypesToParameters(args.expectedTypes),
            typeName(directTypeExpr(resultType), baseTypeExpr()))} _tmp_closure = $Expr{fn};
        ((struct $name{structName})_tmp_closure)._fn(((struct $name{structName})_tmp_closure)._env, $Exprs{args});})
    };

  forwards to mkErrorCheck(localErrors, fwrd);
}
