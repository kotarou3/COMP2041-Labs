#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(param);

print "Content-Type: text/html\r\n";
print "\r\n";
print "<!DOCTYPE html>";
print "<title>A Guessing Game Player</title>";
print "<form method=\"POST\">";

if (defined param("correct")) {
    print "I win<br /><input type=\"submit\" value=\"Play again\" />";
} else {
    my $low = int(param("low") || 1);
    my $high = int(param("high") || 101);
    my $mid = int(($low + $high) / 2);

    if (defined param("higher")) {
        $low = $mid + 1;
    } elsif (defined param("lower")) {
        $high = $mid;
    }
    $mid = int(($low + $high) / 2);

    if ($low == $high) {
        print "Hacker<br /><input type=\"submit\" value=\"Play again\" />";
    } else {
        print "I guess $mid<br />";
        print "<input type=\"submit\" name=\"lower\" value=\"Lower\" />";
        print "<input type=\"submit\" name=\"correct\" value=\"Correct\" />";
        print "<input type=\"submit\" name=\"higher\" value=\"Higher\" />";
        print "<input type=\"hidden\" name=\"low\" value=\"$low\" />";
        print "<input type=\"hidden\" name=\"high\" value=\"$high\" />";
    }
}

print "</form>";
