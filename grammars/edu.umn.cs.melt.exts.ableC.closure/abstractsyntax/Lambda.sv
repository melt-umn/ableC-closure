grammar edu:umn:cs:melt:exts:ableC:closure:abstractsyntax;

imports silver:langutil;
imports silver:langutil:pp;

imports edu:umn:cs:melt:ableC:abstractsyntax:host;
imports edu:umn:cs:melt:ableC:abstractsyntax:construction;
imports edu:umn:cs:melt:ableC:abstractsyntax:construction:parsing;
imports edu:umn:cs:melt:ableC:abstractsyntax:substitution;
imports edu:umn:cs:melt:ableC:abstractsyntax:env;
imports edu:umn:cs:melt:ableC:abstractsyntax:overloadable as ovrld;
--imports edu:umn:cs:melt:ableC:abstractsyntax:debug;

import silver:util:raw:treemap as tm;

global builtin::Location = builtinLoc("closure");

abstract production lambdaExpr
top::Expr ::= allocator::MaybeExpr captured::MaybeCaptureList params::Parameters res::Expr
{
  propagate substituted;
  top.pp = pp"lambda ${case allocator of justExpr(e) -> pp"(${e.pp}) " | _ -> pp"" end}${captured.pp}(${ppImplode(text(", "), params.pps)}) -> (${res.pp})";
  
  local localErrors::[Message] =
    checkAllocatorErrors(top.location, allocator) ++
    allocator.errors ++ captured.errors ++ params.errors ++ res.errors;
  
  local paramNames::[Name] =
    map(name(_, location=builtin), map(fst, foldr(append, [], map((.valueContribs), params.defs))));
  captured.freeVariablesIn = removeAllBy(nameEq, paramNames, nubBy(nameEq, res.freeVariables));
  res.env = openScopeEnv(addEnv(params.defs, params.env));
  res.returnType = just(res.typerep);
  
  local fwrd::Expr =
    lambdaStmtExpr(
      allocator, captured, params,
      typeName(directTypeExpr(res.typerep), baseTypeExpr()),
      returnStmt(justExpr(res)),
      location=top.location);
  
  forwards to mkErrorCheck(localErrors, fwrd);
}

abstract production lambdaStmtExpr
top::Expr ::= allocator::MaybeExpr captured::MaybeCaptureList params::Parameters res::TypeName body::Stmt
{
  propagate substituted;
  top.pp = pp"lambda ${case allocator of justExpr(e) -> pp"(${e.pp}) " | _ -> pp"" end}${captured.pp}(${ppImplode(text(", "), params.pps)}) -> (${res.pp}) ${braces(nestlines(2, body.pp))}";
  
  local localErrors::[Message] =
    checkAllocatorErrors(top.location, allocator) ++
    allocator.errors ++ captured.errors ++ params.errors ++ res.errors ++ body.errors;
  
  local paramNames::[Name] =
    map(name(_, location=builtin), map(fst, foldr(append, [], map((.valueContribs), params.defs))));
  captured.freeVariablesIn = removeAllBy(nameEq, paramNames, nubBy(nameEq, body.freeVariables));
  captured.globalEnv = addEnv(params.defs ++ res.defs, globalEnv(top.env));
  
  res.env = top.env;
  res.returnType = nothing();
  params.env = addEnv(res.defs, res.env);
  body.env = openScopeEnv(addEnv(params.defs, params.env));
  body.returnType = just(res.typerep);
  
  local id::String = toString(genInt()); 
  local envStructName::String = s"_lambda_env_${id}_s";
  local funName::String = s"_lambda_fn_${id}";
  
  captured.structNameIn = envStructName;
  
  local envStructDcl::Decl =
    typeExprDecl(
      nilAttribute(),
      structTypeExpr(
        nilQualifier(),
        structDecl(
          nilAttribute(),
          justName(name(envStructName, location=builtin)),
          captured.envStructTrans,
          location=builtin)));
  
  local funDcl::Decl =
    substDecl(
      [typedefSubstitution("__res_type__", typeModifierTypeExpr(res.bty, res.mty)),
       parametersSubstitution("__params__", params),
       stmtSubstitution("__env_copy__", captured.envCopyOutTrans),
       stmtSubstitution("__body__", body)],
      decls(
        parseDecls(s"""
proto_typedef __res_type__, __params__;
static __res_type__ ${funName}(void *_env_ptr, __params__) {
  struct ${envStructName} _env = *(struct ${envStructName}*)_env_ptr;
  __env_copy__;
  __body__;
}
""")));
  
  local globalDecls::Decls = foldDecl([envStructDcl, funDcl]);
  
  local fwrd::Expr =
    substExpr(
      [declRefSubstitution(
         "__allocator__",
         case allocator of
           justExpr(e) -> e
         | nothingExpr() -> declRefExpr(name("GC_malloc", location=builtin), location=builtin)
         end),
       typedefSubstitution(
         "__closure_type__",
         closureTypeExpr(
           nilQualifier(),
           argTypesToParameters(params.typereps),
           typeName(directTypeExpr(res.typerep), baseTypeExpr()))),
       initializerSubstitution("__env_init__", objectInitializer(captured.envInitTrans))],
      parseExpr(s"""
({proto_typedef __closure_type__;
  struct ${envStructName} _env = __env_init__;
  
  struct ${envStructName} *_env_ptr = __allocator__(sizeof(struct ${envStructName}));
  *_env_ptr = _env;
  
  __closure_type__ _result;
  _result._fn_name = "${funName}";
  _result._env = (void*)_env_ptr;
  _result._fn = ${funName};
  _result;})
"""));
  
  forwards to
    mkErrorCheck(localErrors, injectGlobalDeclsExpr(globalDecls, fwrd, location=top.location));
}

