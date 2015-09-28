#!/usr/bin/perl
use v5.10;
use strict;
use warnings;

use English;

# Recompile parsers if they're out of date
foreach my $parser ("ShPyParser", "ShPyTestParser", "ShPyExprParser") {
    if ((-M "$parser.pm" || "inf") > -M "$parser.yp") {
        system("yapp $parser.yp");
    }
}
require ShPyParser;
require ShPyTestParser;
require ShPyExprParser;
ShPyParser->import();
ShPyTestParser->import();
ShPyExprParser->import();

sub convert {
    my ($rootNode) = @ARG;

    my (%usedImports, %usedBuiltins, %usedEnvVars);
    my %variableTypes;
    my $isGlobbed = 0;

    # XXX: Assume command arguments don't need to be globbed
    for (my $n = 0; $n < 10; ++$n) {
        $variableTypes{"sys.argv[$n]"} = "string";
    }

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

        return join(" + ", @result) || "[]";
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

                # Check for builtins
                if ($args[0] eq "\"cd\"" && scalar @args == 2) {
                    $usedImports{"os"} = 1;
                    if (!$isCommandGlobbed) {
                        return "os.chdir(" . $args[1] . "); ";
                    } else {
                        $usedImports{"glob"} = 1;
                        return "os.chdir(sorted(glob.glob(" . $args[1] . "))[0]); ";
                    }
                } elsif ($args[0] eq "\"echo\"") {
                    shift @args;
                    shift @globbedArgs;
                    if (!$isCommandGlobbed) {
                        return scalar @args > 0 ? "print " . join(", ", @args) . "; " : "print; ";
                    } else {
                        return "print \" \".join(" . &$globsToPythonList(\@args, \@globbedArgs) . "); ";
                    }
                } elsif ($args[0] eq "\"exit\"" && scalar @args == 2 && !$isCommandGlobbed) {
                    $usedImports{"sys"} = 1;
                    return "sys.exit(int(" . $args[1] . ")); ";
                } elsif ($args[0] eq "\"expr\"" && !$isCommandGlobbed) {
                    my @argsCopy = @args; # Don't modify arguments if parser fails
                    shift @argsCopy;

                    my $exprParser = new ShPyExprParser;
                    $exprParser->YYData->{"ARGS"} = \@argsCopy;

                    my $result = $exprParser->YYParse(yylex => \&ShPyExprParser::Lexer, yyerror => sub {});
                    if ($exprParser->YYNberr() == 0) {
                        $result =~ /(?:[<=>]| and | or )/ and $result = "+($result)";
                        return "print $result; ";
                    }
                } elsif ($args[0] eq "\"read\"" && (scalar @args == 1 || scalar @args == 2 && $args[1] =~ /"([a-z_][a-z0-9_]*)"/i)) {
                    my $var;
                    if (scalar @args == 1) {
                        $var = "REPLY";
                    } else {
                        $var = $1;
                    }

                    $usedImports{"sys"} = 1;
                    $variableTypes{$var} = "string"; # XXX: Assume user doesn't want any globbing
                    return "$var = sys.stdin.readline().strip(); ";
                } elsif (($args[0] eq "\"test\"" || $args[0] eq "\"[\"" && $args[-1] eq "\"]\"") && !$isCommandGlobbed) {
                    my @argsCopy = @args; # Don't modify arguments if parser fails
                    shift @argsCopy;

                    my $testParser = new ShPyTestParser;
                    $testParser->YYData->{"ARGS"} = \@argsCopy;

                    my $result = $testParser->YYParse(yylex => \&ShPyTestParser::Lexer, yyerror => sub {});
                    if ($testParser->YYNberr() == 0) {
                        foreach my $import (keys %{$testParser->YYData->{"usedImports"}}) {
                            $usedImports{$import} = 1;
                        }
                        return $result . "; ";
                    }
                }

                # Fallback to normal subprocess call
                $usedBuiltins{"call"} = 1;
                return "call(" . &$globsToPythonList(\@args, \@globbedArgs) . "); ";
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
            my ($compoundCommand) = @ARG;
            return &$doDefaultNext($compoundCommand);
        },

        "for_clause" => sub {
            my ($forClause) = @ARG;
            $forClause = $forClause->{"value"};

            my $in = &$doDefault($forClause->{"in"});
            if (!$isGlobbed && $in ne "[]") {
                # Non-zero length lists don't need the the enclosing brackets for for loops
                $in =~ s/^\[//;
                $in =~ s/\]$//;
            }

            $variableTypes{$forClause->{"var"}} = "string"; # XXX: Assume user doesn't want any extra globbing

            my $action = &$doDefault($forClause->{"action"});

            my $comments = "";
            if ($forClause->{"comments"}) {
                $comments = &$doDefault($forClause->{"comments"});
            }

            if (!($comments =~ /\n/) && !($action =~ /^\n/)) {
                # Python needs a newline before the first action
                $comments .= "\n";
            } elsif ($comments =~ /\n$/ && $action =~ /^\n/) {
                # Get rid of blank line caused by the `do` removal
                $comments =~ s/\n$//;
            }

            $action =~ s/^/    /gm; # Add indentation
            return "for " . $forClause->{"var"} . " in $in:$comments$action";
        },

        "case_clause" => sub {
            print(STDERR "Warning: The case clause is currently unsupported\n");
            return "# case_clause";
        },

        "if_clause" => sub {
            my ($ifClause) = @ARG;
            $ifClause = $ifClause->{"value"};

            my $result = "";
            while (1) {
                my $condition = &$doDefault($ifClause->{"condition"});
                $condition =~ s/;\s+$//;
                if ($condition =~ /[&;\n]/) {
                    print(STDERR "Warning: Multi-statement conditions not supported. Output might be invalid\n");
                }

                my $then = &$doDefault($ifClause->{"then"});
                $then =~ /^\n/ or $then = "\n$then"; # Python needs a newline
                $then =~ s/^/    /gm; # Add indentation

                if (length $result == 0) {
                    $result = "if $condition:$then";
                } else {
                    $result =~ /\n$/ or $result .= "\n"; # Python needs a newline
                    $result .= "elif $condition:$then";
                }

                if ($ifClause->{"else"}) {
                    if (!$ifClause->{"else"}->{"condition"}) {
                        my $else = &$doDefault($ifClause->{"else"});
                        $else =~ /^\n/ or $else = "\n$else"; # Python needs a newline
                        $else =~ s/^/    /gm; # Add indentation

                        $result =~ /\n$/ or $result .= "\n"; # Python needs a newline
                        $result .= "else:$else";

                        last;
                    } else {
                        $ifClause = $ifClause->{"else"};
                        next;
                    }
                } else {
                    last;
                }
            }

            return $result;
        },

        "while_clause" => sub {
            my ($whileClause) = @ARG;
            $whileClause = $whileClause->{"value"};

            my $condition = &$doDefault($whileClause->{"condition"});
            $condition =~ s/;\s+$//;
            if ($condition =~ /[&;\n]/) {
                print(STDERR "Warning: Multi-statement conditions not supported. Output might be invalid\n");
            }

            my $then = &$doDefault($whileClause->{"then"});
            $then =~ /^\n/ or $then = "\n$then"; # Python needs a newline
            $then =~ s/^/    /gm; # Add indentation

            return "while $condition:$then";
        },

        "wordlist" => sub {
            my ($wordlist) = @ARG;
            $wordlist = $wordlist->{"children"};

            my @words;
            my @globbedWords;
            my $isAnyGlobbed = 0;
            foreach my $word (@$wordlist) {
                push(@words, &$doDefault($word));
                push(@globbedWords, $isGlobbed);
                $isAnyGlobbed = $isGlobbed || $isAnyGlobbed;
            }

            $isGlobbed = $isAnyGlobbed;
            return &$globsToPythonList(\@words, \@globbedWords);
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
                        # Check for command arguments ($0..$9)
                        if ($part->{"value"} =~ /^([0-9])$/) {
                            $usedImports{"sys"} = 1;
                            $part->{"value"} = "sys.argv[$1]";
                        }

                        # If the variable is unknown, mark it to pull from the environment
                        # XXX: Assume user doesn't want it globbed
                        if (!defined $variableTypes{$part->{"value"}}) {
                            $usedEnvVars{$part->{"value"}} = 1;
                            $variableTypes{$part->{"value"}} = "string";
                        }

                        # If the variable has been "tainted" with a glob, the entire word is globbed
                        if ($variableTypes{$part->{"value"}} eq "glob") {
                            $isGlobbed = 1;
                        }
                    } elsif ($part->{"type"} eq "word_squoted") {
                        # Globbing doesn't happen in quotes and escapes, unless we're ignoring globbing
                        if ($ignoreGlobbing) {
                            $part->{"value"} =~ /\[.[^]]*\]|[*?]/ and $isGlobbed = 1;
                        }
                    } else {
                        die("Should never happen");
                    }
                } else {
                    $part =~ /\[.[^]]*\]|[*?]/ and $isGlobbed = 1;
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
        $rootNode->{"children"}[0]->{"children"}[0] = "#!/usr/bin/python -u";
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

    # Pull in environment variables used
    if (scalar keys %usedEnvVars > 0) {
        $usedImports{"os"} = 1;
        push(@builtins, map {"$_ = os.getenv(\"$_\", \"\")"} keys %usedEnvVars);
        push(@builtins, "\n");
    }

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

    # Remove redundant int casting
    $result =~ s/[^a-zA-Z0-9_]\Kint\("([0-9]+)"\)/$1/g;

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
