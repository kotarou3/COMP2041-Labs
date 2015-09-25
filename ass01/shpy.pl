#!/usr/bin/perl
use v5.10;
use strict;
use warnings;

use English;

# Recompile parser if it's out of date
if ((-M "ShPyParser.pm" || "inf") > -M "ShPyParser.yp") {
    system("yapp ShPyParser.yp");
}
require ShPyParser;
ShPyParser->import();

sub convert {
    my ($rootNode) = @ARG;

    my (%usedImports, %usedBuiltins);

    my ($doDefault, $doDefaultNext);
    my %action = (
        "list" => sub {
            my ($list) = @ARG;
            return join("", &$doDefaultNext($list));
        },

        "newline_list" => sub {
            my ($newlineList) = @ARG;
            return join("", @{$newlineList->{"children"}});
        },

        "and_or" => sub {
            my ($andOr) = @ARG;
            if (scalar @{$andOr->{"children"}} > 1) {
                print(STDERR "Warning: && and || are currently unsupported\n");
            }
            return &$doDefault($andOr->{"children"}[0]);
        },

        "not" => sub {
            my ($not) = @ARG;
            print(STDERR "Warning: ! is currently unsupported\n");
            return &$doDefaultNext($not);
        },

        "pipe_sequence" => sub {
            my ($pipeSequence) = @ARG;
            if (scalar @{$pipeSequence->{"children"}} > 1) {
                print(STDERR "Warning: Pipes are currently unsupported\n");
            }
            return &$doDefault($pipeSequence->{"children"}[0]);
        },

        "simple_command" => sub {
            my ($simpleCommand) = @ARG;
            $simpleCommand = $simpleCommand->{"value"};

            if ($simpleCommand->{"command"}) {
                if ($simpleCommand->{"assignment"}) {
                    print(STDERR "Warning: Environment assignment currently unsupported\n");
                }

                my @args = (&$doDefault($simpleCommand->{"command"}));
                if ($simpleCommand->{"args"}) {
                    push(@args, map {&$doDefault($_);} @{$simpleCommand->{"args"}});
                }

                if ($args[0] eq "\"echo\"") {
                    return "print " . join(", ", @args[1 .. $#args]) . ";";
                } else {
                    $usedBuiltins{"call"} = 1;
                    return "call([" . join(", ", @args) . "]);";
                }
            } elsif ($simpleCommand->{"assignment"}) {
                # Variable assignment
                return join("; ", map {
                    $_->{"var"} . " = " . &$doDefault($_->{"value"});
                } @{$simpleCommand->{"assignment"}}) . ";";
            } else {
                # Only IO redirection
                print(STDERR "Warning: IO redirection currently unsupported\n");
                return "# simple_command io redirection";
            }
        },

        "compound_command" => sub {
            print(STDERR "Warning: Compound commands are currently unsupported\n");
            return "# compound_command";
        },

        "word" => sub {
            my ($word) = @ARG;
            $word = $word->{"children"};

            my @variables;
            my $result = join("", map {
                if (ref($_) eq "HASH") {
                    $_->{"type"} eq "variable" or die("Should never happen");
                    push(@variables, $_->{"value"});
                    "{" . (scalar @variables - 1) . "}";
                } else {
                    $_;
                }
            } @$word);

            # Add any necessary escapes and quote the string
            $result =~ /\P{ASCII}/ and die("FIXME: Unicode not supported");
            $result =~ s/(\p{PosixCntrl}|[\\"])/{
                "\\" => "\\\\",
                "\"" => "\\\"",
                "\a" => "\\a",
                "\b" => "\\b",
                "\f" => "\\f",
                "\n" => "\\n",
                "\r" => "\\r",
                "\t" => "\\t",
                "\x0b" => "\\v"
            }->{$1} || sprintf("\\x%02x", ord($1))/ge;
            $result = "\"$result\"";

            if (scalar @variables == 1 && scalar @$word == 1) {
                # Word consists of a single variable
                $result = $variables[0];
            } elsif (scalar @variables > 0) {
                $result .= ".format(" . join(", ", @variables) . ")";
            }

            return $result;
        }
    );

    $doDefault = sub {
        my ($node) = @ARG;
        ref($node) eq "HASH" or die("Should never happen");

        return $action{$node->{"type"}}($node);
    };

    $doDefaultNext = sub {
        my ($node) = @ARG;

        if (ref($node) eq "HASH") {
            if ($node->{"children"}) {
                return map {&$doDefault($_);} @{$node->{"children"}};
            } elsif ($node->{"value"}) {
                return &$doDefault($node->{"value"});
            }
        } elsif (ref($node) eq "ARRAY") {
            return map {&$doDefault($_);} @$node;
        }

        die("Should never happen");
    };

    # Convert shebang if it exists
    my $hasShebang = 0;
    if ($rootNode->{"children"}[0] &&
        $rootNode->{"children"}[0]->{"type"} eq "newline_list" &&
        $rootNode->{"children"}[0]->{"children"}[0] &&
        $rootNode->{"children"}[0]->{"children"}[0] =~ /^#!/) {
        $rootNode->{"children"}[0]->{"children"}[0] = "#!/usr/bin/python";
        $hasShebang = 1;
    }

    # Do main conversion
    my $result = &$doDefault($rootNode);

    # Generate builtins
    my @builtins = map {
        if ($_ eq "call") {
            $usedImports{"subprocess"} = 1;
            "def call(args):\n" .
            "    return not subprocess.call(args)\n";
        } else {
            die("Should never happen");
        }
    } keys %usedBuiltins;

    # Generate imports
    if (scalar keys %usedImports > 0) {
        unshift(@builtins, "import " . join(", ", keys %usedImports) . "\n");
    }

    # Add builtins/imports to result
    if (scalar @builtins > 0) {
        if ($hasShebang) {
            $result =~ s/\n/"\n\n" . join("\n", @builtins) . "\n"/e;
        } else {
            $result = join("\n", @builtins) . "\n$result";
        }
    }

    return $result;
}

sub postProcess {
    my ($result) = @ARG;

    # Remove trailing whitespace and semicolons
    $result =~ s/[; ]+$//mg;

    return $result;
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
        $result = convert($result);
        $result = postProcess($result);
        print($result);
    } else {
        print STDERR "$file failed\n";
    }
}
