#!/usr/bin/python3

import io, re, sys

__all__ = ["findWords"]

def findWords(iterable):
    for line in iterable:
        for word in filter(lambda w: w, re.split("[^a-zA-Z]+", line)):
            yield word

if __name__ == "__main__":
    print(len(list(findWords(io.TextIOWrapper(sys.stdin.buffer, encoding = "utf-8")))), "words")
