#!/bin/sh

if [ $# -lt 1 ]; then
    echo "Generates a list of random numbers using the LCG algorithm"
    echo "Usage: $0 <length> [<seed> [<m> <a> <c>]]"
    exit 1
fi

LENGTH="$1"
if [ $# -lt 2 ]; then
    SEED="$(date +%s)"
else
    SEED="$2"
fi
if [ $# -lt 5 ]; then
    # Suggestion from the ISO/IEC 9899 C11 standard
    M=4294967296
    A=1103515245
    C=12345
else
    M="$3"
    A="$4"
    C="$5"
fi

for N in $(seq $LENGTH); do
    SEED="$(expr \( "$A" \* "$SEED" + "$C" \) % "$M")"
    echo $SEED
done
