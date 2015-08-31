#!/usr/bin/python3

from __future__ import print_function
import sys, re

whales = {}
for line in sys.stdin:
    line = re.sub("\s+", " ", line.lower().strip())
    parts = line.split(" ")
    if len(parts) < 2:
        continue

    number = int(parts[0])
    type = re.sub("s$", "", " ".join(parts[1:]))

    if not type in whales:
        whales[type] = {
            "pods": 0,
            "individuals": 0
        }

    whales[type]["pods"] += 1
    whales[type]["individuals"] += number;

if len(sys.argv) > 1:
    print("{0} observations: ".format(sys.argv[1]), end = "")
    if sys.argv[1] in whales:
        print("{0} pods, {1} individuals".format(whales[sys.argv[1]]["pods"], whales[sys.argv[1]]["individuals"]))
    else:
        print("0 pods, 0 individuals")
else:
    for type in sorted(whales):
        print("{0} observations: {1} pods, {2} individuals".format(type, whales[type]["pods"], whales[type]["individuals"]))
