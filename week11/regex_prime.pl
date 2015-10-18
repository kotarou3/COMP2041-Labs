#!/usr/bin/perl

use strict;
use warnings;

my $regex = qr/^(?:.|(..+)\1+)$/;
foreach my $n (1..100) {
    my $unary = 1 x $n;
    print "$n = $unary unary - ";
    if ($unary =~ $regex) {
        print "composite\n"
    } else {
        print "prime\n";
    }
}
