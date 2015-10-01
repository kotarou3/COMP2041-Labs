#!/bin/sh

# Compare output to see if translated properly

# Stuff like this is almost perfect
echo $(head -n5 /etc/passwd)

if [ -u /bin/sh ] || [ -u /bin/bash ] && [ "$(whoami)" != "root" ]; then
    echo $LOCALE
fi

echo a | echo b || echo c || echo d && echo e && echo f | echo g || echo h || echo i && echo j || echo k && echo l || echo m && echo n && echo o

# These translate ok
A=1; B=2
echo $(PATH=..; A=3; echo $(PATH=.; A=4; echo $A $B $PATH $PWD) $A $PATH $HOME) $A $PATH
echo $A $PATH

# This less well
echo $(
    for A in `seq 10`; do
        echo $(
            for B in `seq $A 10`; do
                echo $B
            done
        )
    done
    echo $A $B
)

# All the rest fail
C=1
echo $(echo $C; C=2; echo $C) $C

while expr $B - $C; do
    C=`expr $C + 1`
done

if A=`echo 1; false`; then
    echo no
else
    echo $A
fi

true && A=1 || B=1
