#!/usr/bin/perl

use strict;
use warnings;

use English;
use LWP::Simple;
use HTML::TreeBuilder;
use XML::LibXML;

if (!$ARGV[0] || !($ARGV[0] =~ /[A-Z]{4}/)) {
    die "Usage: $PROGRAM_NAME <course code prefix>\n";
}

# "Clean" the HTML into XML, and ignore any non-ascii characters
my $html = get("http://www.timetable.unsw.edu.au/current/${ARGV[0]}KENS.html");
my $xml = HTML::TreeBuilder->new_from_content($html)->as_XML();
$xml =~ s/[\x7f-\xff]+//g;
my $document = XML::LibXML->load_xml(string => $xml);

my @nodes = $document->find("//td[\@class='data'][1]/a[starts-with(text(), '${ARGV[0]}')]")->get_nodelist();
foreach my $node (@nodes) {
    (my $textContent = $node->textContent) =~ s/^\s+|\s+$//;
    print "$textContent\n";
}
