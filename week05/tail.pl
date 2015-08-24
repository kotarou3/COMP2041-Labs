#!/usr/bin/perl
use strict;
use warnings;

use English;

sub doTail {
    my ($handle, $length) = @ARG;

    if ($length == 0) {
        return;
    }

    my @buffer;
    while (my $line = <$handle>) {
        if (scalar @buffer == $length) {
            shift @buffer;
        }
        push @buffer, $line;
    }
    print join("", @buffer);
}

# Would use a CPAN module for this, but are we allowed to?
my $length = 10;
if ($ARGV[0] && $ARGV[0] =~ /-(\d+)/) {
    $length = int $1;
    shift @ARGV;
}
if ($ARGV[0] && $ARGV[0] eq "--") {
    shift @ARGV;
}

if (scalar @ARGV == 0) {
    doTail \*STDIN, $length;
} else {
    foreach my $file (@ARGV) {
        my $handle;
        if (!open $handle, "<", $file) {
            print STDERR "$PROGRAM_NAME: Can't open $file\n";
            next;
        }

        if (scalar @ARGV > 1) {
            print "==> $file <==\n";
        }

        doTail $handle, $length;

        close $handle;
    }
}
