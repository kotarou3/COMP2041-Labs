#!/usr/bin/python3

import io, sys
from total_words import findWords

__all__ = ["getWordCounts"]

def getWordCounts(input):
    result = {"_total": 0}
    for word in findWords(input):
        word = word.lower()
        if not word in result:
            result[word] = 0

        result[word] += 1
        result["_total"] += 1

    return result

if __name__ == "__main__":
    word = sys.argv[1].lower()
    wordCounts = getWordCounts(io.TextIOWrapper(sys.stdin.buffer, encoding = "utf-8"))
    print("{} occurred {} times".format(word, wordCounts.get(word, 0)))
