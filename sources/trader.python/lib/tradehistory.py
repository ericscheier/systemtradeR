#!/usr/bin/env python
# Created by genBTC 3/19/2013
# reading trade history data from a file and gathering stats on it and
# testing mean functions with list comprehension 
import sys
import os
import json
import common 
import pyreadline
import time
import datetime
import math

fullpath = os.path.dirname(os.path.realpath(__file__))
if os.name == 'nt':
  partialpath=os.path.join(fullpath + '\\..\\data\\')
else:
  partialpath=os.path.join(fullpath + '/../data/')

#all it does is a simple "mean" calculation
def movavg(trades):
    #movingavg = sum(map(lambda x: x['price'], trades)) / len(trades)
    movingavg = sum(x['price'] for x in trades["data"]) / len(trades["data"])
    return movingavg

#this is the refined mean function thta i plan to use    
def mean(l): 
    if isinstance(l, dict):
        #print "The dict has [\"data\"] still attached and we have a dict of a list of dicts"
        return sum(float(x['price']) for x in l["data"]) / len(l["data"])
    elif isinstance(l, list) and isinstance(l[0],dict):
        #print "Return has been taken off and now dealing with a list of dicts"
        return sum(float(x['price']) for x in l) / len(l)
    elif isinstance(l,list):
        return sum(l) / len(l)
    else:
        raise TypeError()

def readhist24():
    print "Enter the filename in the data/ directory to open: "
    filetoopen = raw_input("Leave blank for default: ")
    if not(filetoopen):
        filetoopen = "mtgox_entiretrades.txt"
    with open(os.path.join(partialpath + filetoopen),'r') as f:
        everything = f.readlines()


    everything[0],everything[1] = everything[1],everything[0]

    new = json.loads(everything[0])
    newnew = common.floatify(new["data"])
    timeframe = raw_input("Press Enter to check the whole file, or just the last 'n' seconds: ")
    if timeframe:
        starttime = (newnew[-1]['tid']/1E6) - float(timeframe)
        templist = []
        for a in newnew:
            if (a['tid']/1E6) > starttime:
                templist.append(a)
        newnew = templist
    [earliesttime],[latesttime] = [[func(x[thing] for x in newnew) for thing in ['tid']] for func in [min,max]]

    independently = common.prompt("Analyse volume independently as Buys vs. Sells?",True)

    print "Earliest time is: %s" % (datetime.datetime.fromtimestamp(earliesttime/1E6))
    print "Latest time is: %s" % (datetime.datetime.fromtimestamp(latesttime/1E6))

    if independently:
        word = ("BUYS:","SELLS:")
        loopcount = 2
        condition = ("bid","ask")
    else:
        word = ["ALL:"]
        loopcount = 1
        condition = ["bidask"]
    for count in xrange(0,loopcount):
        print "-"*40
        print word[count]
        print "-"*40
        loopcondition = condition[count]

        #rewritten with list comprehension somehow
        [lowestprice,lowestamount],[highestprice,highestamount],[totaleachprice,totaleachamount] = \
            [[func(x[thing] for x in newnew if x["trade_type"] in loopcondition) for thing in ['price','amount']] for func in [min,max,sum]]
        tradecount = sum(1 for x in newnew if x["trade_type"] in loopcondition)
        print "Sum of all prices: $%f &  Sum of all amounts: %f BTC" % (totaleachprice, totaleachamount)

        print "Highest Price: $%f & Lowest Price: $%f" % (highestprice,lowestprice)

        avgprice = totaleachprice / tradecount
        avgamt = totaleachamount / tradecount
        print "Mean Price is $%f and Mean Amount is %f BTC" % (avgprice,avgamt)

        vwapcum = sum(x['price']*x['amount'] for x in newnew if x["trade_type"] in loopcondition)
        vwap = vwapcum / totaleachamount
        print "VWAP is: $%f" % vwap

        print "Highest Amount: %f BTC & Lowest Amount: %f BTC" % (highestamount,lowestamount)
        dowhale = common.prompt("Analyse for large transactions?",True)
        if dowhale:
            howbig = raw_input("Enter how many BTC above which you want to search for: ")
            print "  List of Whale Transactions (bigger than %s BTC): " % howbig
            print "  ","-"*35
            for x in newnew:
                if x["trade_type"] in loopcondition:
                    if x['amount'] >= int(howbig):
                        time = datetime.datetime.fromtimestamp(x['tid']/1E6).strftime("%H:%M:%S")
                        print "%f BTC @ $%f, %s, %s" % (x['amount'],x['price'],x['properties'],time)


#vari = common.variance((x['price'] for x in newnew),avgprice)
#stddev = common.stddev(vari)


def readdepth():
    filetoopen = raw_input("Enter the filename in the data/ directory to open: ")
    with open(os.path.join(partialpath + filetoopen),'r') as f:
        everything = f.readlines()

    #everything[0],everything[1] = everything[1],everything[0]

    new = json.loads(everything[0])
    newnew = common.floatify(new["data"])

    for ba in newnew.keys():
        print "-"*25,ba.upper(),"-"*25
        highbid = newnew[ba][-1]['price']
        lowask = newnew[ba][0]['price']

        [earliesttime],[latesttime] = [[func(x[thing] for x in newnew[ba]) for thing in ['stamp']] for func in [min,max]]

        newlist = []
        
        for x in newnew[ba]:
            if len(newlist) == 0:
                avgcumthing = highbid if ba == 'bids' else lowask
            else:
                avgcumthing = sum(y['price'] for y in newlist) / len(newlist)

            if math.sqrt((x['price'] - avgcumthing)**2) < x['price']/2:
                newlist.append(x)

        newnew[ba] = newlist

        # vari = common.variance((x['price'] for x in newnew[ba]),avgcumthing)
        # stddev = common.stddev(vari)

        #rewritten with list comprehension somehow
        vwapcum = sum(x['price']*x['amount'] for x in newnew[ba])
        [lowestprice,lowestamount],[highestprice,highestamount],[totaleachprice,totaleachamount] = \
            [[func(x[thing] for x in newnew[ba]) for thing in ['price','amount']] for func in [min,max,sum]]


        print "Sum of all prices: $%f &  Sum of all amounts: %f BTC" % (totaleachprice, totaleachamount)
        avgprice = totaleachprice / len(newnew[ba])
        avgamt = totaleachamount / len(newnew[ba])
        print "Mean Price is $%f and Mean Amount is %f BTC" % (avgprice,avgamt)
        vwap = vwapcum / totaleachamount
        print "VWAP is: $", vwap
        print "Highest Price: $%f & Lowest Price: $%f" % (highestprice,lowestprice)
        print "Highest Amount: %f BTC & Lowest Amount: %f BTC" % (highestamount,lowestamount)
        print "Earliest time is: %s" % (datetime.datetime.fromtimestamp(earliesttime/1E6))
        print "Latest time is: %s" % (datetime.datetime.fromtimestamp(latesttime/1E6))

if __name__ == "__main__":
    print "Is this a Trade History file (not a full depth file)?"
    isdepthfile = raw_input("N/No or [Leave blank for Yes(default)]")
    if not(isdepthfile):
        readhist24()
    else:
        readdepth()
