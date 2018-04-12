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

global builtin::Location = builtinLoc("closure");

abstract production lambdaExpr
top::Expr ::= allocator::MaybeExpr captured::CaptureList params::Parameters res::Expr
{
  propagate substituted;
  top.pp = pp"lambda ${case allocator of justExpr(e) -> pp"allocate(${e.pp}) " | _ -> pp"" end}[${captured.pp}](${ppImplode(text(", "), params.pps)}) -> (${res.pp})";
  
  forwards to
    lambdaTransExpr(
      fromMaybeAllocator(allocator),
      captured, params, res, 
      closureTypeExpr, nullStmt(), nullStmt(),
      location=top.location);
}

abstract production lambdaStmtExpr
top::Expr ::= allocator::MaybeExpr captured::CaptureList params::Parameters res::TypeName body::Stmt
{
  propagate substituted;
  top.pp = pp"lambda ${case allocator of justExpr(e) -> pp"allocate(${e.pp}) " | _ -> pp"" end}[${captured.pp}](${ppImplode(text(", "), params.pps)}) -> (${res.pp}) ${braces(nestlines(2, body.pp))}";
  
  forwards to
    lambdaStmtTransExpr(
      fromMaybeAllocator(allocator),
      captured, params, res, body,
      closureTypeExpr, nullStmt(), nullStmt(),
      location=top.location);
}

abstract production lambdaTransExpr
top::Expr ::= allocator::(Expr ::= Expr Location) captured::CaptureList params::Parameters res::Expr closureTypeExpr::(BaseTypeExpr ::= Qualifiers Parameters TypeName) extraInit1::Stmt extraInit2::Stmt
{
  propagate substituted;
  top.pp = pp"trans lambda [${captured.pp}](${ppImplode(text(", "), params.pps)}) -> (${res.pp})";
  
  local localErrors::[Message] = res.errors;
  params.env = openScopeEnv(top.env);
  res.env = addEnv(params.defs, params.env);
  res.returnType = just(res.typerep);
  
  local fwrd::Expr =
    lambdaStmtTransExpr(
      allocator, captured, params,
      typeName(directTypeExpr(res.typerep.withoutTypeQualifiers), baseTypeExpr()),
      case res.typerep of
        builtinType(_, voidType()) -> exprStmt(res)
      | _ -> returnStmt(justExpr(res))
      end,
      closureTypeExpr, extraInit1, extraInit2,
      location=top.location);
  
  forwards to mkErrorCheck(localErrors, fwrd);
}

abstract production lambdaStmtTransExpr
top::Expr ::= allocator::(Expr ::= Expr Location) captured::CaptureList params::Parameters res::TypeName body::Stmt closureTypeExpr::(BaseTypeExpr ::= Qualifiers Parameters TypeName) extraInit1::Stmt extraInit2::Stmt
{
  propagate substituted;
  top.pp = pp"trans lambda [${captured.pp}](${ppImplode(text(", "), params.pps)}) -> (${res.pp}) ${braces(nestlines(2, body.pp))}";
  
  local localErrors::[Message] =
    checkMemcpyErrors(top.location, top.env) ++
    captured.errors ++ params.errors ++ res.errors ++ body.errors;
  
  local paramNames::[Name] =
    map(name(_, location=builtin), map(fst, foldr(append, [], map((.valueContribs), params.defs))));
  captured.freeVariablesIn = removeAllBy(nameEq, paramNames, nubBy(nameEq, body.freeVariables));
  captured.globalEnv = addEnv(params.defs ++ res.defs, globalEnv(top.env));
  
  res.env = top.env;
  res.returnType = nothing();
  params.env = openScopeEnv(addEnv(res.defs, res.env));
  body.env = addEnv(params.defs, params.env);
  body.returnType = just(res.typerep);
  
  production id::String = toString(genInt()); 
  production envStructName::String = s"_lambda_env_${id}_s";
  production funName::String = s"_lambda_fn_${id}";
  
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
      [initializerSubstitution(
         "__env_init__",
         objectInitializer(
           captured.envInitTrans)),
       stmtSubstitution("__extra_init_1__", extraInit1),
       declRefSubstitution(
         "__allocator__",
         allocator(parseExpr(s"sizeof(struct ${envStructName})"), top.location)),
       typedefSubstitution(
         "__closure_type__",
         closureTypeExpr(
           nilQualifier(),
           argTypesToParameters(params.typereps),
           typeName(directTypeExpr(res.typerep), baseTypeExpr()))),
       stmtSubstitution("__extra_init_2__", extraInit2)],
      parseExpr(s"""
({proto_typedef __closure_type__;
  struct ${envStructName} _env = __env_init__;
  
  __extra_init_1__;
  
  struct ${envStructName} *_env_ptr = __allocator__;
  memcpy(_env_ptr, &_env, sizeof(struct ${envStructName}));
  
  __closure_type__ _result;
  _result._fn_name = "${funName}";
  _result._env = (void*)_env_ptr;
  _result._fn = ${funName};
  
  __extra_init_2__;
  
  _result;})
"""));
  
  forwards to
    mkErrorCheck(localErrors, injectGlobalDeclsExpr(globalDecls, fwrd, location=top.location));
}

