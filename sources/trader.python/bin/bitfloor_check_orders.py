#!/usr/bin/env python

import bitfloorapi
import cmd
import sys
import time

bitfloor = bitfloorapi.Client()

#must be run with Side (0=buy,1=sell), size, Price as arguments on the command line
#no.
#side,size,price = sys.argv[1:]

time.sleep(4)
orders = bitfloor.orders()
for order in orders:
    print order['order_id'], order['size'], order['price']
	