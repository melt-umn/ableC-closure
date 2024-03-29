grammar edu:umn:cs:melt:exts:ableC:closure:concretesyntax:lambdaExpr;

imports edu:umn:cs:melt:ableC:concretesyntax;
imports silver:langutil;

imports edu:umn:cs:melt:ableC:abstractsyntax:host;
imports edu:umn:cs:melt:ableC:abstractsyntax:construction;
imports edu:umn:cs:melt:ableC:abstractsyntax:env;
--imports edu:umn:cs:melt:ableC:abstractsyntax:debug;

import edu:umn:cs:melt:exts:ableC:closure;

marking terminal Lambda_t 'lambda' lexer classes {Keyword, Global};

terminal Allocate_t 'allocate';

-- Productions on Expr_c here since we we want this to have the lowest possible precedence that can
-- still be used as a function argument
concrete productions top::AssignExpr_c
| 'lambda' allocator::MaybeAllocator_c captured::MaybeCaptureList_c '(' params::ParameterList_c ')' '->' DisallowSEUDecl_t res::AssignExpr_c AllowSEUDecl_t
    { top.ast = lambdaExpr(allocator.ast, captured.ast, foldParameterDecl(params.ast), res.ast); }
| 'lambda' allocator::MaybeAllocator_c captured::MaybeCaptureList_c '(' ')' '->' DisallowSEUDecl_t res::AssignExpr_c AllowSEUDecl_t
    { top.ast = lambdaExpr(allocator.ast, captured.ast, nilParameters(), res.ast); }
| 'lambda' allocator::MaybeAllocator_c captured::MaybeCaptureList_c '(' params::ParameterList_c ')' '->' DisallowSEUDecl_t res::TypeName_c AllowSEUDecl_t '{' body::BlockItemList_c '}'
    { top.ast = lambdaStmtExpr(allocator.ast, captured.ast, foldParameterDecl(params.ast), res.ast, foldStmt(body.ast)); }
| 'lambda' allocator::MaybeAllocator_c captured::MaybeCaptureList_c '(' ')' '->' DisallowSEUDecl_t res::TypeName_c AllowSEUDecl_t '{' body::BlockItemList_c '}'
    { top.ast = lambdaStmtExpr(allocator.ast, captured.ast, nilParameters(), res.ast, foldStmt(body.ast)); }
| 'lambda' allocator::MaybeAllocator_c captured::MaybeCaptureList_c '(' params::ParameterList_c ')' '->' DisallowSEUDecl_t res::TypeName_c AllowSEUDecl_t '{' '}'
    { top.ast = lambdaStmtExpr(allocator.ast, captured.ast, foldParameterDecl(params.ast), res.ast, nullStmt()); }
| 'lambda' allocator::MaybeAllocator_c captured::MaybeCaptureList_c '(' ')' '->' DisallowSEUDecl_t res::TypeName_c AllowSEUDecl_t '{' '}'
    { top.ast = lambdaStmtExpr(allocator.ast, captured.ast, nilParameters(), res.ast, nullStmt()); }

tracked nonterminal MaybeAllocator_c with ast<MaybeExpr>;

concrete productions top::MaybeAllocator_c
| 'allocate' '(' e::Expr_c ')'
    { top.ast = justExpr(e.ast); }
| 
    { top.ast = nothingExpr(); }

tracked nonterminal MaybeCaptureList_c with ast<CaptureList>;

concrete productions top::MaybeCaptureList_c
| '[' cl::CaptureList_c ']'
    { top.ast = cl.ast; }
| 
    { top.ast = freeVariablesCaptureList(); }

tracked nonterminal CaptureList_c with ast<CaptureList>;

concrete productions top::CaptureList_c
| id::Identifier_c ',' rest::CaptureList_c
    { top.ast = consCaptureList(id.ast, rest.ast); }
| id::Identifier_c
    { top.ast = consCaptureList(id.ast, nilCaptureList()); }
| '...'
    { top.ast = freeVariablesCaptureList(); }
|
    { top.ast = nilCaptureList(); }
