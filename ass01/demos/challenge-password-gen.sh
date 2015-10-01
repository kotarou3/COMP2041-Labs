#!/bin/sh

if [ $# -lt 1 ]; then
    echo "Generates random passwords"
    echo "Usage: $0 <length> [<amount>]"
    exit 1
fi

LENGTH="$1"
if [ $# -lt 2 ]; then
    AMOUNT=1
else
    AMOUNT="$2"
fi

dd if=/dev/urandom of=/dev/stdout bs=100k count=1 | grep -aoE '[[:alnum:][:punct:] ]' | tr -d '\n' | fold -w "$LENGTH" | head -n "$AMOUNT"
