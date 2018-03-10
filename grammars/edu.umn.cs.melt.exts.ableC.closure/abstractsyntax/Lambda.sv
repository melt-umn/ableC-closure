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
top::Expr ::= allocator::MaybeExpr captured::MaybeCaptureList params::Parameters res::Expr
{
  propagate substituted;
  top.pp = pp"lambda ${case allocator of justExpr(e) -> pp"allocate(${e.pp}) " | _ -> pp"" end}${captured.pp}(${ppImplode(text(", "), params.pps)}) -> (${res.pp})";
  
  forwards to
    lambdaTransExpr(
      getAllocator(top.location, allocator),
      captured, params, res, 
      closureTypeExpr, nullStmt(), [],
      location=top.location);
}

abstract production lambdaStmtExpr
top::Expr ::= allocator::MaybeExpr captured::MaybeCaptureList params::Parameters res::TypeName body::Stmt
{
  propagate substituted;
  top.pp = pp"lambda ${case allocator of justExpr(e) -> pp"allocate(${e.pp}) " | _ -> pp"" end}${captured.pp}(${ppImplode(text(", "), params.pps)}) -> (${res.pp}) ${braces(nestlines(2, body.pp))}";
  
  forwards to
    lambdaStmtTransExpr(
      getAllocator(top.location, allocator),
      captured, params, res, body,
      closureTypeExpr, nullStmt(), [],
      location=top.location);
}

abstract production lambdaTransExpr
top::Expr ::= allocator::Expr captured::MaybeCaptureList params::Parameters res::Expr closureTypeExpr::(BaseTypeExpr ::= Qualifiers Parameters TypeName) extraInit::Stmt extraCaptureInitProds::[(Stmt ::= Name)]
{
  propagate substituted;
  top.pp = pp"trans lambda allocate(${allocator.pp}) ${captured.pp}(${ppImplode(text(", "), params.pps)}) -> (${res.pp})";
  
  local localErrors::[Message] = res.errors;
  res.env = openScopeEnv(addEnv(params.defs, params.env));
  res.returnType = just(res.typerep);
  
  local fwrd::Expr =
    lambdaStmtTransExpr(
      allocator, captured, params,
      typeName(directTypeExpr(res.typerep.withoutTypeQualifiers), baseTypeExpr()),
      case res.typerep of
        builtinType(_, voidType()) -> exprStmt(res)
      | _ -> returnStmt(justExpr(res))
      end,
      closureTypeExpr, extraInit, extraCaptureInitProds,
      location=top.location);
  
  forwards to mkErrorCheck(localErrors, fwrd);
}

abstract production lambdaStmtTransExpr
top::Expr ::= allocator::Expr captured::MaybeCaptureList params::Parameters res::TypeName body::Stmt closureTypeExpr::(BaseTypeExpr ::= Qualifiers Parameters TypeName) extraInit::Stmt extraCaptureInitProds::[(Stmt ::= Name)]
{
  propagate substituted;
  top.pp = pp"trans lambda allocate(${allocator.pp}) ${captured.pp}(${ppImplode(text(", "), params.pps)}) -> (${res.pp}) ${braces(nestlines(2, body.pp))}";
  
  local expectedAllocatorType::Type =
    functionType(
      pointerType(
        nilQualifier(),
        builtinType(nilQualifier(), voidType())),
      protoFunctionType([builtinType(nilQualifier(), unsignedType(longType()))], false),
      nilQualifier());
  
  local localErrors::[Message] =
    (if compatibleTypes(expectedAllocatorType, allocator.typerep, true, false) then []
     else [err(allocator.location, s"Allocator must have type void *(unsigned long) (got ${showType(allocator.typerep)})")]) ++
    checkMemcpyErrors(top.location, top.env) ++
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
  captured.extraInitProds = extraCaptureInitProds;
  
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
       stmtSubstitution("__extra_capture_init__", captured.extraInitTrans),
       declRefSubstitution("__allocator__", allocator),
       typedefSubstitution(
         "__closure_type__",
         closureTypeExpr(
           nilQualifier(),
           argTypesToParameters(params.typereps),
           typeName(directTypeExpr(res.typerep), baseTypeExpr()))),
       stmtSubstitution("__extra_init__", extraInit)],
      parseExpr(s"""
({proto_typedef __closure_type__;
  struct ${envStructName} _env = __env_init__;
  
  __extra_capture_init__;
  
  struct ${envStructName} *_env_ptr = __allocator__(sizeof(struct ${envStructName}));
  memcpy(_env_ptr, &_env, sizeof(struct ${envStructName}));
  
  __closure_type__ _result;
  _result._fn_name = "${funName}";
  _result._env = (void*)_env_ptr;
  _result._fn = ${funName};
  
  __extra_init__;
  
  _result;})
"""));
  
  forwards to
    mkErrorCheck(localErrors, injectGlobalDeclsExpr(globalDecls, fwrd, location=top.location));
}

function getAllocator
Expr ::= loc::Location allocator::Decorated MaybeExpr
{
  return
    case allocator of
      justExpr(e) -> e
    | nothingExpr() ->
      if !null(lookupValue("GC_malloc", allocator.env))
      then declRefExpr(name("GC_malloc", location=builtin), location=builtin)
      else errorExpr([err(loc, "Lambda lacking an explicit allocator requires <gc.h> to be included.")], location=builtin)
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
synthesized attribute extraInitTrans::Stmt; -- Extra initialization statments for each captured var
synthesized attribute envCopyOutTrans::Stmt; -- Copys _env out to vars

autocopy attribute globalEnv::Decorated Env;
autocopy attribute structNameIn::String;
autocopy attribute freeVariablesIn::[Name];
autocopy attribute extraInitProds::[(Stmt ::= Name)];

nonterminal MaybeCaptureList with env, globalEnv, structNameIn, freeVariablesIn, extraInitProds, pp, errors, envStructTrans, envInitTrans, envCopyOutTrans, extraInitTrans;

abstract production justCaptureList
top::MaybeCaptureList ::= cl::CaptureList
{
  top.pp = pp"[${cl.pp}]";
  top.errors := cl.errors;
  top.envStructTrans = cl.envStructTrans;
  top.envInitTrans = cl.envInitTrans;
  top.extraInitTrans = cl.extraInitTrans;
  top.envCopyOutTrans = cl.envCopyOutTrans;
}

abstract production nothingCaptureList
top::MaybeCaptureList ::=
{
  top.pp = pp"";
  top.errors := envContents.errors; -- Should be []
  top.envStructTrans = envContents.envStructTrans;
  top.envInitTrans = envContents.envInitTrans;
  top.extraInitTrans = envContents.extraInitTrans;
  top.envCopyOutTrans = envContents.envCopyOutTrans;
  
  local envContents::CaptureList =
    foldr(consCaptureList, nilCaptureList(), nubBy(nameEq, top.freeVariablesIn));
  envContents.env = top.env;
  envContents.globalEnv = top.globalEnv;
  envContents.structNameIn = top.structNameIn;
  envContents.extraInitProds = top.extraInitProds;
}

nonterminal CaptureList with env, globalEnv, structNameIn, extraInitProds, pp, errors, envStructTrans, envInitTrans, envCopyOutTrans, extraInitTrans;

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
  
  top.extraInitTrans =
    seqStmt(
      foldStmt(map(\ prod::(Stmt ::= Name) -> prod(n), top.extraInitProds)),
      rest.extraInitTrans);
  
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
  top.extraInitTrans = nullStmt();
  top.envCopyOutTrans = nullStmt();
}
