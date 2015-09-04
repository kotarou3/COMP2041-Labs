#!/usr/bin/perl
use strict;
use warnings;

use English;
use File::Spec;

require "count_word.pl";

sub wordCountsToFrequencies {
    my ($wordCounts, $isLog) = @ARG;

    my %result;
    foreach my $word (keys %$wordCounts) {
        if ($word eq "_total") {
            next;
        }

        my $count = $wordCounts->{$word};
        if ($isLog) {
            $result{$word} = log(($count + 1) / $wordCounts->{"_total"});
        } else {
            $result{$word} = $count / $wordCounts->{"_total"};
        }
    }

    if ($isLog) {
        $result{"_zero"} = -log($wordCounts->{"_total"});
    }

    return %result;
}

sub loadPoetFrequencies {
    my ($isLog, $debugWord) = @ARG;

    my %result;
    foreach my $file (glob "poets/*.txt") {
        open my $input, "<", $file;
        my %counts = getWordCounts($input);
        my %frequencies = wordCountsToFrequencies(\%counts, $isLog);
        my $poet = (File::Spec->splitpath($file))[2];
        $poet =~ s/\.txt$//;
        $poet =~ s/_/ /g;
        $result{$poet} = \%frequencies;

        if ($debugWord) {
            if ($isLog) {
                printf("log((%d+1)/%6d) = %8.4f %s\n", $counts{$debugWord} || 0, $counts{"_total"}, $frequencies{$debugWord} || $frequencies{"_zero"}, $poet);
            } else {
                printf("%4d/%6d = %.9f %s\n", $counts{$debugWord} || 0, $counts{"_total"}, $frequencies{$debugWord} || 0, $poet);
            }
        }
    }

    return %result;
}

if (!caller) {
    my $isLog = (File::Spec->splitpath($PROGRAM_NAME))[2] eq "log_probability.pl";
    my $word = lc $ARGV[0];
    loadPoetFrequencies($isLog, $word);
}

1;
