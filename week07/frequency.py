#!/usr/bin/python3

import glob, io, math, os, re, sys
from count_word import getWordCounts

__all__ = ["getWordFrequencies", "loadPoetFrequencies"]

def wordCountsToFrequencies(wordCounts, isLog = False):
    result = {}
    for word, count in wordCounts.items():
        if word == "_total":
            continue

        if isLog:
            result[word] = math.log((count + 1) / wordCounts["_total"])
        else:
            result[word] = count / wordCounts["_total"]

    if isLog:
        result["_zero"] = -math.log(wordCounts["_total"])

    return result

def loadPoetFrequencies(isLog = False, debugWord = False):
    result = {}
    for file in sorted(glob.glob("poets/*.txt")):
        with io.open(file, encoding = "utf8") as input:
            counts = getWordCounts(input)
            frequencies = wordCountsToFrequencies(counts, isLog)
            poet = re.sub("_", " ", os.path.splitext(os.path.basename(file))[0])
            result[poet] = frequencies

            if debugWord:
                if isLog:
                    print("log(({}+1)/{:6d}) = {:8.4f} {}".format(counts.get(debugWord, 0), counts["_total"], frequencies.get(debugWord, frequencies["_zero"]), poet))
                else:
                    print("{:4d}/{:6d} = {:.9f} {}".format(counts.get(debugWord, 0), counts["_total"], frequencies.get(debugWord, 0), poet))

    return result

if __name__ == "__main__":
    isLog = os.path.basename(__file__) == "log_probability.py"
    word = sys.argv[1].lower()
    loadPoetFrequencies(isLog, word)
