grammar edu:umn:cs:melt:exts:ableC:closure:concretesyntax:lambdaExpr;

imports edu:umn:cs:melt:ableC:concretesyntax;
imports silver:langutil;

imports edu:umn:cs:melt:ableC:abstractsyntax:host;
imports edu:umn:cs:melt:ableC:abstractsyntax:construction;
imports edu:umn:cs:melt:ableC:abstractsyntax:env;
--imports edu:umn:cs:melt:ableC:abstractsyntax:debug;

import edu:umn:cs:melt:exts:ableC:closure;

marking terminal Lambda_t 'lambda' lexer classes {Ckeyword};

concrete productions top::PostfixExpr_c
| 'lambda' body::Lambda_c
    { top.ast = body.ast; }

nonterminal Lambda_c with ast<Expr>, location;

concrete productions top::Lambda_c
| captured::MaybeCaptureList_c '(' params::ParameterList_c ')'
  '->' '(' res::Expr_c ')'
    { top.ast = lambdaExpr(captured.ast, foldParameterDecl(params.ast), res.ast,
                  location=top.location); }
| captured::MaybeCaptureList_c '(' ')'
  '->' '(' res::Expr_c ')'
    { top.ast = lambdaExpr(captured.ast, nilParameters(), res.ast,
                  location=top.location); }

nonterminal MaybeCaptureList_c with ast<MaybeCaptureList>, location;

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
