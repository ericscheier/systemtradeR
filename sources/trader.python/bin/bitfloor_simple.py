#!/usr/bin/env python
# adds a single order


import bitfloorapi
import cmd

bitfloor = bitfloorapi.Client()

def trade(side, arg):
    try:
        size, price = arg.split()
    except:
        print "Invalid arg {1}, expected size price".format(side, arg)
    print bitfloor.order_new(side=side, size=size, price=price)
	
class Shell(cmd.Cmd):
    def emptyline(self):
        pass

    prompt = '(buy|sell size price) '

    def do_sell(self, arg):
        trade(1, arg)

    def do_buy(self, arg):
        trade(0, arg)

    def do_EOF(self, arg):
        print "Any Trades have been Executed, Session Terminating......."
        return True

Shell().cmdloop()
