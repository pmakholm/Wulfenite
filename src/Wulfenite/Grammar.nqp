#!/usr/bin/env nqp-p

use NQPHLL;

grammar Wulfenite::Grammar is HLL::Grammar {
    token TOP {
        :my $*CUR_BLOCK := QAST::Block.new(QAST::Stmts.new());
        :my $*IN_SUB    := 0;

        <statementlist>
        [ $ || <.panic('Syntax error')> ]
    }

    rule statementlist {
        [ <statement> ]*
    }

    rule block {
        :my $*CUR_BLOCK := QAST::Block.new(
            :blocktype('immediate'),
            QAST::Stmts.new()
        );

        '{' ~ '}' <statementlist>
    }

    token semicolon { [ ';' || $ ] }
 
    proto token statement {*}
    token statement:sym<EXPR> {
        <EXPR> <semicolon>
    }

    token statement:sym<my> {
        :s <sym> <varname> [ ':=' <EXPR> ]? <semicolon>
    }

    token param { <varname> }
    token statement:sym<sub> { :s
        :s <sym> <subbody>
    }

    rule subbody { 
        :my $*CUR_BLOCK   := QAST::Block.new(QAST::Stmts.new());
        :my $*IN_SUB      := 1;

        :s <ident> 
            '(' ~ ')' [ <param>* % [ ',' ] ] 
            '{' ~ '}' <statementlist>
    } 

    token statement:sym<block> { 
        <block>
    }

    token statement:sym<if> {
        :s <sym> <EXPR> <block>
    }

    token statement:sym<while> {
        :s <sym> <EXPR> <block>
    }

    # Simple expressions
    INIT {
        Wulfenite::Grammar.O(':prec<w=>, :assoc<left>',  '%exponentiation');
        Wulfenite::Grammar.O(':prec<v=>, :assoc<unary>', '%symbolic_unary');
        Wulfenite::Grammar.O(':prec<u=>, :assoc<left>',  '%multiplicative');
        Wulfenite::Grammar.O(':prec<t=>, :assoc<left>',  '%additive');
        Wulfenite::Grammar.O(':prec<r=>, :assoc<left>',  '%concatenation');
        Wulfenite::Grammar.O(':prec<j=>, :assoc<right>', '%conditional');
        Wulfenite::Grammar.O(':prec<i=>, :assoc<right>', '%assignment');
    }
    token prefix:sym<+>   { <sym>  <O('%symbolic_unary, :op<numify>')> }
    token prefix:sym<~>   { <sym>  <O('%symbolic_unary, :op<stringify>')> }

    token infix:sym<**>   { <sym>  <O('%exponentiation, :op<pow_n>')> }
    token infix:sym<*>    { <sym>  <O('%multiplicative, :op<mul_n>')> }
    token infix:sym<%>    { <sym>  <O('%multiplicative, :op<mod_n>')> }
    token infix:sym<+>    { <sym>  <O('%additive, :op<add_n>')> }
    token infix:sym<->    { <sym>  <O('%additive, :op<sub_n>')> }

    token infix:sym<~>    { <sym>  <O('%concatenation , :op<concat>')> }
    token infix:sym<:=>   { <sym> <O('%assignment, :op<bind>')> }

    token infix:sym«==»   { <sym>  <O('%relational, :op<iseq_n>')> }
    token infix:sym«!=»   { <sym>  <O('%relational, :op<isne_n>')> }
    token infix:sym«<=»   { <sym>  <O('%relational, :op<isle_n>')> }
    token infix:sym«>=»   { <sym>  <O('%relational, :op<isge_n>')> }
    token infix:sym«<»    { <sym>  <O('%relational, :op<islt_n>')> }
    token infix:sym«>»    { <sym>  <O('%relational, :op<isgt_n>')> }

    token circumfix:sym<( )> { :s '(' ~ ')' <EXPR> }

    # Simple values
    token term:sym<value>    { <value> }
    token term:sym<variable> { <varname> }

    token term:sym<return>   { :s <?{$*IN_SUB}> <sym> <EXPR>? }
    token term:sym<call>     { 
        :s <ident> [
            [ <EXPR>* % ',' ] | [ '(' ~ ')' [ <EXPR>* % ',' ]]
        ]
    }

    proto token value {*}
    token value:sym<string> { <?["]> <quote_EXPR: ':q', ':b'> }
    token value:sym<integer> { '-'? \d+ }

    # Names et al
    token keyword { [ if | my | return | sub | while ] <!ww> }
    token varname { '$' <[A..Za..z_]> <[A..Za..z0..9_]>* }
    token ident   { 
        [ <keyword> <.panic("keyword used as identifier")> ]?
        <[A..Za..z_]> <[A..Za..z0..9_]>* }
}
