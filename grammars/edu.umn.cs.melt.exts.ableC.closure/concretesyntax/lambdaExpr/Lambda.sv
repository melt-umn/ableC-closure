grammar edu:umn:cs:melt:exts:ableC:closure:concretesyntax:lambdaExpr;

imports edu:umn:cs:melt:ableC:concretesyntax;
imports silver:langutil;

imports edu:umn:cs:melt:ableC:abstractsyntax:host;
imports edu:umn:cs:melt:ableC:abstractsyntax:construction;
imports edu:umn:cs:melt:ableC:abstractsyntax:env;
--imports edu:umn:cs:melt:ableC:abstractsyntax:debug;

import edu:umn:cs:melt:exts:ableC:closure;

marking terminal Lambda_t 'lambda' lexer classes {Ckeyword};

terminal Allocate_t 'allocate';

concrete productions top::PostfixExpr_c
| 'lambda' allocator::MaybeAllocator_c captured::MaybeCaptureList_c '(' params::ParameterList_c ')' '->' '(' res::Expr_c ')'
    { top.ast = lambdaExpr(allocator.ast, captured.ast, foldParameterDecl(params.ast), res.ast, location=top.location); }
| 'lambda' allocator::MaybeAllocator_c captured::MaybeCaptureList_c '(' ')' '->' '(' res::Expr_c ')'
    { top.ast = lambdaExpr(allocator.ast, captured.ast, nilParameters(), res.ast, location=top.location); }
| 'lambda' allocator::MaybeAllocator_c captured::MaybeCaptureList_c '(' params::ParameterList_c ')' '->' '(' res::TypeName_c ')' '{' body::BlockItemList_c '}'
    { top.ast = lambdaStmtExpr(allocator.ast, captured.ast, foldParameterDecl(params.ast), res.ast, foldStmt(body.ast), location=top.location); }
| 'lambda' allocator::MaybeAllocator_c captured::MaybeCaptureList_c '(' ')' '->' '(' res::TypeName_c ')' '{' body::BlockItemList_c '}'
    { top.ast = lambdaStmtExpr(allocator.ast, captured.ast, nilParameters(), res.ast, foldStmt(body.ast), location=top.location); }
| 'lambda' allocator::MaybeAllocator_c captured::MaybeCaptureList_c '(' params::ParameterList_c ')' '->' '(' res::TypeName_c ')' '{' '}'
    { top.ast = lambdaStmtExpr(allocator.ast, captured.ast, foldParameterDecl(params.ast), res.ast, nullStmt(), location=top.location); }
| 'lambda' allocator::MaybeAllocator_c captured::MaybeCaptureList_c '(' ')' '->' '(' res::TypeName_c ')' '{' '}'
    { top.ast = lambdaStmtExpr(allocator.ast, captured.ast, nilParameters(), res.ast, nullStmt(), location=top.location); }

nonterminal MaybeAllocator_c with ast<MaybeExpr>, location;

concrete productions top::MaybeAllocator_c
| 'allocate' '(' e::Expr_c ')'
    { top.ast = justExpr(e.ast); }
| 
    { top.ast = nothingExpr(); }

nonterminal MaybeCaptureList_c with ast<MaybeCaptureList>;

concrete productions top::MaybeCaptureList_c
| '[' cl::CaptureList_c ']'
    { top.ast = justCaptureList(cl.ast); }
| 
    { top.ast = nothingCaptureList(); }

nonterminal CaptureList_c with ast<CaptureList>;

concrete productions top::CaptureList_c
| id::Identifier_t ',' rest::CaptureList_c
    { top.ast = consCaptureList(fromId(id), rest.ast); }
| id::Identifier_t
    { top.ast = consCaptureList(fromId(id), nilCaptureList()); }
|
    { top.ast = nilCaptureList(); }
