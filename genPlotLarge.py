#!/usr/bin/python
import matplotlib.pyplot as plt
import json

themecolor = "#b90f22"

cecountFile = open("data-large/ceCountsLoc.json", "r") 
cecount = json.loads(cecountFile.read())

locFile = open("data-large/locPairs.json", "r") 
loc = json.loads(locFile.read())

slocFile = open("data-large/slocPairs.json", "r") 
sloc = json.loads(slocFile.read())


# Plot loc
x = list(map(lambda e: e["x"], loc))
y = list(map(lambda e: e["y"], loc))
plt.plot(x, x, "-", color="gray", linewidth=1)
plt.scatter(x, y, s=6, marker=".", color=themecolor)
plt.xlabel('ABS input size (loc)')
plt.ylabel('Counterexample size (loc)')
plt.show()

# Plot sloc
x = list(map(lambda e: e["x"], sloc))
y = list(map(lambda e: e["y"], sloc))
plt.plot(x, x, "-", color="gray", linewidth=1)
plt.scatter(x, y, s=6, marker=".", color=themecolor)
plt.xlabel('ABS input size (sloc)')
plt.ylabel('Counterexample size (sloc)')
plt.show()

# Plot loc vs # of counterexamples
x = list(map(lambda e: e["x"], cecount))
y = list(map(lambda e: e["y"], cecount))
plt.scatter(x, y, s=6, marker=".", color=themecolor)
plt.xlabel('ABS input size (loc)')
plt.ylabel('Number of generated counterexamples')
plt.show()