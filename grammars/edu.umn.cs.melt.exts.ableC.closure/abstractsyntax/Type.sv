grammar edu:umn:cs:melt:exts:ableC:closure:abstractsyntax;

import edu:umn:cs:melt:ableC:abstractsyntax:overloadable;

{-
 - closureTypeExpr translates to a global struct declaration (if needed) and a reference to this
 - struct.  closureType, when transformed back into a BaseTypeExpr, is simply a reference to this
 - struct.  An invariant is that for any closureType that appears anywhere, a corresponding
 - closureTypeExpr must have existed somewhere that produced this type in the first place, and thus
 - provided the relevant struct definition.  Note that this closureTypeExpr may be part of the
 - forward for something, as in the case of lambdaExpr.
 -}

abstract production closureTypeExpr
top::BaseTypeExpr ::= q::Qualifiers params::Parameters res::TypeName
{
  propagate substituted;
  top.pp = pp"${terminate(space(), q.pps)}closure<(${
    if null(params.pps) then pp"void" else ppImplode(pp", ", params.pps)}) -> ${res.pp}>";
  
  res.env = addEnv(params.defs, top.env);
  
  local structName::String = closureStructName(params.typereps, res.typerep);
  local structRefId::String = closureStructRefId(params.typereps, res.typerep);
  
  local localErrors::[Message] = params.errors ++ res.errors;
  local fwrd::BaseTypeExpr =
    injectGlobalDeclsTypeExpr(
      consDecl(
        maybeRefIdDecl(
          structRefId,
          ableC_Decl {
            struct __attribute__((refId($stringLiteralExpr{structRefId}))) $name{structName} {
              const char *_fn_name; // For debugging
              void *_env; // Pointer to generated struct containing env
              // Implementation function pointer
              // First param is above env struct pointer
              // Remaining params are params of the closure
              $BaseTypeExpr{typeModifierTypeExpr(res.bty, res.mty)} (*_fn)(void *env, $Parameters{params});
            };
          }),
        nilDecl()),
      extTypeExpr(q, closureType(params.typereps, res.typerep)));
  
  forwards to if !null(localErrors) then errorTypeExpr(localErrors) else fwrd;
}

abstract production closureType
top::ExtType ::= params::[Type] res::Type
{
  propagate substituted;
  
  top.pp = pp"closure<(${
    if null(params) then pp"void" else
      ppImplode(
        pp", ",
        zipWith(cat,
          map((.lpp), params),
          map((.rpp), params)))}) -> ${res.lpp}${res.rpp}>";
  
  local structName::String = closureStructName(params, res);
  local structRefId::String = closureStructRefId(params, res);
  local isErrorType::Boolean =
    any(map(\ t::Type -> case t of errorType() -> true | _ -> false end, res :: params));
  
  top.host =
    if isErrorType
    then errorType()
    else tagType(top.givenQualifiers, refIdTagType(structSEU(), structName, structRefId));
  top.mangledName = s"_closure_${implode("_", map((.mangledName), params))}_${res.mangledName}";
  top.isEqualTo =
    \ other::ExtType ->
      case other of
        closureType(otherParams, otherRes) ->
          length(params) == length(otherParams) &&
          all(zipWith(compatibleTypes(_, _, false, false), res :: params, otherRes :: otherParams))
      | _ -> false
      end;
  
  top.callProd = just(applyExpr(_, _, location=_));
  top.callMemberProd = just(callMemberClosure(_, _, _, _, location=_));
}

function closureStructName
String ::= params::[Type] res::Type
{
  return closureType(params, res).mangledName ++ "_s";
}

function closureStructRefId
String ::= params::[Type] res::Type
{
  return s"edu:umn:cs:melt:exts:ableC:closure:${closureStructName(params, res)}";
}

-- Check if a type is a closure
function isClosureType
Boolean ::= t::Type
{
  return
    case t of
      extType(_, closureType(_, _)) -> true
    | _ -> false
    end;
}

-- Find the parameter types of a closure type
function closureParamTypes
[Type] ::= t::Type
{
  return
    case t of
      extType(_, closureType(paramTypes, _)) -> paramTypes
    | _ -> []
    end;
}

-- Find the result type of a closure type
function closureResultType
Type ::= t::Type
{
  return
    case t of
      extType(_, closureType(_, resType)) -> resType
    | _ -> errorType()
    end;
}
