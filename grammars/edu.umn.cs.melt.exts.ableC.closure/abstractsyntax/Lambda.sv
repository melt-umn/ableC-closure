grammar edu:umn:cs:melt:exts:ableC:closure:abstractsyntax;

imports silver:langutil;
imports silver:langutil:pp;

imports edu:umn:cs:melt:ableC:abstractsyntax:host;
imports edu:umn:cs:melt:ableC:abstractsyntax:construction;
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
      closureType, closureStructDecl, closureStructName, nullStmt(), nullStmt(),
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
      closureType, closureStructDecl, closureStructName, nullStmt(), nullStmt(),
      location=top.location);
}

abstract production lambdaTransExpr
top::Expr ::= allocator::(Expr ::= Expr Location) captured::CaptureList params::Parameters res::Expr
  closureType::(ExtType ::= [Type] Type) closureStructDecl::(Decl ::= Parameters TypeName) closureStructName::(String ::= [Type] Type) extraInit1::Stmt extraInit2::Stmt
{
  propagate substituted;
  top.pp = pp"trans lambda [${captured.pp}](${ppImplode(text(", "), params.pps)}) -> (${res.pp})";
  
  local localErrors::[Message] = res.errors;
  params.env = openScopeEnv(top.env);
  params.position = 0;
  res.env = addEnv(params.defs ++ params.functionDefs, capturedEnv(params.env));
  res.returnType = just(res.typerep);
  
  local fwrd::Expr =
    lambdaStmtTransExpr(
      allocator, captured, params,
      typeName(directTypeExpr(res.typerep.withoutTypeQualifiers), baseTypeExpr()),
      case res.typerep of
        builtinType(_, voidType()) -> exprStmt(decExpr(res, location=builtin))
      | _ -> returnStmt(justExpr(res))
      end,
      closureType, closureStructDecl, closureStructName, extraInit1, extraInit2,
      location=top.location);
  
  forwards to mkErrorCheck(localErrors, fwrd);
}

