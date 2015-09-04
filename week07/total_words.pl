#!/usr/bin/perl
use strict;
use warnings;

use English;

sub findWords {
    my ($input) = @ARG;

    my @words;
    while (my $line = <$input>) {
        push @words, grep(/./, split(/[^a-zA-Z]/, $line));
    }

    return @words;
}

if (!caller) {
    printf "%d words\n", scalar findWords \*STDIN;
}

1;
