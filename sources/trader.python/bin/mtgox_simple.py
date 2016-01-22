#!/usr/bin/env python
# adds a single order to mt.gox
# uses encrypted API keys


import mtgoxhmac
import cmd

mtgox = mtgoxhmac.Client()

#get trade depth
#alltrades=mtgox.get_trades()

class Shell(cmd.Cmd):
    def emptyline(self):
        pass
    #print 'Last Mt.Gox Open order: ', mtgox.last_order()
    #print mtgox.get_info()
    prompt = '(buy|sell volume price) '
    def do_sell(self, arg):
         volume, price = arg.split()
         volume = float(volume)
         price = float(price)
         mtgox.order_new('ask',volume,price)

    def do_buy(self, arg):
        volume, price = arg.split()
        volume = float(volume)
        price = float(price)
        mtgox.order_new('bid',volume,price)

    def do_orders(self,arg):
        orders = mtgox.get_orders()['orders']
        try:
            for order in orders:
                print order['oid']
        except:
            return

    def do_exit(self,arg):
        print "Session Terminating......."
        return True
    def do_EOF(self, arg):
        do_exit(self)
        return True


Shell().cmdloop()
