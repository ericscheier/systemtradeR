#!/usr/bin/env python
# randomly adds/cancels orders to keep track of average latency of ordering and cancelling
### pass how many times you want it to run on the command line


import random
import math
import time
import bitfloorapi
import decimal
from decimal import Decimal as D
import cmd
import readline
import sys

bitfloor = bitfloorapi.Client()

olatency = [] # order latency
clatency = [] # cancel latency

def mean(l):
    return float(sum(l))/len(l) if len(l) > 0 else None

def calclatency():        
    orders = set()
    print '.......... Ctrl+Z to quit..........'
    print 'Running %r times' % (float(sys.argv[1]))
    times = int(sys.argv[1])
    for count in range(times):
        testprice = float(bitfloor.ticker()['price'])+5     #creates a pending order $5 above lowest ask price to test
        magnitude=0.01                                      #Create tiny orders of 0.01 BTC
        print '{0} order/cancels: {1}, {2}'.format(count, testprice, magnitude)
        print 'Ordering latency: {0} orders, Cancellation latency: {1} '.format(mean(olatency), mean(clatency))    

        if random.random() < .5:
            if orders:
                start = time.time()
                bitfloor.order_cancel(orders.pop())
                clatency.append(time.time() - start)
            
        else:
            start = time.time()
            order = bitfloor.order_new(1, magnitude, testprice) #add order
            olatency.append(time.time() - start)
            id = order.get('order_id')
            if id:
                orders.add(id)
            else:
                print "ERROR:", order
#        count += 1
    time.sleep(5)
    bitfloor.cancel_all() #cancel any remaining orders
    print "All Trades have been Cancelled, Session Terminating......."
    return True    
 
calclatency()