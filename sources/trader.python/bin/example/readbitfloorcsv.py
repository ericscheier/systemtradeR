import csv
import json
from decimal import Decimal as D 
import os

fullpath = os.path.dirname(os.path.realpath(__file__))
if os.name == 'nt':
    partialpath=os.path.join(fullpath + '\\..\\..\\data\\')
else:
    partialpath=os.path.join(fullpath + '/../../data/')

csvfile = open(os.path.join(partialpath + 'bitfloor-2013-3.csv'), 'rb')
spamreader = csv.reader(csvfile, delimiter=',', quotechar='"')

#keys = ["time","currency","entry","value","total","tid"]
fulllist = []
firstrow = True
# for row in spamreader:
# 	if firstrow == True:
# 		keys = row
# 	eachlist = []
# 	for x in xrange(len(row)):
# 		eachlist.append({keys[x]:row[x]})
# 	fulllist.append(eachlist)
# 	firstrow = False
#print fulllist

for row in spamreader:
	if firstrow == True:
		keys = row
	eachlist = []
	itemdict = []
	listoflist = []
	for x in xrange(len(row)):
		onelist = [keys[x],row[x]]
		listoflist.append(onelist)
		fulldict = {x[0]:x[1] for x in listoflist}

	fulllist.append(fulldict)
	firstrow = False
#print fulllist
allfees = D('0')
lowest = D('0')
highest = D('0')
onefee = D('0')
totallowest= D('0')
totalhighest = D('0')
for item in fulllist:
	if item["type"] == "fee":
		onefee = D(item["amount"])
		allfees += onefee.quantize(D('0.00000001'))
	if onefee < lowest:
		lowest = onefee.quantize(D('0.00000001'))
	if onefee > highest:
		highest = onefee.quantize(D('0.00000001'))
	if allfees < totallowest:
		totallowest = allfees
	if allfees > totalhighest:
		totalhighest = allfees

	#allfees = sum(x["fee"] for x in item)
print "Sum of all fees is: $",allfees*-1
print "Highest single fee: $",lowest*-1
print "Lowest single fee: $",highest*-1
print "Highest cumulative streak of fees: $",totallowest*-1
print "Lowest cumulative streak of fees: $",totalhighest*-1