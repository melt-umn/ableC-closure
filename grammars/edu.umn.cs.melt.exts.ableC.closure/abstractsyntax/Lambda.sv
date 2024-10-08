grammar edu:umn:cs:melt:exts:ableC:closure:abstractsyntax;

imports silver:langutil;
imports silver:langutil:pp;

imports edu:umn:cs:melt:ableC:abstractsyntax:host;
imports edu:umn:cs:melt:ableC:abstractsyntax:construction;
imports edu:umn:cs:melt:ableC:abstractsyntax:env;
imports silver:util:treemap as tm;
--imports edu:umn:cs:melt:ableC:abstractsyntax:debug;

imports edu:umn:cs:melt:exts:ableC:allocation:abstractsyntax;

abstract production lambdaExpr
top::Expr ::= captured::CaptureList params::Parameters res::Expr
{
  top.pp = pp"lambda ${captured.pp}](${ppImplode(text(", "), params.pps)}) -> (${res.pp})";

  params.env = openScopeEnv(top.env);  -- Equation needed to avoid circularity
  params.controlStmtContext = initialControlStmtContext;
  params.position = 0;
  res.env = addEnv(params.defs ++ params.functionDefs, capturedEnv(top.env));
  res.controlStmtContext = initialControlStmtContext;

  local resType::Type = res.typerep.withoutTypeQualifiers;
  top.typerep = extType(nilQualifier(), closureType(params.typereps, ^resType));

  forwards to
    lambdaStmtExpr(
      @captured, ^params, typeName(resType.baseTypeExpr, resType.typeModifierExpr),
      -- Seemingly unavoidable re-decoration of res here, since the return type affects
      -- the environment that res will recieve.
      case res.typerep of
      | builtinType(_, voidType()) -> exprStmt(^res)
      | _ -> returnStmt(justExpr(^res))
      end);
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

abstract production lambdaStmtExpr
top::Expr ::= captured::CaptureList params::Parameters res::TypeName body::Stmt
{
  top.pp = pp"lambda [${captured.pp}](${ppImplode(text(", "), params.pps)}) -> ${res.pp} ${braces(nestlines(2, body.pp))}";
  attachNote extensionGenerated("ableC-closure");
  
  local localErrors::[Message] =
    (if captured.isEmpty then [] else checkMemcpyErrors(top.env) ++ allocErrors(top.env)) ++
    captured.errors ++ params.errors ++ res.errors ++ body.errors;
  
  local paramNames::[Name] =
    map(name, map(fst, foldr(append, [], map((.valueContribs), params.functionDefs))));
  captured.freeVariablesIn = removeAll(paramNames, nub(body.freeVariables));

  body.env = addEnv(params.functionDefs ++ body.functionDefs, openScopeEnv(addEnv(typeDecl.defs, capturedEnv(top.env))));
  captured.env =
    addEnv(globalDeclsDefs(params.globalDecls ++ body.globalDecls), top.env);
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

  local typeDecl::Decl = closureStructDecl(@params, @res);
  local transParams::Parameters = argTypesNamesToParameters(params.typereps, paramNames);
  local globalDecls::Decls =
    ableC_Decls {
      $Decl{@typeDecl}

      $Decl{
        if captured.isEmpty then decls(nilDecl()) else
        typeExprDecl(
          nilAttribute(),
          structTypeExpr(
            nilQualifier(),
            structDecl(
              nilAttribute(),
              justName(name(envStructName)),
              captured.envStructTrans)))}

      static $directTypeExpr{res.typerep} $name{funName}(void *_env_ptr, $Parameters{@transParams}) {
        $Stmt{
          if captured.isEmpty then nullStmt() else ableC_Stmt {
            struct $name{envStructName} _env = *(struct $name{envStructName}*)_env_ptr;
            $Stmt{captured.envCopyOutTrans}
          }
        }
        $Stmt{@body}
      }
    };
  
  local resExpr::Expr =
    ableC_Expr {
      ({$Stmt{
          if captured.isEmpty
          then ableC_Stmt { void *_env_ptr = 0; }
          else ableC_Stmt {
            struct $name{envStructName} _env = $Initializer{objectInitializer(captured.envInitTrans)};
            struct $name{envStructName} *_env_ptr = allocate(sizeof(struct $name{envStructName}));
            memcpy(_env_ptr, &_env, sizeof(struct $name{envStructName}));
          }
        }
        struct $name{closureTypeStructName} _result;
        _result.fn_name = $stringLiteralExpr{funName};
        _result.env = (void*)_env_ptr;
        _result.fn = $name{funName};

        ($directTypeExpr{extType(nilQualifier(), closureType(params.typereps, res.typerep))})_result;})
    };

  forward fwrd = injectGlobalDeclsExpr(@globalDecls, @resExpr);

  forwards to if null(localErrors) then @fwrd else errorExpr(localErrors);
}

fun checkMemcpyErrors [Message] ::= env::Env =
  if !null(lookupValue("memcpy", env)) then []
  else [errFromOrigin(ambientOrigin(), "Lambda requires definition of memcpy (include <string.h>?).")];

synthesized attribute envStructTrans::StructItemList;
synthesized attribute envInitTrans::InitList; -- Initializer body for _env using vars
synthesized attribute envCopyOutTrans::Stmt; -- Copys _env out to vars

inherited attribute structNameIn::String;
inherited attribute freeVariablesIn::[Name];
inherited attribute currentFunctionNameIn::String;

tracked nonterminal CaptureList with env, structNameIn, freeVariablesIn, currentFunctionNameIn, pp, isEmpty, errors, envStructTrans, envInitTrans, envCopyOutTrans;

propagate env, structNameIn, currentFunctionNameIn, isEmpty, errors on CaptureList;

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
  attachNote extensionGenerated("ableC-closure");
  
  top.errors <- n.valueLookupCheck;
  top.errors <-
    if n.valueItem.isItemValue
    then []
    else [errFromOrigin(n, "'" ++ n.name ++ "' does not refer to a value.")];
  top.errors <-
    if varType.isCompleteType(globalEnv(top.env)) then []
    else [errFromOrigin(n, "'" ++ n.name ++ "' does not have a globally-defined type.")];
  
  -- Strip qualifiers and convert arrays and functions to pointers
  production varType::Type =
    case n.valueItem.typerep of
    | arrayType(elem, _, _, _) -> pointerType(nilQualifier(), ^elem)
    | functionType(res, sub, q) ->
        pointerType(nilQualifier(), noncanonicalType(parenType(functionType(^res, ^sub, ^q))))
    | t -> t
    end;
  varType.inArrayType = false;
  
  -- If true, then this variable is in scope for the lifted function and doesn't need to be captured
  production isGlobal::Boolean =
    !null(lookupValue(n.name, top.env)) &&
    null(lookupValue(n.name, nonGlobalEnv(top.env)))
    -- The current top-level function still needs to be captured
    && n.name != top.currentFunctionNameIn;

  top.isEmpty <- isGlobal;
  
  top.envStructTrans =
    if isGlobal then rest.envStructTrans else
      consStructItem(
        structItem(
          nilAttribute(),
          directTypeExpr(varType.variableArrayConversion),
          consStructDeclarator(
            structField(^n, baseTypeExpr(), nilAttribute()),
            nilStructDeclarator())),
        rest.envStructTrans);
  
  top.envInitTrans =
    if isGlobal then rest.envInitTrans else
      consInit(
        positionalInit(exprInitializer(declRefExpr(^n))),
        rest.envInitTrans);
  
  top.envCopyOutTrans =
    if isGlobal then rest.envCopyOutTrans else
      ableC_Stmt {
        const $directTypeExpr{varType.defaultFunctionArrayLvalueConversion.withoutTypeQualifiers} $Name{^n} = _env.$Name{^n};
        $Stmt{rest.envCopyOutTrans}
      };
  
  rest.freeVariablesIn = remove(^n, top.freeVariablesIn);
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
  top.variableArrayConversion = ^top;
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
