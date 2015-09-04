#!/usr/bin/perl
use strict;
use warnings;

use English;

require "total_words.pl";
require "frequency.pl";

my %frequencies = loadPoetFrequencies(1);

foreach my $file (@ARGV) {
    my %probabilities;
    foreach my $poet (keys %frequencies) {
        $probabilities{$poet} = 0;
    }

    open my $input, "<", $file;
    foreach my $word (findWords($input)) {
        $word = lc $word;
        foreach my $poet (keys %frequencies) {
            $probabilities{$poet} += $frequencies{$poet}{$word} || $frequencies{$poet}{"_zero"};
        }
    }

    my $result = (sort {$probabilities{$b} <=> $probabilities{$a}} keys %probabilities)[0];
    printf("%s most resembles the work of %s (log-probability=%.1f)\n", $file, $result, $probabilities{$result});
}
