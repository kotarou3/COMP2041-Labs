#!/bin/bash

set -e

DATE=$(date -r "$1" --rfc-3339=seconds)
mogrify -gravity south -pointsize 36 \
    -stroke white -fill black -draw "text 0,10 '$DATE'" \
    "$1"
touch -d "$DATE" "$1"
