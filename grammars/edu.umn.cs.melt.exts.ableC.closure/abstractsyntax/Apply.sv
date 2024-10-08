grammar edu:umn:cs:melt:exts:ableC:closure:abstractsyntax;

abstract production applyExpr implements Call
top::Expr ::= @fn::Expr args::Exprs
{
  top.pp = parens(ppConcat([fn.pp, parens(ppImplode(cat(comma(), space()), args.pps))]));
  attachNote extensionGenerated("ableC-closure");
  
  local localErrors :: [Message] =
    (if isClosureType(fn.typerep)
     then args.argumentErrors
     else [errFromOrigin(fn, s"Cannot apply non-closure (got ${show(80, fn.typerep)})")]) ++
    fn.errors ++ args.errors;
  
  local paramTypes::[Type] = closureParamTypes(fn.typerep);
  nondecorated local resultType::Type = closureResultType(fn.typerep);

  args.argumentPosition = 1;
  args.callExpr = fn;
  args.callVariadic = false;
  args.expectedTypes = paramTypes;

  local structName::String = closureStructName(paramTypes, resultType);
  nondecorated local closureStructExpr::Expr = ableC_Expr { (struct $name{structName})$Expr{fn.bindRefExpr} };
  forward fwrd = bindFnCall(fn, @args,
    ableC_Expr {
      $Expr{closureStructExpr}.fn($Expr{closureStructExpr}.env, $Exprs{foldExpr(args.bindRefExprs)})
    });

  forwards to if null(localErrors) then @fwrd else errorExpr(localErrors);
}
