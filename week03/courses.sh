#!/bin/bash

set -e

if ! [[ $1 =~ ^[A-Z]{4}$ ]]; then
    echo "Usage: $0 <4 letter course prefix>" >&2
    exit 1
fi

COURSE_MATCHER=">($1[[:digit:]]{4})([^>]*>){3}([^<]*)<"

declare -A COURSES
for TYPE in "Postgraduate" "Undergraduate"; do
    IFS=$'\n'
    MATCHES=($(
        wget "http://www.handbook.unsw.edu.au/vbook2015/brCoursesByAtoZ.jsp?StudyLevel=$TYPE&descr=${1:0:1}" -qO - |
        tr $'\n' ' ' |
        grep -Eo "$COURSE_MATCHER" |
        sed -E "s/$COURSE_MATCHER/\1\x01\3/g"
    ))

    for PAIR in "${MATCHES[@]}"; do
        IFS=$'\x01'
        PAIR=($PAIR)

        COURSES[${PAIR[0]}]="${PAIR[1]}"
    done
done

IFS=' '
for COURSE in "${!COURSES[@]}"; do
    echo $COURSE ${COURSES[$COURSE]}
done | sort
