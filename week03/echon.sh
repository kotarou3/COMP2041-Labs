#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <number of lines> <string>"
    exit 1
elif ! [[ $1 =~ ^[0-9]+$ ]]; then
    echo "$0: argument 1 must be a non-negative integer"
    exit 1
fi

yes $2 | head -n $1
