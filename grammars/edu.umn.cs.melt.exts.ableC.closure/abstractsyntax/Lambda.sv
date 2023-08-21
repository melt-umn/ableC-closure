grammar edu:umn:cs:melt:exts:ableC:closure:abstractsyntax;

imports silver:langutil;
imports silver:langutil:pp;

imports edu:umn:cs:melt:ableC:abstractsyntax:host;
imports edu:umn:cs:melt:ableC:abstractsyntax:construction;
imports edu:umn:cs:melt:ableC:abstractsyntax:env;
imports edu:umn:cs:melt:ableC:abstractsyntax:overloadable as ovrld;
imports silver:util:treemap as tm;
--imports edu:umn:cs:melt:ableC:abstractsyntax:debug;

global builtin::Location = builtinLoc("closure");

abstract production lambdaExpr
top::Expr ::= allocator::MaybeExpr captured::CaptureList params::Parameters res::Expr
{
  top.pp = pp"lambda ${case allocator of justExpr(e) -> pp"allocate(${e.pp}) " | _ -> pp"" end}[${captured.pp}](${ppImplode(text(", "), params.pps)}) -> (${res.pp})";
  allocator.env = top.env;
  allocator.controlStmtContext = top.controlStmtContext;

  forwards to
    lambdaTransExpr(
      fromMaybeAllocator(allocator),
      @captured, @params, @res, 
      closureType, closureStructDecl, closureStructName, nullStmt(), nullStmt(),
      location=top.location);
}

abstract production lambdaStmtExpr
top::Expr ::= allocator::MaybeExpr captured::CaptureList params::Parameters res::TypeName body::Stmt
{
  top.pp = pp"lambda ${case allocator of justExpr(e) -> pp"allocate(${e.pp}) " | _ -> pp"" end}[${captured.pp}](${ppImplode(text(", "), params.pps)}) -> ${res.pp} ${braces(nestlines(2, body.pp))}";
  allocator.env = top.env;
  allocator.controlStmtContext = top.controlStmtContext;
  
  forwards to
    lambdaStmtTransExpr(
      fromMaybeAllocator(allocator),
      @captured, @params, @res, @body,
      closureType, closureStructDecl, closureStructName, nullStmt(), nullStmt(),
      location=top.location);
}

abstract production lambdaTransExpr
top::Expr ::= allocator::(Expr ::= Expr Location) captured::CaptureList params::Parameters res::Expr
  closureType::(ExtType ::= [Type] Type) closureStructDecl::(Decl ::= Parameters TypeName) closureStructName::(String ::= [Type] Type) extraInit1::Stmt extraInit2::Stmt
{
  top.pp = pp"trans lambda [${captured.pp}](${ppImplode(text(", "), params.pps)}) -> (${res.pp})";
  
  local localErrors::[Message] = params.errors ++ res.errors;
  params.env = openScopeEnv(top.env);  -- Equation needed to avoid circularity
  
  local resType::Type = res.typerep.withoutTypeQualifiers;
  forward fwrd =
    lambdaStmtTransExpr(
      allocator, @captured, @params,
      typeName(resType.baseTypeExpr, resType.typeModifierExpr),
      returnIfNotVoid(@res),
      closureType, closureStructDecl, closureStructName, extraInit1, extraInit2,
      location=top.location);
  
  forwards to if null(localErrors) then @fwrd else errorExpr(localErrors, location=top.location);
}

abstract production returnIfNotVoid
top::Stmt ::= e::Expr
{
  top.pp = pp"returnIfNotVoid ${e.pp};";
  top.functionDefs := [];
  top.labelDefs := [];
  e.env = top.env;
  e.controlStmtContext = top.controlStmtContext;
  forwards to 
    case e.typerep of
    | builtinType(_, voidType()) -> exprStmt(@e)
    | _ -> returnStmt(justExpr(@e))
    end;
}

