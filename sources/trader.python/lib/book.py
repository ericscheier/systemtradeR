#!/usr/bin/env python
# will parse any json book in standard form

import decimal
from decimal import Decimal as D

class Order(object):
    def __init__(self, price, volume):
        self.price = price
        self.volume = volume
    def __repr__(self):
        return str([self.price,self.volume])   
    def __getitem__(self,index):
        alist=[self.price,self.volume]
        return alist[index]
    
class Book(object):
    @classmethod
    def parse(cls, d, isbitfloor=False,goxfulldepth=False):
        def parse_side(arr):
            orders = []
            for a in arr:                       #iterate over the array
                if goxfulldepth:
                    price = str(a['price'])
                    volume = str(a['amount'])
                else:
                    price = str(a[0])
                    volume = str(a[1])

                if isbitfloor:                                    #all bitfloor data starts as 8 decimals
                    price = D(price).quantize(D('0.01'))        #valid prices are 2 decimals
                    volume = D(volume).quantize(D('0.00001'))       #valid volumes are 5 decimals
                else:  #every other site
                    if len(price) in (2,4):            #if the price is too short (ie 47 or 47.1)  then
                        price = D(price).quantize(D('0.01'))    #pad it to 2 decimals
                    else:
                        price = D(price)                          
                    if '.' not in volume:                 #if the volume is an integer and has no dot, then
                        volume = D(volume).quantize(D('0.1'))       #pad it to 1 decimal
                    volume = D(volume)
                orders.append(Order(price,volume))        #generate this side of the book as a class Order object
            return orders                               #and return it

        bids = parse_side(d['bids'])
        asks = parse_side(d['asks'])
        return cls(bids, asks)

    def __init__(self, bids, asks):
        self.bids = bids
        self.asks = asks

    def sort(self):
        self.bids.sort(key=lambda o: o.price, reverse=True)
        self.asks.sort(key=lambda o: o.price)

    def flatten(self, increment):
        def floor_inc(n):
            return (D(str(n))/D(increment)).quantize(D('1'), rounding=decimal.ROUND_DOWN)*D(increment)
        def ceil_inc(n):
            return (D(str(n))/D(increment)).quantize(D('1'), rounding=decimal.ROUND_UP)*D(increment)

        bids = {}
        asks = {}

        def add(d, price, volume):
            o = d.get(price)
            if o is None:
                d[price] = Order(price,volume)
            else:
                o.volume += volume


        for o in self.bids:
            price = floor_inc(o.price)
            add(bids, price, o.volume)

        for o in self.asks:
            price = ceil_inc(o.price)
            add(asks, price, o.volume)

        self.bids = bids.values()
        self.asks = asks.values()

    def subtract(self, other):
        bids = {}
        asks = {}
        for o in self.bids:
            bids[o.price] = o
        for o in self.asks:
            asks[o.price] = o

        def subtract_volume(d, price, volume):
            o = d.get(price)
            if o is not None:
                o.volume -= volume
            else:
                d[price] = Order(price,-volume)

        # remove order volumes book
        if other:
            for o in other.bids:
                subtract_volume(bids, o.price, o.volume)
            for o in other.asks:
                subtract_volume(asks, o.price, o.volume)

        self.bids = bids.values()
        self.asks = asks.values()
