grammar edu:umn:cs:melt:exts:ableC:closure:abstractsyntax;

abstract production applyExpr
top::Expr ::= fn::Expr args::Exprs
{
  top.pp = parens(ppConcat([fn.pp, parens(ppImplode(cat(comma(), space()), args.pps))]));
  attachNote extensionGenerated("ableC-closure");
  propagate controlStmtContext;
  
  local localErrors :: [Message] =
    (if isClosureType(fn.typerep)
     then args.argumentErrors
     else [errFromOrigin(fn, s"Cannot apply non-closure (got ${showType(fn.typerep)})")]) ++
    fn.errors ++ args.errors;
  
  local paramTypes::[Type] = closureParamTypes(fn.typerep);
  local resultType::Type = closureResultType(fn.typerep);
  
  fn.env = top.env;
  args.env = addEnv(fn.defs, fn.env);
  args.argumentPosition = 1;
  args.callExpr = fn;
  args.callVariadic = false;
  args.expectedTypes = paramTypes;
  
  local structName::String = closureStructName(paramTypes, resultType);
  local tmpName::String = "_tmp_closure_" ++ toString(genInt());
  -- Workaround to ensure fn and args get the proper environment if they declare the struct
  local initialDecls::Decl =
    decls(
      ableC_Decls {
        $Decl{
          injectGlobalDeclsDecl(
            consDecl(
              closureStructDecl(
                argTypesToParameters(paramTypes),
                typeName(directTypeExpr(resultType), baseTypeExpr())),
            nilDecl()))}
        struct $name{structName} $name{tmpName} =
          (struct $name{structName})$Expr{decExpr(fn)};
      });
  initialDecls.env = addEnv(args.defs, args.env);
  initialDecls.isTopLevel = false;
  initialDecls.controlStmtContext = initialControlStmtContext;
  local fwrd::Expr =
    ableC_Expr {
      ({$Decl{decDecl(initialDecls)}
        $name{tmpName}.fn($name{tmpName}.env, $Exprs{decExprs(args)});})
    };

  forwards to mkErrorCheck(localErrors, fwrd);
}