abstract production lambdaStmtTransExpr
top::Expr ::= allocator::(Expr ::= Expr Location) captured::CaptureList params::Parameters res::TypeName body::Stmt
  closureType::(ExtType ::= [Type] Type) closureStructDecl::(Decl ::= Parameters TypeName) closureStructName::(String ::= [Type] Type) extraInit1::Stmt extraInit2::Stmt
{
  propagate substituted;
  top.pp = pp"trans lambda [${captured.pp}](${ppImplode(text(", "), params.pps)}) -> (${res.pp}) ${braces(nestlines(2, body.pp))}";
  
  local localErrors::[Message] =
    checkMemcpyErrors(top.location, top.env) ++
    captured.errors ++ params.errors ++ res.errors ++ body.errors;
  
  local paramNames::[Name] =
    map(name(_, location=builtin), map(fst, foldr(append, [], map((.valueContribs), params.functionDefs))));
  captured.freeVariablesIn = removeAllBy(nameEq, paramNames, nubBy(nameEq, body.freeVariables));
  
  res.returnType = nothing();
  params.env = openScopeEnv(addEnv(res.defs, res.env));
  params.position = 0;
  body.env = addEnv(params.defs ++ params.functionDefs, capturedEnv(params.env));
  body.returnType = just(res.typerep);
  captured.env =
    addEnv(globalDeclsDefs(params.globalDecls ++ res.globalDecls ++ body.globalDecls), top.env);
  
  production closureTypeStructName::String = closureStructName(params.typereps, res.typerep);
  production id::String = toString(genInt()); 
  production envStructName::String = s"_lambda_env_${id}_s";
  production funName::String = s"_lambda_fn_${id}";
  
  captured.structNameIn = envStructName;
  
  local closureTypeStructDcl::Decl =
    closureStructDecl(
      argTypesToParameters(params.typereps),
      typeName(directTypeExpr(res.typerep), baseTypeExpr()));
  
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
    ableC_Decl {
      static $BaseTypeExpr{typeModifierTypeExpr(res.bty, res.mty)} $name{funName}(void *_env_ptr, $Parameters{params}) {
        struct $name{envStructName} _env = *(struct $name{envStructName}*)_env_ptr;
        $Stmt{captured.envCopyOutTrans}
        $Stmt{decStmt(body)}
      }
    };
  
  local globalDecls::Decls = foldDecl([closureTypeStructDcl, envStructDcl, funDcl]);
  
  local fwrd::Expr =
    ableC_Expr {
      ({struct $name{envStructName} _env = $Initializer{objectInitializer(captured.envInitTrans)};
        
        $Stmt{extraInit1};
        
        struct $name{envStructName} *_env_ptr =
          $Expr{allocator(ableC_Expr {sizeof(struct $name{envStructName})}, top.location)};
        memcpy(_env_ptr, &_env, sizeof(struct $name{envStructName}));
        
        struct $name{closureTypeStructName} _result;
        _result.fn_name = $stringLiteralExpr{funName};
        _result.env = (void*)_env_ptr;
        _result.fn = $name{funName};
        
        $Stmt{extraInit2};
        
        ($directTypeExpr{extType(nilQualifier(), closureType(params.typereps, res.typerep))})_result;})
    };
  
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

autocopy attribute structNameIn::String;
autocopy attribute freeVariablesIn::[Name];

nonterminal CaptureList with env, structNameIn, freeVariablesIn, pp, errors, envStructTrans, envInitTrans, envCopyOutTrans;

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
  varType.inArrayType = false;
  
  -- If true, then this variable is in scope for the lifted function and doesn't need to be captured
  production isGlobal::Boolean =
    !null(lookupValue(n.name, top.env)) && null(lookupValue(n.name, nonGlobalEnv(top.env)));
  
  top.envStructTrans =
    if isGlobal then rest.envStructTrans else
      consStructItem(
        structItem(
          nilAttribute(),
          directTypeExpr(varType.variableArrayConversion),
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
      ableC_Stmt {
        const $directTypeExpr{varType} $Name{n} = _env.$Name{n};
        $Stmt{rest.envCopyOutTrans}
      };
  
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

-- Convert VLAs to incomplete/constant-length arrays within the struct definition
-- where the VLA size arguments aren't visible.
autocopy attribute inArrayType::Boolean occurs on Type, ArrayType;
synthesized attribute variableArrayConversion<a>::a;
attribute variableArrayConversion<Type> occurs on Type;
attribute variableArrayConversion<ArrayType> occurs on ArrayType;
attribute variableArrayConversion<FunctionType> occurs on FunctionType;

aspect default production
top::Type ::=
{
  top.variableArrayConversion = top;
}

aspect production pointerType
top::Type ::= q::Qualifiers  target::Type
{
  propagate variableArrayConversion;
  target.inArrayType = false;
}

aspect production arrayType
top::Type ::= element::Type  indexQualifiers::Qualifiers  sizeModifier::ArraySizeModifier  sub::ArrayType
{
  propagate variableArrayConversion;
  element.inArrayType = true;
}

aspect production constantArrayType
top::ArrayType ::= size::Integer
{
  propagate variableArrayConversion;
}

aspect production incompleteArrayType
top::ArrayType ::=
{
  propagate variableArrayConversion;
}

aspect production variableArrayType
top::ArrayType ::= size::Decorated Expr
{
  top.variableArrayConversion =
    if !top.inArrayType then incompleteArrayType() else constantArrayType(1);
}

aspect production functionType
top::Type ::= result::Type  sub::FunctionType  q::Qualifiers
{
  propagate variableArrayConversion;
  result.inArrayType = false;
}

aspect production protoFunctionType
top::FunctionType ::= args::[Type]  variadic::Boolean
{
  top.variableArrayConversion =
    protoFunctionType(map(doVariableArrayConversion, args), variadic);
}

aspect production noProtoFunctionType
top::FunctionType ::=
{
  propagate variableArrayConversion;
}

aspect production atomicType
top::Type ::= q::Qualifiers  bt::Type
{
  propagate variableArrayConversion;
}

aspect production attributedType
top::Type ::= attrs::Attributes  bt::Type
{
  propagate variableArrayConversion;
}

aspect production vectorType
top::Type ::= bt::Type  bytes::Integer
{
  propagate variableArrayConversion;
}

function doVariableArrayConversion
Type ::= t::Type
{
  t.inArrayType = false;
  return t.variableArrayConversion;
}
