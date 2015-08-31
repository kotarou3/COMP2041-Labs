#!/usr/bin/perl
use strict;
use warnings;

my %whales;
while (my $line = <STDIN>) {
    $line = lc $line;
    $line =~ s/\s+/ /g;
    $line =~ s/^\s|\s$//;
    my @parts = split(" ", $line);
    if (scalar @parts < 2) {
        next;
    }

    my $number = int shift(@parts);
    my $type = join(" ", @parts);
    $type =~ s/s$//;

    if (!$whales{$type}) {
        $whales{$type}{"pods"} = 0;
        $whales{$type}{"individuals"} = 0;
    }

    ++$whales{$type}{"pods"};
    $whales{$type}{"individuals"} += $number;
}

if ($ARGV[0]) {
    print "$ARGV[0] observations: ";
    if ($whales{$ARGV[0]}) {
        print "${whales{$ARGV[0]}{'pods'}} pods, ${whales{$ARGV[0]}{'individuals'}} individuals\n";
    } else {
        print "0 pods, 0 individuals\n";
    }
} else {
    foreach my $type (sort keys %whales) {
        print "$type observations:  ${whales{$type}{'pods'}} pods, ${whales{$type}{'individuals'}} individuals\n";
    }
}
