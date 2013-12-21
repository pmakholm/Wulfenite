#!/usr/bin/env nqp-p

use Wulfenite::Grammar;
use Wulfenite::Actions;
use Wulfenite::Compiler;

sub MAIN(*@ARGS) {
    my $comp := Wulfenite::Compiler.new();
    $comp.language('wulfenite');
    $comp.parsegrammar(Wulfenite::Grammar);
    $comp.parseactions(Wulfenite::Actions);
    $comp.command_line(@ARGS, :encoding('utf8'));
}

