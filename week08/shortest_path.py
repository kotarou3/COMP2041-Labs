#!/usr/bin/python3

# Destructive dijkstra's

import heapq, sys

class PriorityQueue(object):
    def __init__(self):
        self.heap = []
        self.entryFinder = {}
        self.REMOVED = "<removed_marker>"

    def insert(self, node, priority = 0):
        if node in self.entryFinder:
            self.delete(node)
        entry = [priority, node]
        self.entryFinder[node] = entry
        heapq.heappush(self.heap, entry)

    def delete(self, node):
        entry = self.entryFinder.pop(node)
        entry[-1] = self.REMOVED

    def pop(self):
        while self.heap:
            priority, node = heapq.heappop(self.heap)
            if node is not self.REMOVED:
                del self.entryFinder[node]
                return node
        raise KeyError("pop from an empty priority queue")

nodes = {}

for line in sys.stdin:
    parts = line.split()

    if not parts[0] in nodes:
        nodes[parts[0]] = {
            "name": parts[0],
            "edgeWeights": {},
            "distance": float("inf")
        }

    if not parts[1] in nodes:
        nodes[parts[1]] = {
            "name": parts[1],
            "edgeWeights": {},
            "distance": float("inf")
        }

    nodes[parts[0]]["edgeWeights"][parts[1]] = int(parts[2])
    nodes[parts[1]]["edgeWeights"][parts[0]] = int(parts[2])

nodes[sys.argv[1]]["distance"] = 0
pqueue = PriorityQueue()
pqueue.insert(sys.argv[1])

while len(pqueue.heap) > 0 and len(nodes[sys.argv[2]]["edgeWeights"]) > 0:
    node = nodes[pqueue.pop()]
    for name, weight in node["edgeWeights"].items():
        targetNode = nodes[name]
        newDistance = node["distance"] + weight
        if newDistance < targetNode["distance"]:
            targetNode["distance"] = newDistance
            targetNode["fromName"] = node["name"]
            pqueue.insert(name, newDistance)

    node["edgeWeights"].clear()

node = nodes[sys.argv[2]];
resultDistance = node["distance"]
resultPath = [sys.argv[2]]
while "fromName" in node:
    resultPath.append(node["fromName"])
    node = nodes[node["fromName"]]
resultPath.reverse()

print("Shortest route is length = {}: {}.".format(resultDistance, " ".join(resultPath)))
