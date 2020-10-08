#!/usr/bin/python
import matplotlib.pyplot as plt
import json

themecolor = "#b90f22"

cecountFile = open("data/ceCountsLoc.json", "r") 
cecount = json.loads(cecountFile.read())

locFile = open("data/locPairs.json", "r") 
loc = json.loads(locFile.read())

slocFile = open("data/slocPairs.json", "r") 
sloc = json.loads(slocFile.read())

byteFile = open("data/bytePairs.json", "r") 
byte = json.loads(byteFile.read())
# filter outliers
byte = list(filter(lambda e: e["y"] < 10000, byte))


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

# Plot byte
x = list(map(lambda e: e["x"], byte))
y = list(map(lambda e: e["y"], byte))
plt.plot(x, x, "-", color="gray", linewidth=1)
plt.scatter(x, y, s=6, marker=".", color=themecolor)
plt.xlabel('ABS input size (byte)')
plt.ylabel('Counterexample size (byte)')
plt.show()

# Plot loc vs # of counterexamples
x = list(map(lambda e: e["x"], cecount))
y = list(map(lambda e: e["y"], cecount))
plt.scatter(x, y, s=6, marker=".", color=themecolor)
plt.xlabel('ABS input size (loc)')
plt.ylabel('Number of generated counterexamples')
plt.show()