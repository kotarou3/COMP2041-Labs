#!/usr/bin/perl
use v5.10;
use strict;
use warnings;

use English;

use CGI qw(:all);

sub authenticateUser {
    my ($username, $password) = @ARG;

    local $/ = undef;
    if ($username =~ /\/|\x00/ || !open(my $passwordFile, "<", "accounts/$username/password")) {
        print "Unknown username!\n";
    } else {
        my $correctPassword = <$passwordFile>;
        $correctPassword =~ s/\n+$//;
        if ($password ne $correctPassword) {
            print "Incorrect password!\n";
        } else {
            print "$username authenticated.\n";
        }
    }
}

if (-t STDOUT) {
    print "username: ";
    my $username = <STDIN>;

    print "password: ";
    my $password = <STDIN>;

    chomp(($username, $password));
    authenticateUser($username, $password);
} else {
    print header, start_html("Login Page");

    my $username = param("username") || "";
    my $password = param("password") || "";

    if ($username && $password) {
        authenticateUser($username, $password);
    } else {
        print start_form, "\n\n";

        if ($username) {
            print hidden("username", $username), "\n";
        } else {
            print "Username:\n", textfield("username"), "\n";
        }

        if ($password) {
            print hidden("password", $password);
        } else {
            print "Password:\n", textfield("password"), "\n";
        }

        print submit(value => "Login"), "\n";
        print end_form;
    }

    print end_html;
}
