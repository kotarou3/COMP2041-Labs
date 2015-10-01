#!/bin/sh

if [ $# -lt 2 ]; then
    echo "Calculates the greatest common divisor using the Euclidean algorithm"
    echo "Usage: $0 <a> <b>"
    exit 1
fi

A="$1"
B="$2"

while [ "$B" -ne 0 ]; do
    T="$B"
    B="$(expr "$A" % "$B")"
    A="$T"
done

echo "$A"
