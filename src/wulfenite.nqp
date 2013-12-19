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

class Wulfenite::Actions is HLL::Actions {
    method TOP($/) {
        $*CUR_BLOCK.push($<statementlist>.ast);

        make $*CUR_BLOCK;
    }

    method statementlist($/) {
        my $stmts := QAST::Stmts.new( :node($/) );
        for $<statement> {
            $stmts.push($_.ast)
        }
        make $stmts;
    }

    method block($/) {
        $*CUR_BLOCK.push($<statementlist>.ast);

        make $*CUR_BLOCK;
    }

    method statement:sym<EXPR>($/) { make $<EXPR>.ast; }

    method statement:sym<block>($/) {
        make $<block>.ast;
    }

    method statement:sym<my>($/) {
        my $name := ~$<varname>;
        my $var  := QAST::Var.new( :name($name), :scope('lexical'), :decl('var') );
        $*CUR_BLOCK.symbol($name, :declared(1) );
	
        make QAST::Op.new(
	    :op('bind'),
	    $var,
	    $<EXPR> ?? $<EXPR>.ast !! QAST::SVal.new(:value(""))
        );
    }

    method statement:sym<sub>($/) {
        $*CUR_BLOCK[0].push(QAST::Op.new(
            :op('bind'),
            QAST::Var.new( :name(~$<ident>), :scope('lexical'), :decl('var') ),
            $<subbody>.ast
        ));
        make QAST::Op.new( :op('null') );
    }

    method subbody($/) {
        $*CUR_BLOCK.name(~$<ident>);
        $*CUR_BLOCK.push(
            QAST::Op.new(
                :op('lexotic'), :name<RETURN>,
                $<statementlist>.ast
            )
        );
        
        make $*CUR_BLOCK;
    }
        
    method param($/) {
        $*CUR_BLOCK[0].push(QAST::Var.new(
            :name(~$<varname>), :scope('lexical'), :decl('param')
        ));
        $*CUR_BLOCK.symbol(~$<varname>, :declared(1));
    }

    method term:sym<return>($/) {
        make QAST::Op.new(
            :op('call'), :name('RETURN'),
            $<EXPR> ?? $<EXPR>.ast !! QAST::Op.new( :op('null') )
        );
    }

    method term:sym<call>($/) {
        my $name := ~$<ident>;

        my %builtins := nqp::hash(
            'say',   'concat',
            'print', 'concat',
            'die',   'single',
            'exit',  'single',
            'sleep', 'single',
        );

        my $call;
        if %builtins{$name} eq 'concat' {
            my $val := $<EXPR>.shift().ast;
            for $<EXPR> {
                $val := QAST::Op.new( :op('concat'), $val, $_.ast );
            }
            $call := QAST::Op.new( :op($name), $val );
        } elsif %builtins{$name} eq 'single' {
            my $val := $<EXPR>.shift().ast;
            $call := QAST::Op.new( :op($name), $val );
        } else {
            $call := QAST::Op.new( :op('call'), :name($name) );
            for $<EXPR> {
                $call.push($_.ast);
            }
        }

        make $call;
    }

    method statement:sym<if>($/) {
        make QAST::Op.new(
            :op('if'),
            $<EXPR>.ast,
            $<block>.ast
        );
    }

    method statement:sym<while>($/) {
        make QAST::Op.new(
            :op('while'),
            $<EXPR>.ast,
            $<block>.ast
        );
    }

    method term:sym<value>($/) { make $<value>.ast; }
    method term:sym<variable>($/) { 
        my $name := ~$<varname>;

        make QAST::Var.new( :name($name), :scope('lexical') );
    }

    method value:sym<string>($/) {
        make $<quote_EXPR>.ast;
    }
    method value:sym<integer>($/) {
        make QAST::IVal.new( :value(+$/.Str) )
    }
    method value:sym<float>($/) {
        make QAST::NVal.new( :value(+$/.Str) )
    }

    method circumfix:sym<( )>($/) { make $<EXPR>.ast }
}

class Wulfenite::Compiler is HLL::Compiler {
}

sub MAIN(*@ARGS) {
    my $comp := Wulfenite::Compiler.new();
    $comp.language('wulfenite');
    $comp.parsegrammar(Wulfenite::Grammar);
    $comp.parseactions(Wulfenite::Actions);
    $comp.command_line(@ARGS, :encoding('utf8'));
}


