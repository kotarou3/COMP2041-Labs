#!/usr/bin/python3

from __future__ import print_function
import collections, io, re, sys

def doTail(input, length):
    if length == 0:
        return

    buffer = collections.deque(maxlen = length)
    for line in input:
        buffer.append(line)

    print("".join(buffer), end = "")

for file in sys.argv[1:]:
    try:
        input = io.open(file)
    except IOError:
        print(sys.argv[0] + ": Can't open " + file, file = sys.stderr)
        continue

    try:
        doTail(input, 10)
    finally:
        input.close()