function fromMaybeAllocator
(Expr ::= Expr Location) ::= allocator::Decorated MaybeExpr
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
        if compatibleTypes(expectedType, e.typerep, true, false)
        then \ size::Expr loc::Location -> callExpr(e, consExpr(size, nilExpr()), location=loc)
        else
          \ size::Expr loc::Location ->
            errorExpr([err(e.location, s"Allocator must have type void *(unsigned long) (got ${showType(e.typerep)})")], location=loc)
    | nothingExpr() ->
        if !null(lookupValue("GC_malloc", allocator.env))
        then
          \ size::Expr loc::Location ->
            directCallExpr(
              name("GC_malloc", location=builtin),
              consExpr(size, nilExpr()),
              location=loc)
        else
          \ size::Expr loc::Location ->
            errorExpr([err(loc, "Lambda lacking an explicit allocator requires <gc.h> to be included.")], location=loc)
    end;
}

function checkMemcpyErrors
[Message] ::= loc::Location env::Decorated Env
{
  return
    if !null(lookupValue("memcpy", env)) then []
    else [err(loc, "Lambda requires definition of memcpy (include <string.h>?).")];
}

synthesized attribute envStructTrans::StructItemList;
synthesized attribute envInitTrans::InitList; -- Initializer body for _env using vars
synthesized attribute envCopyOutTrans::Stmt; -- Copys _env out to vars

autocopy attribute globalEnv::Decorated Env;
autocopy attribute structNameIn::String;
autocopy attribute freeVariablesIn::[Name];

nonterminal CaptureList with env, globalEnv, structNameIn, freeVariablesIn, pp, errors, envStructTrans, envInitTrans, envCopyOutTrans;

abstract production freeVariablesCaptureList
top::CaptureList ::=
{
  top.pp = pp"...";
  forwards to foldr(consCaptureList, nilCaptureList(), nubBy(nameEq, top.freeVariablesIn));
}

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
  production varType::Type =
    case n.valueItem.typerep of
      arrayType(elem, _, _, _) -> pointerType(nilQualifier(), elem)
    | functionType(res, sub, q) ->
        pointerType(nilQualifier(), noncanonicalType(parenType(functionType(res, sub, q))))
    | t -> t
    end;
  
  -- If true, then this variable is in scope for the lifted function and doesn't need to be captured
  production isGlobal::Boolean = !null(lookupValue(n.name, top.globalEnv));
  
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
        positionalInit(exprInitializer(declRefExpr(n, location=builtin))),
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
  
  rest.freeVariablesIn = removeBy(nameEq, n, top.freeVariablesIn);
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
