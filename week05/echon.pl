#!/usr/bin/perl
use strict;
use warnings;

use English;

if (scalar @ARGV != 2) {
    die "Usage: $PROGRAM_NAME <number of lines> <string>\n";
}

print(($ARGV[1] . "\n") x $ARGV[0]);
