#!/usr/bin/perl
use v5.10;
use strict;
use warnings;

use English;

sub luhn_checksum {
    my ($numbers) = @ARG;

    my $checksum = 0;
    for (my $n = -1; $n >= -(scalar @$numbers); --$n) {
        my $d = $numbers->[$n] * (1 + ($n + 1) % 2);
        if ($d > 9) {
            $d -= 9;
        }
        $checksum += $d;
    }

    return $checksum % 10;
}

sub validate {
    my ($number) = @ARG;

    $number =~ s/\D//g;
    my @numbers = map {int($_);} split("", $number);
    if (length $number != 16) {
        return $ARG[0] . " is invalid  - does not contain exactly 16 digits";
    } elsif (luhn_checksum(\@numbers) == 0) {
        return $ARG[0] . " is valid";
    } else {
        return $ARG[0] . " is invalid";
    }
}

if (!caller) {
    foreach my $number (@ARGV) {
        print validate($number) . "\n";
    }
}

1;
