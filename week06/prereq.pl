#!/usr/bin/perl

# Subset of https://github.com/kotarou3/UNSW-Course-Dependency-Viewer/blob/master/scraper.js

use strict;
use warnings;

use English;

sub fetchHandbookPages {
    use LWP::Simple;
    use constant courseTypes => ("undergraduate", "postgraduate", "research");

    my ($year, $course) = @ARG;

    return map {
        get("http://www.handbook.unsw.edu.au/$_/courses/$year/$course.html")
    } courseTypes;
}

sub parseHandbookPage {
    use HTML::TreeBuilder;
    use XML::LibXML;

    my %dataKeyMap = (
        "prerequisite" => "prerequisiteCourses",
        "prerequisites" => "prerequisiteCourses",
        "prerequisiite" => "prerequisiteCourses",
        "prerequsite" => "prerequisiteCourses",
        "prerequiste" => "prerequisiteCourses",
        "prerequistes" => "prerequisiteCourses",
        "prerequiistes" => "prerequisiteCourses",
        "parerequisite" => "prerequisiteCourses",
        "prerquisite" => "prerequisiteCourses",
        "prerequisitie" => "prerequisiteCourses",
        "prererquisite" => "prerequisiteCourses",
        "prequisite" => "prerequisiteCourses",
        "prereq" => "prerequisiteCourses",
        "pre" => "prerequisiteCourses",
        "required" => "prerequisiteCourses",

        "corequisite" => "prerequisiteCourses",
        "corequisites" => "prerequisiteCourses",
        "corequistes" => "prerequisiteCourses",
        "corequiste" => "prerequisiteCourses",
        "corerequisite" => "prerequisiteCourses",
        "co" => "prerequisiteCourses",
        "andcorequisite" => "prerequisiteCourses",
        "prerequisitecorequisite" => "prerequisiteCourses",
        "prerequisiteorcorequisite" => "prerequisiteCourses",
        "prerequisitesorcorequisites" => "prerequisiteCourses",
        "precorequisite" => "prerequisiteCourses",

        "equivalent" => "equivalentCourses"
    );

    my ($page, $results) = @ARG;

    # "Clean" the HTML into XML, and ignore any non-ascii characters
    my $xml = HTML::TreeBuilder->new_from_content($page)->as_XML();
    $xml =~ s/[\x7f-\xff]+//g;
    my $document = XML::LibXML->load_xml(string => $xml);

    my @nodes = $document->find(
        # Find the first common ancestor between the "Faculty" and "School" entries and return its children
        "//*[text() = 'Faculty:']" .
        "/ancestor::*[" .
            "count(. | //*[text() = 'School:']/ancestor::*) = count(//*[text() = 'School:']/ancestor::*)" .
        "]" .
        "[1]/*"
    )->get_nodelist;

    foreach my $node (@nodes) {
        (my $textContent = $node->string_value) =~ s/^\s+|\s+$//;
        my @parts = split(":", $textContent);
        my $key = lc(shift(@parts));
        $key =~ s/^\s+|\s+$//;
        $key =~ s/[^a-z]+//g;
        my $value = join(":", @parts);

        my $mappedKey = $dataKeyMap{$key};
        if (!$mappedKey) {
            next;
        }

        for my $course ($value =~ m/[a-zA-Z]{4}[0-9]{4}/g) {
            $results->{$mappedKey}{uc $course} = 1;
        }
    }
}

my $isRecursive = 0;
if ($ARGV[0] && $ARGV[0] eq "-r") {
    shift(@ARGV);
    $isRecursive = 1;
}

if (!$ARGV[0] || !($ARGV[0] =~ /[A-Z]{4}[0-9]{4}/)) {
    die "Usage: $PROGRAM_NAME <course code>\n";
}

my @pendingCourses = ($ARGV[0]);
my %parsedCourses;
while (scalar @pendingCourses > 0) {
    my $course = pop(@pendingCourses);
    if ($parsedCourses{$course}) {
        next;
    }

    my %results;
    foreach my $page (fetchHandbookPages(2015, $course)) {
        if ($page) {
            parseHandbookPage($page, \%results);
        }
    }

    if ($isRecursive) {
        for my $prereqType (keys %results) {
            push @pendingCourses, keys %{$results{$prereqType}};
        }
    }
    $parsedCourses{$course} = \%results;
}

my %allPrerequisiteCourses;
foreach my $course (keys %parsedCourses) {
    if ($course ne $ARGV[0] && $parsedCourses{$course}{"equivalentCourses"}) {
        for my $equivalentCourse (keys %{$parsedCourses{$course}{"equivalentCourses"}}) {
            $allPrerequisiteCourses{$equivalentCourse} = 1;
        }
    }

    if ($parsedCourses{$course}{"prerequisiteCourses"}) {
        for my $prerequisiteCourse (keys %{$parsedCourses{$course}{"prerequisiteCourses"}}) {
            $allPrerequisiteCourses{$prerequisiteCourse} = 1;
        }
    }
}

print join("\n", sort keys %allPrerequisiteCourses) . "\n";
