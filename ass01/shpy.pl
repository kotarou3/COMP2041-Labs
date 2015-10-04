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

my $isPipelinesEnabled = 0;
if ($ARGV[0] && $ARGV[0] eq "-pipeline") {
    $isPipelinesEnabled = 1;
    shift(@ARGV);
}

sub convert {
    my ($rootNode, $parentShell) = @ARG;

    my ($usedImports, $usedBuiltins) = ({}, {});
    my (%variableTypes, %unknownVars);
    my %subshells;
    my $isGlobbed = 0;

    if ($parentShell) {
        $usedImports = $parentShell->{"usedImports"};
        $usedBuiltins = $parentShell->{"usedBuiltins"};
        %variableTypes = %{$parentShell->{"variableTypes"}}
    }

    # XXX: Assume command arguments don't need to be globbed
    for (my $n = 0; $n < 10; ++$n) {
        $variableTypes{"sys.argv[$n]"} = "string";
    }
    $variableTypes{"\" \".join(sys.argv[1:])"} = "string";
    $variableTypes{"len(sys.argv[1:])"} = "string";

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
                $usedImports->{"glob"} = 1;
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

            # If the return value is needed, mark the last and_or for return value capture
            if ($list->{"captureReturn"}) {
                for (my $c = scalar @{$list->{"children"}}; $c > 0; --$c) {
                    if ($list->{"children"}[$c - 1]->{"type"} eq "and_or") {
                        $list->{"children"}[$c - 1]->{"captureReturn"} = 1;
                        last;
                    }
                }
            }

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

            # Mark all child pipe_sequences except the last for return value capture, unless the parent needs it
            for (my $c = 0; $c < scalar @{$andOr->{"children"}} - 1 + ($andOr->{"captureReturn"} || 0); ++$c) {
                if (!ref($andOr->{"children"}[$c]) || $andOr->{"children"}[$c]->{"type"} eq "newline_list") {
                    next;
                }

                $andOr->{"children"}[$c]->{"captureReturn"} = 1;
            }

            if (scalar @{$andOr->{"children"}} == 1) {
                return &$doDefault($andOr->{"children"}[0]);
            }

            # Hoist comments to the front, since python doesn't support multiline conditionals
            my @newlineList;

            my $lastCondition;
            my $result = "";
            foreach my $child (@{$andOr->{"children"}}) {
                if (!ref($child)) {
                    if ($child eq "&&") {
                        # Python has different operator precedence
                        if ($lastCondition && $lastCondition eq "||") {
                            $result =~ s/\s+$//;
                            $result = "($result) ";
                        }

                        $result .= "and ";
                    } else {
                        $result .= "or ";
                    }
                    $lastCondition = $child;
                } elsif ($child->{"type"} eq "newline_list") {
                    push(@newlineList, @{$child->{"children"}});
                } else {
                    my $subshell = convert($child, {
                        "usedImports" => $usedImports,
                        "usedBuiltins" => $usedBuiltins,
                        "variableTypes" => \%variableTypes,
                        "unknownVars" => \%unknownVars
                    });
                    $subshell =~ s/;\s+$//;

                    # If the command is simple enough, we don't need to use a full function
                    if (scalar @{$andOr->{"children"}} == 1 || !($subshell =~ /[\n;]/) && $subshell =~ s/^return //) {
                        $result .= "$subshell ";
                        next;
                    }

                    if (!$subshells{$subshell}) {
                        $subshells{$subshell} = "subshell" . scalar keys %subshells;
                    }
                    $result .= $subshells{$subshell} . "() ";
                }
            }
            $result =~ s/\s*$/; /;

            my $comments = join("", @newlineList);
            $comments =~ s/^\s+//;
            $comments =~ s/\s+$/\n/;
            $comments =~ s/\n\n+/\n/g;

            return "$comments$result";
        },

        "not" => sub {
            my ($not) = @ARG;
            $not->{"captureReturn"} = $not->{"value"}->{"captureReturn"};

            print(STDERR "Warning: ! is currently unsupported\n");
            return &$doDefaultNext($not);
        },

        "pipe_sequence" => sub {
            my ($pipeSequence) = @ARG;

            # Only the return value of the last command is important
            $pipeSequence->{"children"}[-1]->{"captureReturn"} = $pipeSequence->{"captureReturn"};

            if (!$isPipelinesEnabled && scalar @{$pipeSequence->{"children"}} > 1) {
                print(STDERR "Warning: Pipes are not enabled. Enable with the -pipeline option\n");
                $pipeSequence->{"children"} = [$pipeSequence->{"children"}[-1]];
            }
            if (scalar @{$pipeSequence->{"children"}} == 1) {
                return &$doDefault($pipeSequence->{"children"}[0]);
            }

            # Hoist comments to the front, since python doesn't support multiline expressions
            my @newlineList;

            my @pipeline;
            foreach my $child (@{$pipeSequence->{"children"}}) {
                if ($child->{"type"} eq "newline_list") {
                    push(@newlineList, @{$child->{"children"}});
                } else {
                    my $subshell = convert($child, {
                        "usedImports" => $usedImports,
                        "usedBuiltins" => $usedBuiltins,
                        "variableTypes" => \%variableTypes,
                        "unknownVars" => \%unknownVars
                    });
                    $subshell =~ s/;\s+$//;

                    if (!$subshells{$subshell}) {
                        $subshells{$subshell} = "subshell" . scalar keys %subshells;
                    }
                    push (@pipeline, $subshells{$subshell});
                }
            }

            $usedBuiltins->{"pipeline"} = 1;
            my $result = "pipeline(" . join(", ", @pipeline) . "); ";
            if ($pipeSequence->{"captureReturn"}) {
                $result = "return $result";
            }

            my $comments = join("", @newlineList);
            $comments =~ s/^\s+//;
            $comments =~ s/\s+$/\n/;
            $comments =~ s/\n\n+/\n/g;

            return "$comments$result";
        },

        "simple_command" => sub {
            my ($simpleCommand) = @ARG;
            my $isCapturingReturn = $simpleCommand->{"captureReturn"};
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
                if ($args[0] eq "\"cd\"") {
                    if (scalar @args == 2) {
                        $usedImports->{"os"} = 1;

                        my $result = $isCapturingReturn ? "return not " : ""; # os.chdir() throws on failure any way...
                        if (!$isCommandGlobbed) {
                            $result .= "os.chdir(" . $args[1] . "); ";
                        } else {
                            $usedImports->{"glob"} = 1;
                            $result .= "os.chdir(sorted(glob.glob(" . $args[1] . "))[0]); ";
                        }
                        return $result;
                    } else {
                        print(STDERR "Warning: `cd` builtin used but could not be translated\n");
                    }
                } elsif ($args[0] eq "\"chmod\"" && scalar @args == 3 && $args[1] =~ /^\"([0-7]+)\"$/ && !$isCommandGlobbed) {
                    $usedImports->{"os"} = 1;
                    return ($isCapturingReturn ? "return not " : "") . "os.chmod(" . $args[2] . ", 0$1); ";
                } elsif ($args[0] eq "\"echo\"") {
                    shift @args;
                    shift @globbedArgs;

                    my $result;
                    if ($args[0] && $args[0] eq "\"-n\"") {
                        shift @args;
                        shift @globbedArgs;

                        $usedImports->{"sys"} = 1;
                        if (!$isCommandGlobbed && scalar @args <= 1) {
                            $result = "sys.stdout.write(" . ($args[0] || "\"\"") . "); ";
                        } else {
                            $result = "sys.stdout.write(\" \".join(" . &$globsToPythonList(\@args, \@globbedArgs) . ")); ";
                        }
                        if ($isCapturingReturn) {
                            $result = "return not $result";
                        }
                    } else {
                        if (!$isCommandGlobbed) {
                            $result = scalar @args > 0 ? "print " . join(", ", @args) . "; " : "print; ";
                        } else {
                            $result = "print \" \".join(" . &$globsToPythonList(\@args, \@globbedArgs) . "); ";
                        }
                        if ($isCapturingReturn) {
                            $result .= "\nreturn True; ";
                        }
                    }
                    return $result;
                } elsif ($args[0] eq "\"exit\"") {
                    if (scalar @args == 2 && !$isCommandGlobbed) {
                        $usedImports->{"sys"} = 1;
                        return "sys.exit(int(" . $args[1] . ")); ";
                    } else {
                        print(STDERR "Warning: `exit` builtin used but could not be translated\n");
                    }
                } elsif ($args[0] eq "\"expr\"" && !$isCommandGlobbed) {
                    my @argsCopy = @args; # Don't modify arguments if parser fails
                    shift @argsCopy;

                    my $exprParser = new ShPyExprParser;
                    $exprParser->YYData->{"ARGS"} = \@argsCopy;

                    my $result = $exprParser->YYParse(yylex => \&ShPyExprParser::Lexer, yyerror => sub {});
                    if ($exprParser->YYNberr() == 0) {
                        $result =~ /(?:[<=>]| and | or )/ and $result = "+($result)";
                        if ($isCapturingReturn) {
                            return "__tmp = str($result)\nprint __tmp\nreturn __tmp; ";
                        } else {
                            return "print str($result); ";
                        }
                    }
                } elsif ($args[0] eq "\"ls\"" && scalar @args <= 2  && !($args[1] && $args[1] =~ /^"-/) && !$isCommandGlobbed) {
                    $usedImports->{"os"} = 1;
                    my $result = "print \"\\n\".join(sorted(filter(lambda file: file[0] != \".\", os.listdir(" . ($args[1] || "\".\"") . ")))); ";
                    if ($isCapturingReturn) {
                        $result .= "\nreturn True; ";
                    }
                    return $result;
                }  elsif ($args[0] eq "\"mv\"" && !($args[1] && $args[1] =~ /^"-/)) {
                    shift @args;
                    shift @globbedArgs;

                    $usedBuiltins->{"mv"} = 1;
                    return ($isCapturingReturn ? "return not " : "") . "mv(" . &$globsToPythonList(\@args, \@globbedArgs) . "); ";
                } elsif ($args[0] eq "\"read\"") {
                    if (scalar @args == 1 || scalar @args == 2 && $args[1] =~ /"([a-z_][a-z0-9_]*)"/i) {
                        my $var;
                        if (scalar @args == 1) {
                            $var = "REPLY";
                        } else {
                            $var = $1;
                        }

                        $usedImports->{"sys"} = 1;
                        $variableTypes{$var} = "string"; # XXX: Assume user doesn't want any globbing
                        my $result = "$var = sys.stdin.readline().strip()";
                        if ($isCapturingReturn) {
                            print(STDERR "Warning: Python does not support variable assignment in conditional expressions. Output will be invalid\n");
                            return "return ($result); ";
                        } else {
                            return "$result; ";
                        }
                    } else {
                        print(STDERR "Warning: `read` builtin used but could not be translated\n");
                    }
                } elsif ($args[0] eq "\"rm\"" && $args[1] && ($args[1] eq "\"--\"" && $args[2] || !($args[1] =~ /^"-/))) {
                    shift @args;
                    shift @globbedArgs;
                    if ($args[0] eq "\"--\"") {
                        shift @args;
                        shift @globbedArgs;
                    }

                    $usedImports->{"os"} = 1;
                    my $result;
                    if (scalar @args > 1 || $isCommandGlobbed) {
                        $result = "[os.unlink(file) for file in " . &$globsToPythonList(\@args, \@globbedArgs) . "]; ";
                        if ($isCapturingReturn) {
                            $result = "return not not $result";
                        }
                    } else {
                        $result = "os.unlink(" . $args[0] . "); ";
                        if ($isCapturingReturn) {
                            $result = "return not $result";
                        }
                    }
                    return $result;
                } elsif (($args[0] eq "\"test\"" || $args[0] eq "\"[\"" && $args[-1] eq "\"]\"") && !$isCommandGlobbed) {
                    my @argsCopy = @args; # Don't modify arguments if parser fails
                    shift @argsCopy;

                    my $testParser = new ShPyTestParser;
                    $testParser->YYData->{"ARGS"} = \@argsCopy;

                    my $result = $testParser->YYParse(yylex => \&ShPyTestParser::Lexer, yyerror => sub {});
                    if ($testParser->YYNberr() == 0) {
                        foreach my $import (keys %{$testParser->YYData->{"usedImports"}}) {
                            $usedImports->{$import} = 1;
                        }
                        if ($isCapturingReturn) {
                            return "return $result; ";
                        } else {
                            return "$result; ";
                        }
                    }
                }

                # Fallback to normal subprocess call
                $usedImports->{"subprocess"} = 1;
                my $result = "subprocess.call(" . &$globsToPythonList(\@args, \@globbedArgs) . "); ";
                if ($isCapturingReturn) {
                    $result = "return not $result";
                }
                return $result;
            } elsif ($simpleCommand->{"assignment"}) {
                # Variable assignment
                my $result = join("; ", map {
                    my $value = $action{"word"}($_->{"value"}, 1);
                    if ($isGlobbed) {
                        # Globs are evaluated at command execution
                        $variableTypes{$_->{"var"}} = "glob";
                    } else {
                        $variableTypes{$_->{"var"}} = "string";
                    }

                    $_->{"var"} . " = " . $value;
                } @{$simpleCommand->{"assignment"}});

                if ($isCapturingReturn) {
                    print(STDERR "Warning: Python does not support variable assignment in conditional expressions. Output will be invalid\n");
                    return "return ($result); ";
                } else {
                    return "$result; ";
                }
            } else {
                # Only IO redirection
                print(STDERR "Warning: IO redirection currently unsupported\n");
                return "# simple_command io redirection";
            }
        },

        "compound_command" => sub {
            my ($compoundCommand) = @ARG;

            if ($compoundCommand->{"captureReturn"}) {
                print(STDERR "Warning: Capturing return value of compound commands is unsupported\n");
            }

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

                if ($in =~ /\(\)|callCapturingStdout\(/) {
                    # XXX: Hack to make for word split on command substitutions
                    $in .= ".split()";
                }
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
            my ($caseClause) = @ARG;
            $caseClause = $caseClause->{"value"};

            my $result = &$doDefault($caseClause->{"comments"});
            $result =~ s/^\s+//;
            if (length $result > 0 && !($result =~ /\n$/)) {
                $result .= "\n";
            }

            my $word = &$doDefault($caseClause->{"word"});

            if (!$caseClause->{"cases"}) {
                return "${result}if $word:\n    pass # Empty case clause\n";
            }

            for (my $c = 0; $c < scalar @{$caseClause->{"cases"}}; ++$c) {
                my $case = $caseClause->{"cases"}[$c];

                my @conditions;
                my $isDefaultMatch = 0;
                foreach my $pattern (@{$case->{"case"}}) {
                    my $match = &$doDefault($pattern);
                    if ($match eq "\"*\"") {
                        $isDefaultMatch = $c == scalar @{$caseClause->{"cases"}} - 1;
                        push(@conditions, "True");
                    } elsif ($match =~ /[]?*[]/) {
                        $usedImports->{"fnmatch"} = 1;
                        push(@conditions, "fnmatch.fnmatchcase($word, $match)");
                    } else {
                        push(@conditions, "$word == $match");
                    }
                }
                my $condition = join(" or ", @conditions);
                if ($c == 0) {
                    $condition = "if $condition:";
                } elsif ($isDefaultMatch) {
                    $condition = "else:";
                } else {
                    $condition = "elif $condition:";
                }

                my $action = $case->{"action"} ? &$doDefault($case->{"action"}) : "pass; ";
                $action =~ s/^/    /mg;

                my $comments = &$doDefault($case->{"comments"});
                if (!($comments =~ /\n$/)) {
                    $comments .= "\n";
                }

                $result .= "$condition\n$action$comments";
            }

            return $result;
        },

        "if_clause" => sub {
            my ($ifClause) = @ARG;
            $ifClause = $ifClause->{"value"};

            my $result = "";
            while (1) {
                $ifClause->{"condition"}->{"captureReturn"} = 1;
                my $condition = &$doDefault($ifClause->{"condition"});
                $condition =~ s/;\s+$//;
                $condition =~ s/^return //;
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

            $whileClause->{"condition"}->{"captureReturn"} = 1;
            my $condition = &$doDefault($whileClause->{"condition"});
            $condition =~ s/;\s+$//;
            $condition =~ s/^return //;
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

            # Check if the word has any globs or variables first
            # If globbing is ignored, check if the resulting word contains any globs
            $isGlobbed = 0;
            my $hasVariables = 0;
            foreach my $part (@$word) {
                if (ref($part) eq "HASH") {
                    if ($part->{"type"} eq "variable") {
                        $hasVariables = 1;

                        # Check for command arguments ($0..$9, $@, $*, $#)
                        if ($part->{"value"} =~ /^([0-9])$/) {
                            $usedImports->{"sys"} = 1;
                            $part->{"value"} = "sys.argv[$1]";
                        } elsif ($part->{"value"} =~ /^([@*])$/) {
                            $usedImports->{"sys"} = 1;
                            $part->{"value"} = "\" \".join(sys.argv[1:])";
                        } elsif ($part->{"value"} eq "#") {
                            $usedImports->{"sys"} = 1;
                            $part->{"value"} = "len(sys.argv[1:])";
                        }

                        # If the variable is unknown, mark it to pull from the environment
                        # XXX: Assume user doesn't want it globbed
                        if (!defined $variableTypes{$part->{"value"}}) {
                            $unknownVars{$part->{"value"}} = 1;
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
                    } elsif ($part->{"type"} eq "list") {
                        # XXX: Static checking is impossible here - assume user doesn't want to glob
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

                        # Escape braces if necessary
                        if ($hasVariables) {
                            $_->{"value"} =~ s/{/{{/g;
                            $_->{"value"} =~ s/}/}}/g;
                        }

                        $_->{"value"};
                    } elsif ($_->{"type"} eq "list") {
                        # Command substitution executes in a subshell, so we use a function for that
                        my $subshell = convert($_, {
                            "usedImports" => $usedImports,
                            "usedBuiltins" => $usedBuiltins,
                            "variableTypes" => \%variableTypes
                        });
                        $subshell =~ s/;\s+$//;

                        # If the command is simple enough, we don't need to use a full function
                        my $isSimpleSubshell = 0;
                        if (!($subshell =~ /[\n;]/)) {
                            if ($subshell =~ s/^print //) {
                                $subshell =~ /, / and $subshell = "\" \".join($subshell)";
                                push(@variables, $subshell);
                                $isSimpleSubshell = 1;
                            } elsif ($subshell =~ s/^subprocess\.call\(//) {
                                $usedBuiltins->{"callCapturingStdout"} = 1;
                                push(@variables, "callCapturingStdout($subshell");
                                $isSimpleSubshell = 1;
                            }
                        }
                        if (!$isSimpleSubshell) {
                            if (!$subshells{$subshell}) {
                                $subshells{$subshell} = "subshell" . scalar keys %subshells;
                            }
                            $usedBuiltins->{"captureStdout"} = 1;
                            push(@variables, "captureStdout(" . $subshells{$subshell} . ")");
                        }

                        "{" . (scalar @variables - 1) . "}";
                    }
                } else {
                    # Escape braces if necessary
                    if ($hasVariables) {
                        $_ =~ s/{/{{/g;
                        $_ =~ s/}/}}/g;
                    }

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
    if (!$parentShell &&
        $rootNode->{"children"}[0] &&
        $rootNode->{"children"}[0]->{"type"} eq "newline_list" &&
        $rootNode->{"children"}[0]->{"children"}[0] &&
        $rootNode->{"children"}[0]->{"children"}[0] =~ /^#!/) {
        $rootNode->{"children"}[0]->{"children"}[0] = "#!/usr/bin/python -u";
        $hasShebang = 1;
    }

    # Do main conversion
    my $result = &$doDefault($rootNode);

    my @header;

    # Generate builtins
    if (!$parentShell) {
        if ($usedBuiltins->{"pipeline"}) {
            $usedBuiltins->{"captureStdout"} = 1
        }
        push(@header, map {
            if ($_ eq "callCapturingStdout") {
                $usedImports->{"subprocess"} = 1;
                "def callCapturingStdout(args):\n" .
                "    try:\n" .
                "        return subprocess.check_output(args).strip()\n" .
                "    except subprocess.CalledProcessError as e:\n" .
                "        return e.output.strip()\n";
            } elsif ($_ eq "captureStdout") {
                $usedImports->{"fcntl"} = 1;
                $usedImports->{"os"} = 1;
                $usedImports->{"sys"} = 1;
                $usedImports->{"thread"} = 1;
                "def captureStdout(function, input = None):\n" .
                "    # Hackish way to do output capturing on arbritary subshells\n" .
                "\n" .
                "    # Set up new stdin if needed\n" .
                "    if input:\n" .
                "        oldStdin = os.dup(0)\n" .
                "        (newStdinR, newStdinW) = os.pipe()\n" .
                "        fcntl.fcntl(newStdinW, fcntl.F_SETFD, fcntl.FD_CLOEXEC)\n" .
                "        os.dup2(newStdinR, 0)\n" .
                "        sys.stdin = os.fdopen(newStdinR, \"r\")\n" .
                "\n" .
                "    # Set up new stdout\n" .
                "    oldStdout = os.dup(1)\n" .
                "    (newStdoutR, newStdoutW) = os.pipe()\n" .
                "    fcntl.fcntl(newStdoutR, fcntl.F_SETFD, fcntl.FD_CLOEXEC)\n" .
                "    os.dup2(newStdoutW, 1)\n" .
                "    sys.stdout = os.fdopen(newStdoutW, \"w\")\n" .
                "\n" .
                "    # Run subshell in separate thread to avoid a pipe deadlock\n" .
                "    def runSubshell():\n" .
                "        try:\n" .
                "            function()\n" .
                "        finally:\n" .
                "            # Restore stdin if needed\n" .
                "            if input:\n" .
                "                os.dup2(oldStdin, 0)\n" .
                "                sys.stdin = os.fdopen(oldStdin, \"r\")\n" .
                "\n" .
                "            # Restore stdout\n" .
                "            os.dup2(oldStdout, 1)\n" .
                "            sys.stdout = os.fdopen(oldStdout, \"w\")\n" .
                "\n" .
                "    thread.start_new_thread(runSubshell, ())\n" .
                "\n" .
                "    # Write to the new stdin if needed\n" .
                "    if input:\n" .
                "        os.write(newStdinW, input)\n" .
                "        os.close(newStdinW)\n" .
                "\n" .
                "    # Read from the new stdout\n" .
                "    result = \"\"\n" .
                "    while True:\n" .
                "        buffer = os.read(newStdoutR, 0x1000)\n" .
                "        result += buffer\n" .
                "        if len(buffer) == 0:\n" .
                "            break\n" .
                "\n" .
                "    os.close(newStdoutR)\n" .
                "    return result.strip()\n";
            } elsif ($_ eq "mv") {
                $usedImports->{"os"} = 1;
                $usedImports->{"errno"} = 1;
                "def mv(args):\n" .
                "    if len(args) > 2 or os.path.isdir(args[-1]):\n" .
                "        for src in args[0:-1]:\n" .
                "            os.rename(src, os.path.join(args[-1], src))\n" .
                "    else:\n" .
                "        os.rename(args[0], args[1])\n";
            } elsif ($_ eq "pipeline") {
                $usedImports->{"fcntl"} = 1;
                $usedImports->{"threading"} = 1;
                "def pipeline(*functions):\n" .
                "    output = captureStdout(functions[0])\n" .
                "    for function in functions[1:-1]:\n" .
                "        output = captureStdout(function, input = output)\n" .
                "\n" .
                "    # Set up new stdin\n" .
                "    oldStdin = os.dup(0)\n" .
                "    (newStdinR, newStdinW) = os.pipe()\n" .
                "    fcntl.fcntl(newStdinW, fcntl.F_SETFD, fcntl.FD_CLOEXEC)\n" .
                "    os.dup2(newStdinR, 0)\n" .
                "    sys.stdin = os.fdopen(newStdinR, \"r\")\n" .
                "\n" .
                "    # Run subshell in separate thread to avoid a pipe deadlock\n" .
                "    result = [False]\n" .
                "    def runSubshell():\n" .
                "        try:\n" .
                "            result[0] = functions[-1]()\n" .
                "        finally:\n" .
                "            # Restore stdin\n" .
                "            os.dup2(oldStdin, 0)\n" .
                "            sys.stdin = os.fdopen(oldStdin, \"r\")\n" .
                "\n" .
                "    t = threading.Thread(target = runSubshell)\n" .
                "    t.start()\n" .
                "\n" .
                "    # Write to the new stdin\n" .
                "    os.write(newStdinW, output)\n" .
                "    os.close(newStdinW)\n" .
                "\n" .
                "    # Wait for subshell to return\n" .
                "    t.join()\n" .
                "    return result[0]\n";
            } else {
                die("Should never happen");
            }
        } sort keys %$usedBuiltins);
    }

    # Generate subshell functions
    push(@header, sort map {
        my $body = $_;
        $body =~ /^\n/ or $body = "\n$body";
        $body =~ /\n$/ or $body = "$body\n";
        $body =~ s/^/    /gm;
        "\ndef " . $subshells{$_} . "():$body";
    } sort keys %subshells);

    # Pull in unknown variables used from the environment
    if (scalar keys %unknownVars > 0) {
        if (!$parentShell || !$parentShell->{"unknownVars"}) {
            $usedImports->{"os"} = 1;
            push(@header, map {"$_ = os.getenv(\"$_\", \"\")"} sort keys %unknownVars);
            push(@header, "\n");
        } else {
            foreach my $var (keys %unknownVars) {
                $parentShell->{"unknownVars"}->{$var} = 1;
            }
        }
    }
    if ($parentShell && $parentShell->{"unknownVars"}) {
        foreach my $var (keys %variableTypes) {
            $parentShell->{"variableTypes"}->{$var} = $variableTypes{$var};
        }
    }

    # Generate imports
    if (!$parentShell && scalar keys %$usedImports > 0) {
        unshift(@header, "import " . join(", ", sort keys %$usedImports) . "\n");
    }

    # Add builtins/imports to result
    if (scalar @header > 0) {
        if ($hasShebang) {
            $result =~ s/\n\n?/"\n\n" . join("\n", @header) . "\n"/e;
        } else {
            $result = join("\n", @header) . "\n$result";
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
    $result =~ s/\n{3,}/\n\n/g;

    # Remove all but one trailing newlines (or add it in if it doesn't exist)
    $result =~ s/\n+$//;
    $result .= "\n";

    return $result;
}

my $document = do {
    local $/ = undef;
    <STDIN>;
};

my $parser = new ShPyParser;
$parser->YYData->{"DATA"} = $document;

my $result = $parser->YYParse(yylex => \&ShPyParser::Lexer);
if ($parser->YYNberr() == 0) {
    $result = convert($result);
    $result = postProcess($result);
    print($result);
}
