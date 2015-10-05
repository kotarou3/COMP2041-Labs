#!/usr/bin/perl
use v5.10;
use strict;
use warnings;

use English;

use CGI qw(:all);

require "creditcard.pl";

print header, start_html("Credit Card Validation");
print "\n", h2("Credit Card Validation"), "\n";

if (param("close")) {
    print "Thank you for using the Credit Card Validator.\n";
} else {
    print "This page checks whether a potential credit card number satisfies the Luhn Formula.\n";
    print "<p>\n";

    print start_form(-method => "GET"), "\n";

    my $number = param("credit_card") || "";
    $number =~ s/\D//g;
    if (defined param("credit_card")) {
        my $result = validate($number);
        if ($result =~ /is valid$/) {
            print escapeHTML($result), "\n";
            print "<p>\n";
            print "Another card number:\n";
            $number = "";
        } else {
            print b(span({-style => "color: red"}, escapeHTML($result))), "\n";
            print "<p>\n";
            print "Try again:\n";
        }
    }

    print textfield(-name => "credit_card", -default => $number, -override => 1), "\n";
    print submit("submit", "Validate"), "\n";
    print reset("Reset"), "\n";
    print submit("close", "Close"), "\n";
    print end_form, "\n";
}

print end_html;
