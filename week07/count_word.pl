#!/usr/bin/perl
use strict;
use warnings;

use English;

require "total_words.pl";

sub getWordCounts {
    my ($input) = @ARG;

    my %result = ("_total" => 0);
    foreach my $word (findWords($input)) {
        $word = lc $word;
        if (!$result{$word}) {
            $result{$word} = 0;
        }

        ++$result{$word};
        ++$result{"_total"};
    }

    return %result;
}

if (!caller) {
    my $word = lc $ARGV[0];
    my %wordCounts = getWordCounts(\*STDIN);
    printf("%s occurred %d times\n", $word, $wordCounts{$word} || 0);
}

1;
