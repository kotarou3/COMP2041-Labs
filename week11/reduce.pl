#!/usr/bin/perl

use strict;
use warnings;

use English;

sub reduce(&@) {
    my $expr = \&{shift @ARG};

    my $result = shift @ARG;
    while (scalar @ARG > 0) {
        our $a = $result;
        our $b = shift @ARG;
        $result = $expr->();
    }

    return $result;
}

my $sum = reduce { $a + $b } 1 .. 10;
my $min = reduce { $a < $b ? $a : $b } 5..10;
my $maxstr = reduce { $a gt $b ? $a : $b } 'aa'..'ee';
my $concat = reduce { $a . $b } 'J'..'P';
my $sep = '-';
my $join = reduce { "$a$sep$b" }  'A'..'E';
print "$sum $min $maxstr $concat $join\n";
