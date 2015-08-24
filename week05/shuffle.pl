#!/usr/bin/perl
use strict;
use warnings;

# Fisher-Yates shuffle

my @result;
while (my $line = <STDIN>) {
    my $position = int(rand(scalar @result + 1));
    if ($position == scalar @result) {
        push @result, $line;
    } else {
        push @result, $result[$position];
        $result[$position] = $line;
    }
}

print join("", @result);
