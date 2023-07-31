grammar edu:umn:cs:melt:exts:ableC:closure:abstractsyntax;

abstract production callMemberClosure
top::Expr ::= lhs::Expr deref::Boolean rhs::Name a::Exprs
{
  forwards to
    case rhs.name, a of
      "free", consExpr(deallocate, nilExpr()) -> freeExpr(lhs, deallocate)
    | "free", _ -> errorExpr([errFromOrigin(rhs, "Closure free expected exactly 1 parameter")])
    | n, _ -> errorExpr([errFromOrigin(rhs, s"Closure does not have field ${n}")])
    end;
}

abstract production freeExpr
top::Expr ::= fn::Expr deallocate::Expr
{
  top.pp = pp"${fn.pp}.free(${deallocate.pp})";
  propagate env, controlStmtContext;
  
  local deallocateExpectedType::Type =
    functionType(
      builtinType(nilQualifier(), voidType()),
      protoFunctionType(
        [pointerType(nilQualifier(), builtinType(nilQualifier(), voidType()))],
        false),
      nilQualifier());
  local localErrors :: [Message] =
    if compatibleTypes(deallocateExpectedType, deallocate.typerep, true, false) then []
    else [errFromOrigin(deallocate, s"Deallocator must have type void(void*) (got ${showType(deallocate.typerep)})")] ++
    fn.errors ++ deallocate.errors;
  
  local paramTypes::[Type] = closureParamTypes(fn.typerep);
  local resultType::Type = closureResultType(fn.typerep);
  local structName::String = closureStructName(paramTypes, resultType);
  local fwrd::Expr =
    injectGlobalDeclsExpr(
      consDecl(
        closureStructDecl(
          argTypesToParameters(paramTypes),
          typeName(directTypeExpr(resultType), baseTypeExpr())),
        nilDecl()),
      ableC_Expr { $Expr{deallocate}(((struct $name{structName})$Expr{fn}).env) });
  
  forwards to mkErrorCheck(localErrors, fwrd);
}
