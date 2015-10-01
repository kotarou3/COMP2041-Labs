#!/bin/sh

if [ $# -lt 4 ]; then
    echo "Remember CySCA?"
    echo "Usage: $0 <breadth> <depth> <node size> <dest>"
    exit 1
fi

BREADTH="$1"
DEPTH="$2"
SIZE="$3"
DEST="$4"

if [ -e "$DEST" ]; then
    echo "$DEST exists. Not overwriting"
    exit 1
fi

TMPDIR="$(mktemp -d --tmpdir="$(pwd)")"
cd "$TMPDIR"

truncate -s "$SIZE" dest.zip

while [ "$DEPTH" -gt 0 ]; do
    mv dest.zip 0.zip
    for N in $(seq 0 "$(expr "$BREADTH" - 1)"); do
        echo "Depth $DEPTH Breadth $N"

        7z a dest.zip "$N.zip"
        mv "$N.zip" "$(expr "$N" + 1).zip"
    done

    rm "$BREADTH.zip"
    truncate -s "$SIZE" dest.zip

    DEPTH="$(expr "$DEPTH" - 1)"
done

cd ..
mv "$TMPDIR"/dest.zip "$DEST"
rmdir "$TMPDIR"
