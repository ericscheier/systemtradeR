#!/usr/bin/env python
#Alarm lag#
# Created by genBTC 3/30/2013

import urllib2
import json
#import json_ascii
import winsound         #plays beeps for alerts 
import time

from decimal import Decimal as D    #renamed to D for simplicity.

url = "https://data.mtgox.com/api/1/generic/order/lag"
req = urllib2.Request(url)

threshhold = raw_input("Lag Alarm Threshhold? (in seconds):  ")
threshhold = int(threshhold)
delaytime = raw_input("How often do you want to check? (in seconds):  ")
delaytime = int(delaytime)
while True:                                 #infinite loop
    resp = urllib2.urlopen(req)
    data = json.load(resp)

    lag = D(str(data["return"]["lag_secs"]))

    if lag >= D(threshhold):
        while True:
            for x in range(2,25):           # create a sequence of beeps
                winsound.Beep(x*100,100)    # each beep is at x*100hz for 100ms
            time.sleep(5)                   # repeat the alarm every 5 seconds
    print "The lag was normal. %s seconds" % lag
    time.sleep(delaytime)                   # pause for however long specified