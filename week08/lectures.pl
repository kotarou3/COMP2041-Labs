#!/usr/bin/perl

use strict;
use warnings;

use English;
use LWP::Simple;
use HTML::TreeBuilder;
use XML::LibXML;

my $outputType = "human";
if ($ARGV[0]) {
    if ($ARGV[0] eq "-d") {
        $outputType = "machine";
        shift @ARGV;
    } elsif ($ARGV[0] eq "-t") {
        $outputType = "table";
        shift @ARGV;
    }
}

my %resultTable;

foreach my $course (@ARGV) {
    # "Clean" the HTML into XML, and ignore any non-ascii characters
    my $html = get("http://www.timetable.unsw.edu.au/current/$course.html");
    my $xml = HTML::TreeBuilder->new_from_content($html)->as_XML();
    $xml =~ s/[\x7f-\xff]+//g;
    my $document = XML::LibXML->load_xml(string => $xml);

    my @timeNodes = $document->find("//a[text() = 'Lecture']/../../td[last()]/text()")->get_nodelist();
    my %duplicateTimes;
    foreach my $timeNode (@timeNodes) {
        (my $time = $timeNode->textContent) =~ s/^\s+|\s+$//;

        my $linkNode = ($timeNode->find("../../../..//a[starts-with(text(), 'Go to Class Detail records')]")->get_nodelist())[0];
        my $period = substr($linkNode->attributes()->getNamedItem("href")->textContent, 1);

        if ($duplicateTimes{$period}{$time}) {
            next;
        }
        $duplicateTimes{$period}{$time} = 1;

        if ($outputType eq "human") {
            print "$course: $period $time\n";
            next;
        }

        while ($time =~ /\b(Mon|Tue|Wed|Thu|Fri) (\d+):\d+ - (\d+):(\d+)\b/g) {
            my $day = $1;
            my $startTime = int $2;
            my $endTime = (int $3) + (int $4 == 0 ? 0 : 1);

            for (; $startTime < $endTime; ++$startTime) {
                if ($outputType eq "machine") {
                    print "$period $course $day $startTime\n";
                } elsif ($outputType eq "table") {
                    if (!$resultTable{$period}{$startTime}{$day}) {
                        $resultTable{$period}{$startTime}{$day} = 0;
                    }
                    ++$resultTable{$period}{$startTime}{$day};
                }
            }
        }
    }
}

if ($outputType eq "table") {
    foreach my $period (("S1", "S2", "X1")) {
        if (!$resultTable{$period}) {
            next;
        }

        print "$period       Mon   Tue   Wed   Thu   Fri\n";
        for (my $time = 9; $time <= 20; ++$time) {
            my $resultRow = $resultTable{$period}{$time};
            my $output = sprintf("%02d:00     %s     %s     %s     %s     %s",
                $time,
                $resultRow->{"Mon"} || " ",
                $resultRow->{"Tue"} || " ",
                $resultRow->{"Wed"} || " ",
                $resultRow->{"Thu"} || " ",
                $resultRow->{"Fri"} || " "
            );
            $output =~ s/\s+$//;
            print $output, "\n";
        }
    }
}