abstract production lambdaStmtTransExpr
top::Expr ::= allocator::(Expr ::= Expr Location) captured::CaptureList params::Parameters res::TypeName body::Stmt
  closureType::(ExtType ::= [Type] Type) closureStructDecl::(Decl ::= Parameters TypeName) closureStructName::(String ::= [Type] Type) extraInit1::Stmt extraInit2::Stmt
{
  top.pp = pp"trans lambda [${captured.pp}](${ppImplode(text(", "), params.pps)}) -> ${res.pp} ${braces(nestlines(2, body.pp))}";
  
  local localErrors::[Message] =
    checkMemcpyErrors(top.location, top.env) ++
    captured.errors ++ params.errors ++ res.errors ++ body.errors;
  
  local paramNames::[Name] =
    map(name(_, location=builtin), map(fst, foldr(append, [], map((.valueContribs), params.functionDefs))));
  captured.freeVariablesIn = removeAll(paramNames, nub(body.freeVariables));
  
  res.env = top.env;
  res.controlStmtContext = initialControlStmtContext;
  params.env = openScopeEnv(capturedEnv(res.env));
  body.env = addEnv(params.defs ++ params.functionDefs ++ body.functionDefs, openScopeEnv(params.env));
  body.controlStmtContext = controlStmtContext(just(res.typerep), false, false, tm:fromList(body.labelDefs));
  captured.env =
    addEnv(globalDeclsDefs(params.globalDecls ++ res.globalDecls ++ body.globalDecls), top.env);
  captured.currentFunctionNameIn =
    case lookupMisc("this_func", top.env) of
    | currentFunctionItem(n, _) :: _ -> n.name
    | _ -> ""
    end;
  
  production closureTypeStructName::String = closureStructName(params.typereps, res.typerep);
  production id::String = toString(genInt()); 
  production envStructName::String = s"_lambda_env_${id}_s";
  production funName::String = s"_lambda_fn_${id}";
  
  captured.structNameIn = envStructName;
  
  local globalDecls::Decls =
    ableC_Decls {
      $Decl{
        closureStructDecl(
          argTypesToParameters(params.typereps),
          typeName(directTypeExpr(res.typerep), baseTypeExpr()))}

      $Decl{
        typeExprDecl(
          nilAttribute(),
          structTypeExpr(
            nilQualifier(),
            structDecl(
              nilAttribute(),
              justName(name(envStructName, location=builtin)),
              captured.envStructTrans,
              location=builtin)))}

      static $BaseTypeExpr{typeModifierTypeExpr(res.bty, res.mty)} $name{funName}(void *_env_ptr, $Parameters{@params}) {
        struct $name{envStructName} _env = *(struct $name{envStructName}*)_env_ptr;
        $Stmt{captured.envCopyOutTrans}
        $Stmt{@body}
      }
    };
  
  local resExpr::Expr =
    ableC_Expr {
      ({struct $name{envStructName} _env = $Initializer{objectInitializer(captured.envInitTrans, location=builtin)};
        
        $Stmt{@extraInit1};
        
        struct $name{envStructName} *_env_ptr =
          $Expr{allocator(ableC_Expr {sizeof(struct $name{envStructName})}, top.location)};
        memcpy(_env_ptr, &_env, sizeof(struct $name{envStructName}));
        
        struct $name{closureTypeStructName} _result;
        _result.fn_name = $stringLiteralExpr{funName};
        _result.env = (void*)_env_ptr;
        _result.fn = $name{funName};
        
        $Stmt{@extraInit2};
        
        ($directTypeExpr{extType(nilQualifier(), closureType(params.typereps, res.typerep))})_result;})
    };

  forward fwrd = injectGlobalDeclsExpr(@globalDecls, @resExpr, location=top.location);

  forwards to if null(localErrors) then @fwrd else errorExpr(localErrors, location=top.location);
}

global expectedAllocatorType::Type =
  pointerType(
    nilQualifier(),
    functionType(
      pointerType(
        nilQualifier(),
        builtinType(nilQualifier(), voidType())),
      protoFunctionType([builtinType(nilQualifier(), unsignedType(longType()))], false),
      nilQualifier()));

function fromMaybeAllocator
(Expr ::= Expr Location) ::= allocator::Decorated MaybeExpr
{
  return
    case allocator of
      justExpr(e) ->
        if typeAssignableTo(expectedAllocatorType, e.typerep)
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

inherited attribute structNameIn::String;
inherited attribute freeVariablesIn::[Name];
inherited attribute currentFunctionNameIn::String;

nonterminal CaptureList with env, structNameIn, freeVariablesIn, currentFunctionNameIn, pp, errors, envStructTrans, envInitTrans, envCopyOutTrans;

propagate env, structNameIn, currentFunctionNameIn, errors on CaptureList;

abstract production freeVariablesCaptureList
top::CaptureList ::=
{
  top.pp = pp"...";
  forwards to foldr(consCaptureList, nilCaptureList(), nub(top.freeVariablesIn));
}

abstract production consCaptureList
top::CaptureList ::= n::Name rest::CaptureList
{
  top.pp = pp"${n.pp}, ${rest.pp}";
  
  top.errors <- n.valueLookupCheck;
  top.errors <-
    if n.valueItem.isItemValue
    then []
    else [err(n.location, "'" ++ n.name ++ "' does not refer to a value.")];
  
  -- Strip qualifiers and convert arrays and functions to pointers
  production varType::Type =
    case n.valueItem.typerep of
    | arrayType(elem, _, _, _) -> pointerType(nilQualifier(), elem)
    | functionType(res, sub, q) ->
        pointerType(nilQualifier(), noncanonicalType(parenType(functionType(res, sub, q))))
    | t -> t
    end;
  varType.inArrayType = false;
  
  -- If true, then this variable is in scope for the lifted function and doesn't need to be captured
  production isGlobal::Boolean =
    !null(lookupValue(n.name, top.env)) &&
    null(lookupValue(n.name, nonGlobalEnv(top.env)))
    -- The current top-level function still needs to be captured
    && n.name != top.currentFunctionNameIn;
  
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
        positionalInit(exprInitializer(declRefExpr(n, location=builtin), location=builtin)),
        rest.envInitTrans);
  
  top.envCopyOutTrans =
    if isGlobal then rest.envCopyOutTrans else
      ableC_Stmt {
        const $directTypeExpr{varType.defaultFunctionArrayLvalueConversion.withoutTypeQualifiers} $Name{n} = _env.$Name{n};
        $Stmt{rest.envCopyOutTrans}
      };
  
  rest.freeVariablesIn = remove(n, top.freeVariablesIn);
}

abstract production nilCaptureList
top::CaptureList ::=
{
  top.pp = pp"";
  
  top.envStructTrans = nilStructItem();
  top.envInitTrans = nilInit();
  top.envCopyOutTrans = nullStmt();
}

-- Convert VLAs to incomplete/constant-length arrays within the struct definition
-- where the VLA size arguments aren't visible.
inherited attribute inArrayType::Boolean occurs on Type, ArrayType;
functor attribute variableArrayConversion occurs on Type, ArrayType, FunctionType;

propagate inArrayType on Type, ArrayType excluding pointerType, arrayType, functionType;

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
  sub.inArrayType = top.inArrayType;
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
