#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: $0 <a> <b>"
    exit 1
fi

[ "$1" \< "$2" ] && echo "$1 < $2"
[ "$1" \> "$2" ] && echo "$1 > $2"
[ "$1" = "$2" ] && echo "$1 = $2"