function checkAllocatorErrors
[Message] ::= loc::Location allocator::Decorated MaybeExpr
{
  local expectedType::Type =
    functionType(
      pointerType(
        nilQualifier(),
        builtinType(nilQualifier(), voidType())),
      protoFunctionType([builtinType(nilQualifier(), unsignedType(longType()))], false),
      nilQualifier());
    
  return
    case allocator of
      justExpr(e) ->
      if compatibleTypes(expectedType, e.typerep, true, false) then []
      else [err(e.location, s"Allocator must have type void*(unsigned long) (got ${showType(e.typerep)})")]
    | nothingExpr() ->
      if !null(lookupValue("GC_malloc", allocator.env)) then []
      else [err(loc, "Lambdas lacking an explicit allocator require <gc.h> to be included.")]
    end;
}

synthesized attribute envStructTrans::StructItemList;
synthesized attribute envInitTrans::InitList; -- Initializer body for _env using vars
synthesized attribute envCopyOutTrans::Stmt; -- Copys _env out to vars

autocopy attribute globalEnv::Decorated Env;
autocopy attribute structNameIn::String;
autocopy attribute freeVariablesIn::[Name];

nonterminal MaybeCaptureList with env, globalEnv, structNameIn, freeVariablesIn, pp, errors, envStructTrans, envInitTrans, envCopyOutTrans;

abstract production justCaptureList
top::MaybeCaptureList ::= cl::CaptureList
{
  top.pp = pp"[${cl.pp}]";
  top.errors := cl.errors;
  top.envStructTrans = cl.envStructTrans;
  top.envInitTrans = cl.envInitTrans;
  top.envCopyOutTrans = cl.envCopyOutTrans;
}

abstract production nothingCaptureList
top::MaybeCaptureList ::=
{
  top.pp = pp"";
  top.errors := envContents.errors; -- Should be []
  top.envStructTrans = envContents.envStructTrans;
  top.envInitTrans = envContents.envInitTrans;
  top.envCopyOutTrans = envContents.envCopyOutTrans;
  
  local envContents::CaptureList =
    foldr(consCaptureList, nilCaptureList(), nubBy(nameEq, top.freeVariablesIn));
  envContents.env = top.env;
  envContents.globalEnv = top.globalEnv;
  envContents.structNameIn = top.structNameIn;
}

nonterminal CaptureList with env, globalEnv, structNameIn, pp, errors, envStructTrans, envInitTrans, envCopyOutTrans;

abstract production consCaptureList
top::CaptureList ::= n::Name rest::CaptureList
{
  top.pp = pp"${n.pp}, ${rest.pp}";
  
  top.errors := rest.errors;
  top.errors <- n.valueLookupCheck;
  top.errors <-
    if n.valueItem.isItemValue
    then []
    else [err(n.location, "'" ++ n.name ++ "' does not refer to a value.")];

  -- Strip qualifiers and convert arrays and functions to pointers
  local varType::Type =
    case n.valueItem.typerep of
      arrayType(elem, _, _, _) -> pointerType(nilQualifier(), elem)
    | functionType(res, sub, q) ->
        pointerType(nilQualifier(), noncanonicalType(parenType(functionType(res, sub, q))))
    | t -> t
    end;
  
  -- If true, then this variable is in scope for the lifted function and doesn't need to be captured
  local isGlobal::Boolean = !null(lookupValue(n.name, top.globalEnv));
  
  top.envStructTrans =
    if isGlobal then rest.envStructTrans else
      consStructItem(
        structItem(
          nilAttribute(),
          directTypeExpr(varType),
          consStructDeclarator(
            structField(n, baseTypeExpr(), nilAttribute()),
            nilStructDeclarator())),
        rest.envStructTrans);
  
  top.envInitTrans =
    if isGlobal then rest.envInitTrans else
      consInit(
        init(exprInitializer(declRefExpr(n, location=builtin))),
        rest.envInitTrans);
  
  top.envCopyOutTrans =
    if isGlobal then rest.envCopyOutTrans else
      seqStmt(
        declStmt(
          variableDecls(
            [], nilAttribute(),
            directTypeExpr(addQualifiers([constQualifier(location=builtin)], varType)),
            consDeclarator(
              declarator(
                n,
                baseTypeExpr(),
                nilAttribute(),
                justInitializer(
                  exprInitializer(
                    memberExpr(
                      declRefExpr(name("_env", location=builtin), location=builtin),
                      false,
                      n,
                      location=builtin)))),
              nilDeclarator()))),
        rest.envCopyOutTrans);
}

abstract production nilCaptureList
top::CaptureList ::=
{
  top.pp = pp"";
  top.errors := [];
  
  top.envStructTrans = nilStructItem();
  top.envInitTrans = nilInit();
  top.envCopyOutTrans = nullStmt();
}
