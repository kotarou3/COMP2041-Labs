#!/usr/bin/python3

from __future__ import print_function
import sys

if len(sys.argv) != 3:
    print("Usage: " + sys.argv[0] + " <number of lines> <string>")
    exit(1)

print((sys.argv[2] + "\n") * int(sys.argv[1]), end = "")
