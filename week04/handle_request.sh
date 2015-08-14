#!/bin/bash

DOCUMENT_ROOT="$HOME/public_html"

function cleanup {
    read -t .01 -d '' || true # Consume all remaining input
}
trap cleanup EXIT

function status {
    echo "HTTP/1.0 $1 "$'\r'
}
function header {
    echo "$1: $2"$'\r'
}
function body {
    if ! [ "$IS_BODY_STARTED" ]; then
        echo $'\r'
        IS_BODY_STARTED=yes
    fi

    if ! [ "$IS_HEAD" ] && [ "$1" ]; then
        if [ "$1" != "stdin" ]; then
            echo "$1"
        else
            cat
        fi
    fi
}

function doListing {
    status "200 OK"
    header "Content-Type" "application/xhtml+xml"
    [ "$IS_HEAD" ] && return

    body stdin <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
EOF
    body "<head><title>Index of $2</title></head>"
    body "<body>"
    body "<h1>Index of $2</h1><hr /><pre><a href=\"../\">../</a>"

    for FILE in "$1"/*; do
        FILENAME=$(basename "$FILE")
        MTIME=$(date -ur "$FILE")
        if [ -d "$FILE" ]; then
            printf "<a href=\"%s/\">%-54s %s %19s\n" "$FILENAME" "$FILENAME/</a>" "$MTIME" "-" | body stdin
        else
            printf "<a href=\"%s\">%-54s %s %19s\n" "$FILENAME" "$FILENAME</a>" "$MTIME" "$(stat -c %s "$FILE")" | body stdin
        fi
    done

    body "</pre><hr /></body></html>"
}

function doPipe {
    status "200 OK"
    header "Content-Type" "$(file --mime-type -b "$1")"
    header "Content-Length" "$(stat -c %s "$1")"
    body
    [ "$IS_HEAD" ] || cat "$1"
}

read -t 60 REQUEST
REQUEST="${REQUEST%$'\r'}" # Remove carriage return

echo $REQUEST >&2

VALID_REQUEST="^(GET|HEAD) (/([-a-zA-Z0-9._~!$&'()*+,;=:@/]|%[a-zA-Z0-9]{2})*) HTTP/1\.[01]\$"
if ! [[ "$REQUEST" =~ $VALID_REQUEST ]]; then
    status "400 Bad Request"
    body "Bad Request"
    exit
fi

IS_HEAD=$([[ "$REQUEST" =~ ^HEAD ]] && echo yes)
REQUEST_FILE=$(<<< "$REQUEST" sed -E -e $'s\x01'"$VALID_REQUEST"$'\x01'"\2"$'\x01' -e 's/%/\\x/g')
REQUEST_FILE=$(printf %b "$REQUEST_FILE")
if [[ "$REQUEST_FILE" =~ /\.\. ]]; then
    status "400 Bad Request"
    body "Bad Request"
    exit
fi

FILE="$DOCUMENT_ROOT$REQUEST_FILE"
if ! [ -e "$FILE" ]; then
    status "404 Not Found"
    body "Not Found"
elif ! [ -r "$FILE" ]; then
    status "403 Forbidden"
    body "Forbidden"
elif [ -d "$FILE" ]; then
    if [ -r "$FILE/index.html" ]; then
        doPipe "$FILE/index.html"
    else
        doListing "$FILE" "$REQUEST_FILE"
    fi
elif [[ "$FILE" =~ \.cgi$ ]] && [ -x "$FILE" ]; then
    status "200 OK"
    [ "$IS_HEAD" ] || "$FILE"
else
    doPipe "$FILE"
fi
