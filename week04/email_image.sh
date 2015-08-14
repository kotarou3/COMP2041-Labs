#!/bin/bash

set -e

for FILE in "$@"; do
    if ! [ -e "$FILE" ]; then
        echo $FILE does not exist >&2
        exit 1
    fi
done

for FILE in "$@"; do
    display "$FILE"

    unset EMAIL
    while ! [ "$EMAIL" ]; do
        read -p "Address to e-mail this image to? " EMAIL
    done

    read -p "Message to accompany image? " MESSAGE

    <<< "$MESSAGE" mutt -s "$FILE" -a "$FILE" -- "$EMAIL"
    echo $FILE sent to $EMAIL
done
