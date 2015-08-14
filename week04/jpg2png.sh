#!/bin/bash

for FILE in *.jpg; do
    if [ -e "${FILE%.jpg}.png" ]; then
        echo ${FILE%.jpg}.png already exists >&2
        exit 1
    fi
done

for FILE in *.jpg; do
    convert "$FILE" "${FILE%.jpg}.png"
    rm "$FILE"
done
