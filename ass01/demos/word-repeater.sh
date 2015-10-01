#!/bin/sh

if [ $# -lt 2 ]; then
    echo "Repeats a word many times"
    echo "Usage: $0 <word> <times>"
    exit 1
fi

N=0
while [ "$N" -lt "$2" ]; do
    RESULT="$RESULT$1"
    N=$(expr "$N" + 1)
done

echo "$RESULT"
