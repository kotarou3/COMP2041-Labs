#!/bin/bash

SMALL=("Small files:")
MEDIUM=("Medium-sized files:")
LARGE=("Large files:")

for FILE in *; do
    LINES=$(wc -l < "$FILE")

    if [ $LINES -lt 10 ]; then
        SMALL+=($FILE)
    elif [ $LINES -lt 100 ]; then
        MEDIUM+=($FILE)
    else
        LARGE+=($FILE)
    fi
done

echo ${SMALL[@]}
echo ${MEDIUM[@]}
echo ${LARGE[@]}
