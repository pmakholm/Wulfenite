#!/usr/bin/env nqp-p

use NQPHLL;

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

    method term:sym<closure>($/) {
        $*CUR_BLOCK.name(~$<ident>);
        $*CUR_BLOCK.push(
            QAST::Op.new(
                :op('lexotic'), :name<RETURN>,
                $<statementlist>.ast
            )
        );

        make QAST::Op.new( :op('takeclosure'), $*CUR_BLOCK );
    }

    method term:sym<apply>($/) { 
        my $call := QAST::Op.new( :op('call'), $<closure>.ast );
        for $<EXPR> {
            $call.push($_.ast);
        }

        make $call;
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
