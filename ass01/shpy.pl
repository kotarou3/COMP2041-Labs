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
    my %variableTypes;
    my $isGlobbed = 0;

    my $globsToPythonList = sub {
        # Glob each element of $args depending on the flag in $globbedArgs
        # and return the result as a python list
        my @args = @{$ARG[0]};
        my @globbedArgs = @{$ARG[1]};

        my @result;
        while (scalar @args > 0) {
            if (!$globbedArgs[0]) {
                my @currentUnglobbedRun;
                while (scalar @args > 0 && !$globbedArgs[0]) {
                    push(@currentUnglobbedRun, shift(@args));
                    shift(@globbedArgs);
                }
                push(@result, "[" . join(", ", @currentUnglobbedRun) . "]");
            } else {
                $usedImports{"glob"} = 1;
                push(@result, "sorted(glob.glob(" . shift(@args) . "))");
                shift(@globbedArgs);
            }
        }

        return join(" + ", @result);
    };

    my ($doDefault, $doDefaultNext);
    my %action;
    %action = (
        "list" => sub {
            my ($list) = @ARG;
            my @result = &$doDefaultNext($list);

            # Remove semicolons if a comment immediately follows
            for (my $r = 0; $r < scalar @result - 1; ++$r) {
                if ($result[$r + 1] =~ /^#/) {
                    $result[$r] =~ s/; $/ /;
                }
            }

            return join("", @result);
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

                my @args = &$doDefault($simpleCommand->{"command"});
                my @globbedArgs = ($isGlobbed);
                my $isCommandGlobbed = $isGlobbed;

                if ($simpleCommand->{"args"}) {
                    foreach my $arg (@{$simpleCommand->{"args"}}) {
                        push(@args, &$doDefault($arg));
                        push(@globbedArgs, $isGlobbed);
                        $isCommandGlobbed = $isGlobbed || $isCommandGlobbed;
                    }
                }

                if ($args[0] eq "\"echo\"") {
                    shift @args;
                    shift @globbedArgs;
                    if (!$isCommandGlobbed) {
                        return scalar @args > 0 ? "print " . join(", ", @args) . "; " : "print; ";
                    } else {
                        return "print \" \".join(" . &$globsToPythonList(\@args, \@globbedArgs) . "); ";
                    }
                } else {
                    $usedBuiltins{"call"} = 1;
                    return "call(" . &$globsToPythonList(\@args, \@globbedArgs) . "); ";
                }
            } elsif ($simpleCommand->{"assignment"}) {
                # Variable assignment
                return join("; ", map {
                    my $value = $action{"word"}($_->{"value"}, 1);
                    if ($isGlobbed) {
                        # Globs are evaluated at command execution
                        $variableTypes{$_->{"var"}} = "glob";
                    } else {
                        $variableTypes{$_->{"var"}} = "string";
                    }

                    $_->{"var"} . " = " . $value;
                } @{$simpleCommand->{"assignment"}}) . "; ";
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
            my ($word, $ignoreGlobbing) = @ARG;
            $word = $word->{"children"};

            # Check if the word has any globs first
            # If globbing is ignored, check if the resulting word contains any globs
            $isGlobbed = 0;
            foreach my $part (@$word) {
                if (ref($part) eq "HASH") {
                    if ($part->{"type"} eq "variable") {
                        # If the variable has been "tainted" with a glob or is unknown, the entire word is globbed
                        if (!defined $variableTypes{$part->{"value"}} || $variableTypes{$part->{"value"}} eq "glob") {
                            $isGlobbed = 1;
                        }
                    } elsif ($part->{"type"} eq "word_squoted") {
                        # Globbing doesn't happen in quotes and escapes, unless we're ignoring globbing
                        if ($ignoreGlobbing) {
                            $part->{"value"} =~ /[]*?[]/ and $isGlobbed = 1;
                        }
                    } else {
                        die("Should never happen");
                    }
                } else {
                    $part =~ /[]*?[]/ and $isGlobbed = 1;
                }
            }

            # Build the format string
            my @variables;
            my $result = join("", map {
                if (ref($_) eq "HASH") {
                    if ($_->{"type"} eq "variable") {
                        push(@variables, $_->{"value"});
                        "{" . (scalar @variables - 1) . "}";
                    } elsif ($_->{"type"} eq "word_squoted") {
                        # Escape globs if necessary
                        if ($isGlobbed && !$ignoreGlobbing) {
                            $_->{"value"} =~ s/([]*?[])/[$1]/g;
                        }

                        $_->{"value"};
                    }
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
            $result =~ s/\n\n?/"\n\n" . join("\n", @builtins) . "\n"/e;
        } else {
            $result = join("\n", @builtins) . "\n$result";
        }
    }

    return $result;
}

sub postProcess {
    my ($result) = @ARG;

    # Remove trailing spaces and semicolons
    $result =~ s/[; ]+$//mg;

    # Remove double blank lines
    $result =~ s/\n{3,}/\n/g;

    # Remove all but one trailing newlines (or add it in if it doesn't exist)
    $result =~ s/\n+$//;
    $result .= "\n";

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
