#!/usr/bin/env python
#Ticker Printout#
# Created by genBTC 4/12/2013

import urllib2
import json
#import json_ascii
import time

#from decimal import Decimal as D    #renamed to D for simplicity.

url = "http://data.mtgox.com/api/1/BTCUSD/ticker_fast"
req = urllib2.Request(url)

delaytime = raw_input("How often do you want to check? (in seconds):  ")
delaytime = int(delaytime)
while True:                                 #infinite loop
    resp = urllib2.urlopen(req)
    data = json.load(resp)

    buy = str(data["return"]["buy"]["display"])
    sell = str(data["return"]["sell"]["display"])
    print " ticker:  bid:", buy,"   ask:", sell

    time.sleep(delaytime)                   # pause for however long specified