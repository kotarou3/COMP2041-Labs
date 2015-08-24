#!/bin/bash

function runTest {
    INPUT_SIZE="$1"
    TRIALS="$2"

    # Binomial distribution
    declare -A PROBABILITIES
    EXPECTED=$((TRIALS / INPUT_SIZE))
    ONE_SIGMA=$(bc <<< "sqrt($TRIALS * ($INPUT_SIZE - 1) / $INPUT_SIZE^2)")
    TWO_SIGMA=$(bc <<< "sqrt(2^2 * $TRIALS * ($INPUT_SIZE - 1) / $INPUT_SIZE^2)")
    THREE_SIGMA=$(bc <<< "sqrt(3^2 * $TRIALS * ($INPUT_SIZE - 1) / $INPUT_SIZE^2)")
    FOUR_SIGMA=$(bc <<< "sqrt(4^2 * $TRIALS * ($INPUT_SIZE - 1) / $INPUT_SIZE^2)")

    echo "Shuffling $INPUT_SIZE values $TRIALS times ($INPUT_SIZE x $TRIALS)" >&2

    for ((INPUT=1; INPUT<=INPUT_SIZE; ++INPUT)); do
        for ((OUTPUT=0; OUTPUT<INPUT_SIZE; ++OUTPUT)); do
            PROBABILITIES["$INPUT,$OUTPUT"]=0
        done
    done

    INPUT="$(seq "$INPUT_SIZE")"
    for ((TRIAL=0; TRIAL<TRIALS; ++TRIAL)); do
        RESULT=($(<<< "$INPUT" ./shuffle.pl)) # Bottleneck here since perl takes >1 us to start
        for LINE_NUMBER in "${!RESULT[@]}"; do
            if [ "$LINE_NUMBER" -ge "$INPUT_SIZE" ]; then
                echo "Failed ($INPUT_SIZE x $TRIALS): Script outputted more lines than expected (>$INPUT_SIZE):" >&2
                echo "$RESULT" >&2
                return 1
            fi

            ((++PROBABILITIES["${RESULT[$LINE_NUMBER]},$LINE_NUMBER"]))
        done
    done

    echo "Expected mean: $EXPECTED"
    echo $'\033[0;32m1\033[0m / \033[0;33m2\033[0m / \033[1;33m3\033[0m / \033[0;31m4\033[0m-sigma: \033[0;32m'"$ONE_SIGMA"$'\033[0m / \033[0;33m'"$TWO_SIGMA"$'\033[0m / \033[1;33m'"$THREE_SIGMA"$'\033[0m / \033[0;31m'"$FOUR_SIGMA"$'\033[0m'

    echo -n "   Out"$'\t'
    for ((OUTPUT=0; OUTPUT<INPUT_SIZE; ++OUTPUT)); do
        echo -n "$((OUTPUT + 1))"$'\t'
    done
    echo
    echo '  \'
    echo "In"
    for ((INPUT=1; INPUT<=INPUT_SIZE; ++INPUT)); do
        echo -n "$INPUT"$'\t'
        for ((OUTPUT=0; OUTPUT<INPUT_SIZE; ++OUTPUT)); do
            OFFSET=$((PROBABILITIES["$INPUT,$OUTPUT"] - EXPECTED))
            if [ "-$ONE_SIGMA" -le "$OFFSET" ] && [ "$OFFSET" -le "$ONE_SIGMA" ]; then
                echo -n $'\033[0;32m'"$OFFSET"$'\033[0m\t'
            elif [ "-$TWO_SIGMA" -le "$OFFSET" ] && [ "$OFFSET" -le "$TWO_SIGMA" ]; then
                echo -n $'\033[0;33m'"$OFFSET"$'\033[0m\t'
            elif [ "-$THREE_SIGMA" -le "$OFFSET" ] && [ "$OFFSET" -le "$THREE_SIGMA" ]; then
                echo -n $'\033[1;33m'"$OFFSET"$'\033[0m\t'
            elif [ "-$FOUR_SIGMA" -le "$OFFSET" ] && [ "$OFFSET" -le "$FOUR_SIGMA" ]; then
                IS_FAILED="almost"
                echo -n $'\033[0;31m'"$OFFSET"$'\033[0m\t'
            else
                IS_FAILED="yes"
                echo -n $'\033[1;31m'"$OFFSET"$'\033[0m\t'
            fi
        done
        echo
    done

    if [ "$IS_FAILED" == "yes" ]; then
        echo $'\033[1;31m'"Failed ($INPUT_SIZE x $TRIALS): Output distribution not within 4-sigma"$'\033[0m\t' >&2
        return 1
    elif [ "$IS_FAILED" == "almost" ]; then
        echo $'\033[0;31m'"Almost failed ($INPUT_SIZE x $TRIALS): Output distribution not within 3-sigma"$'\033[0m\t' >&2
    else
        echo "Passed ($INPUT_SIZE x $TRIALS)" >&2
    fi
}

set -e
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

runTest 5 2000 &
runTest 10 4000 &
runTest 5 10000 &
runTest 10 20000 &
runTest 20 40000 &

sleep 1
for N in $(seq 5); do
    echo
    wait "$(jobs -p | head -n1)"
done
trap - EXIT
