#!/usr/bin/perl
use strict;
use warnings;

use English;

# Recompile parser if it's out of date
if ((-M "ShPyParser.pm" || "inf") > -M "ShPyParser.yp") {
    system("yapp ShPyParser.yp");
}
require ShPyParser;
ShPyParser->import();

sub dumpParsedSh {
    use YAML qw(Dump Bless);
    my ($dump) = @ARG;

    sub doBless {
        my ($node) = @ARG;

        if (ref($node) ne "HASH") {
            return;
        }

        Bless($node)->keys([grep {$node->{$_}} qw(type value children assignment command args)]);

        if ($node->{"value"}) {
            doBless($node->{"value"});
        } elsif ($node->{"children"}) {
            foreach my $child (@{$node->{"children"}}) {
                doBless($child);
            }
        }
    }

    doBless($dump);
    print Dump($dump);
}

foreach my $file (@ARGV) {
    my $document = do {
        local $/ = undef;
        open my $fh, "<", $file
            or die "could not open $file: $!";
        <$fh>;
    };

    my $parser = new ShPyParser;
    $parser->YYData->{"DATA"} = $document;

    my $result = $parser->YYParse(yylex => \&ShPyParser::Lexer);
    if ($parser->YYNberr() == 0) {
        print($document);
        dumpParsedSh($result);
    } else {
        print STDERR "$file failed\n";
    }
}
