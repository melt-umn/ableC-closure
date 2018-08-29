grammar edu:umn:cs:melt:exts:ableC:closure:abstractsyntax;

abstract production callMemberClosure
top::Expr ::= lhs::Expr deref::Boolean rhs::Name a::Exprs
{
  propagate substituted;
  
  forwards to
    case rhs.name, a of
      "free", consExpr(deallocate, nilExpr()) -> freeExpr(lhs, deallocate, location=top.location)
    | "free", _ -> errorExpr([err(rhs.location, "Closure free expected exactly 1 parameter")], location=top.location)
    | n, _ -> errorExpr([err(rhs.location, s"Closure does not have field ${n}")], location=top.location)
    end;
}

abstract production freeExpr
top::Expr ::= fn::Expr deallocate::Expr
{
  propagate substituted;
  top.pp = pp"${fn.pp}.free(${deallocate.pp})";
  
  local deallocateExpectedType::Type =
    functionType(
      builtinType(nilQualifier(), voidType()),
      protoFunctionType(
        [pointerType(nilQualifier(), builtinType(nilQualifier(), voidType()))],
        false),
      nilQualifier());
  local localErrors :: [Message] =
    if compatibleTypes(deallocateExpectedType, deallocate.typerep, true, false) then []
    else [err(deallocate.location, s"Deallocator must have type void(void*) (got ${showType(deallocate.typerep)})")] ++
    fn.errors ++ deallocate.errors;
  
  local paramTypes::[Type] = closureParamTypes(fn.typerep);
  local resultType::Type = closureResultType(fn.typerep);
  local structName::String = closureStructName(paramTypes, resultType);
  local fwrd::Expr = ableC_Expr { $Expr{deallocate}(((struct $name{structName})$Expr{fn})._env) };

  forwards to mkErrorCheck(localErrors, fwrd);
}
