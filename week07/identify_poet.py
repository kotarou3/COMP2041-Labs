#!/usr/bin/python3

import io, sys
from total_words import findWords
from frequency import loadPoetFrequencies

frequencies = loadPoetFrequencies(True)

for file in sys.argv[1:]:
    probabilities = {}
    for poet in frequencies.keys():
        probabilities[poet] = 0

    with io.open(file) as input:
        for word in findWords(input):
            word = word.lower()
            for poet, wordFrequencies in frequencies.items():
                probabilities[poet] += wordFrequencies.get(word, wordFrequencies["_zero"])

    result = sorted(probabilities.items(), key = lambda p: p[1])[-1]
    print("{} most resembles the work of {} (log-probability={:.1f})".format(file, result[0], result[1]))
