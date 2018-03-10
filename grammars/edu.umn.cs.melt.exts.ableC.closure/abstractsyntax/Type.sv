grammar edu:umn:cs:melt:exts:ableC:closure:abstractsyntax;

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
  local structRefId::String = s"edu:umn:cs:melt:exts:ableC:closure:${structName}";
  local closureStructDecl::Decl = parseDecl(s"""
struct __attribute__((refId("${structRefId}"),
                      module("edu:umn:cs:melt:exts:ableC:closure:closure"))) ${structName} {
  const char *_fn_name; // For debugging
  void *_env; // Pointer to generated struct containing env
  __res_type__ (*_fn)(void *env, __params__); // First param is above env struct pointer
};
""");
  
  local localErrors::[Message] = params.errors ++ res.errors;
  local fwrd::BaseTypeExpr =
    injectGlobalDeclsTypeExpr(
      consDecl(
        maybeRefIdDecl(
          structRefId,
          substDecl(
            [parametersSubstitution("__params__", params),
             typedefSubstitution("__res_type__", typeModifierTypeExpr(res.bty, res.mty))],
            closureStructDecl)),
        nilDecl()),
      directTypeExpr(closureType(q, params.typereps, res.typerep)));
  
  forwards to if !null(localErrors) then errorTypeExpr(localErrors) else fwrd;
}

abstract production closureType
top::Type ::= q::Qualifiers params::[Type] res::Type
{
  propagate substituted;
  
  top.lpp = pp"${terminate(space(), q.pps)}closure<(${
    if null(params) then pp"void" else
      ppImplode(
        pp", ",
        zipWith(cat,
          map((.lpp), params),
          map((.rpp), params)))}) -> ${res.lpp}${res.rpp}>";
  top.rpp = notext();
  
  top.withTypeQualifiers =
    closureType(foldQualifier(top.addedTypeQualifiers ++ q.qualifiers), params, res);
  
  local structName::String = closureStructName(params, res);
  local structRefId::String = s"edu:umn:cs:melt:exts:ableC:closure:${structName}";
  
  forwards to tagType(q, refIdTagType(structSEU(), structName, structRefId));
}

function closureStructName
String ::= params::[Type] res::Type
{
  return s"_closure_${implode("_", map((.mangledName), params))}_${res.mangledName}_s";
}

-- Check if a type is a closure in a non-interfering way
function isClosureType
Boolean ::= t::Type
{
  return
    case t of
      tagType(_, refIdTagType(_, _, refId)) ->
        startsWith("edu:umn:cs:melt:exts:ableC:closure:", refId)
    | _ -> false
    end;
}

-- Find the parameter types of a closure type in a non-interfering way
function closureParamTypes
[Type] ::= t::Type env::Decorated Env
{
  local refId::String =
    case t of
      tagType(_, refIdTagType(_, _, refId)) -> refId
    | _ -> ""
    end;
  local refIds::[RefIdItem] = lookupRefId(refId, env);
  local valueItems::[ValueItem] = lookupValue("_fn", head(refIds).tagEnv);
  local fnPtrType::Type = head(valueItems).typerep;

  return
    case refIds, valueItems, fnPtrType of
      [], _, _ -> []
    | _, [], _ -> []
    | _, _, pointerType(_, functionType(_, protoFunctionType(params, _), _)) -> tail(params)
    | _, _, _ -> []
    end;
}

-- Find the result type of a closure type in a non-interfering way
function closureResultType
Type ::= t::Type env::Decorated Env
{
  local refId::String =
    case t of
      tagType(_, refIdTagType(_, _, refId)) -> refId
    | _ -> ""
    end;
  local refIds::[RefIdItem] = lookupRefId(refId, env);
  local valueItems::[ValueItem] = lookupValue("_fn", head(refIds).tagEnv);
  local fnPtrType::Type = head(valueItems).typerep;

  return
    case refIds, valueItems, fnPtrType of
      [], _, _ -> errorType()
    | _, [], _ -> errorType()
    | _, _, pointerType(_, functionType(res, _, _)) -> res
    | _, _, _ -> errorType()
    end;
}
