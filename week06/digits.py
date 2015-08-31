#!/usr/bin/python3

from __future__ import print_function
from re import sub;
import sys;

for line in sys.stdin:
    print(sub("[6-9]", ">", sub("[0-4]", "<", line)), end = "")
