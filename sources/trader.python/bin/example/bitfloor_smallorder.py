#!/usr/bin/env python
# Basic Trading Script for Bitfloor given

import random
import math

import bitfloorapi

bitfloor = bitfloorapi.Client()

book = bitfloor.book()

askprice = float(book['ask'][0])
print 'the book ask price is', askprice

bidprice = float(book['bid'][0])
print 'the book bid price is', bidprice

#Actually make a trade.
#side 0 means buy, side 1 means sell
#syntax is Bitfloor.order_new(side, size, price)

resp = bitfloor.order_new(0, 0.01, 50.02)
id = resp.get('order_id')
print format(id)
print resp


#    # add order
#    side = random.randrange(2)
#    price = bitfloor.round_inc(max(0.05, random.normalvariate(center - 0.5 + side, magnitude)))
#    size = round(max(0.01, random.random())*1e8)/1e8

#    
#    id = resp.get('order_id')
#    if id:
#        bitfloor.order_cancel(id)
#    else:
#        print "ERROR:", resp

#    count += 1

