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
    injectGlobalDeclsExpr(
      consDecl(
        closureStructDecl(
          argTypesToParameters(paramTypes),
          typeName(directTypeExpr(resultType), baseTypeExpr())),
        nilDecl()),
      ableC_Expr {
        ({struct $name{structName} _tmp_closure = (struct $name{structName})$Expr{fn};
          _tmp_closure.fn(_tmp_closure.env, $Exprs{args});})
      },
      location=builtin);

  forwards to mkErrorCheck(localErrors, fwrd);
}
