import json
f = open('../data/mtgox_entiretrades322.txt','r')
everything = f.readlines()
data = everything[1]
data = json.loads(everything[1])
data = data["data"]
onedelta = 0
lowestdelta = 999999999999999999999999999999999
for x in xrange(0,len(data)-1):
  onedelta = float(data[x+1]['tid'])-float(data[x]['tid'])
  if onedelta < lowestdelta:
    lowestdelta = onedelta


print lowestdelta
print "Trades per second is ", (1*1E6) / lowestdelta