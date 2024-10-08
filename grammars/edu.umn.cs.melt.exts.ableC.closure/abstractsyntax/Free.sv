grammar edu:umn:cs:melt:exts:ableC:closure:abstractsyntax;

abstract production freeClosure implements Destructor
top::Expr ::= e::Expr
{
  top.pp = pp"delete ${e.pp}";
  attachNote extensionGenerated("ableC-closure");

  local localErrors::[Message] = deallocErrors(top.env);

  local structName::String = closureStructName(closureParamTypes(e.typerep), closureResultType(e.typerep));
  nondecorated local result::Expr = ableC_Expr {
    deallocate((void*)((struct $name{structName})$Expr{e.bindRefExpr}).env)
  };

  forwards to bindDestructor(@e, mkErrorCheck(localErrors, result));
}
