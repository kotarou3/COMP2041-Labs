#!/usr/bin/python3

import sys, urllib.request
from html.parser import HTMLParser

class TagCounter(HTMLParser):
    tagCount = {}
    def handle_starttag(self, tag, attrs):
        if not tag in self.tagCount:
            self.tagCount[tag] = 0
        self.tagCount[tag] += 1

isByFrequency = sys.argv[1] == "-f"

parser = TagCounter(strict = False)
parser.feed(urllib.request.urlopen(sys.argv[2 if isByFrequency else 1]).read().decode("utf8"))

for tag, count in sorted(parser.tagCount.items(), key = lambda pair: pair[1 if isByFrequency else 0]):
    print(tag, count)
