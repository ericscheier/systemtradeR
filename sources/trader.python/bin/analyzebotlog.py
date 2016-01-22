#!/usr/bin/env python
#analyzes the liquidbotlog.txt file to find out total price of all that were bought/sold
#this should no longer be needed because i added a new file that the bot will write only successes to in a special format


#filetoopen = raw_input("Enter the filename in the data/ directory to open: ")
# filetoopen = "liquidbotlog.txt"

# filled = open("filled.txt",'w') 
# with open(filetoopen,'r') as f:
#     for line in f:
#     	if "filled" in line:
#     		filled.write(line)
# filled.close()

filled = open("filled.txt",'r') 
buylinelist = []
selllinelist = []
for line in filled:
	if "Buy" in line and "order" in line:
		wordlist = line.split()
		buybtc = float(wordlist[5])
		buyprice = float(wordlist[8][1:])
		buylinelist.append([buybtc,buyprice])
	if "Sell" in line and "order" in line:
		wordlist = line.split()
		sellbtc = float(wordlist[5])
		sellprice = float(wordlist[8][1:])
		selllinelist.append([sellbtc,sellprice])
	
totalbuy = 0
totalsell = 0
for x in buylinelist:
	totalbuy += x[0]*x[1]
for x in selllinelist:
	totalsell += x[0]*x[1]

print "Total Bought: $%s.  Total Sold: $%s"	% (totalbuy,totalsell)