#!/usr/bin/env python
# bitstamp_client.py
# Created by genBTC 4/13/2013
# Universal Client for all things bitstamp

import bitstampapi 
import cmd
import time
from decimal import Decimal as D    #got annoyed at having to type Decimal every time.
from common import *
from book import *
import threading
import signal
import traceback
import logging
import sys
import socket
import os
if os.name == 'nt':
    import winsound
    import pyreadline
    import commandhistory   #enable command line completion and command history

#################################

bitstamp = bitstampapi.Client()

bPrec = bitstamp.bPrec
cPrec = bitstamp.cPrec

threadlist = {}

# data partial path directory
fullpath = os.path.dirname(os.path.realpath(__file__))
if ".exe" in sys.argv[0]:
    partialpath=os.path.join(fullpath + '\\data\\')
elif os.name == 'nt':
    partialpath=os.path.join(fullpath + '\\..\\data\\')
else:
    partialpath=os.path.join(fullpath + '/../data/')


#################################

def bal():
    balance = bitstamp.account_balance()
    btcbalance = D(balance['btc_balance'])
    usdbalance = D(balance['usd_balance'])
    return btcbalance,usdbalance

def available():
    balance = bitstamp.account_balance()
    btcavailable =D(balance['btc_available'])
    usdavailable = D(balance['usd_available'])
    return btcavailable,usdavailable

def reserved():
    balance = bitstamp.account_balance()
    btcreserved = D(balance['btc_reserved'])
    usdreserved = D(balance['usd_reserved'])
    return btcreserved,usdreserved

#################################


#For Market Orders (not limit)
# Checks market conditions
# Order X amount of BTC between price A and B
# optional Wait time (default to instant gratification)
#Checks exact price (total and per bitcoin) @ Market prices
#   by checking opposite Order Book depth for a given volume and price range (lower to upper)
#   and alerts you if cannot be filled immediately, and lets you place a limit order instead
def markettrade(bookside,action,amount,lowest,highest,waittime=0):
    fail = False

    if action == 'sell':
        if lowest > bookside[0].price:
            fail = True
            print "Market order impossible, price too high."
            print "Your Lowest asking price: $%s is higher than the highest bid: $%s" % (lowest,bookside[0].price)
            print "Place [L]imit order on the books for later?   or......"
            print "Sell to the [H]ighest Bidder? Or [C]ancel?"
            print "[L]imit Order / [H]ighest Bidder / [C]ancel: "
            choice = raw_input()
            if choice =='H' or choice == 'h' or choice =='B' or choice =='b':
                pass                 #sell_on_mtgox

    elif action == 'buy':
        if highest < bookside[0].price:
            fail = True
            print "Suboptimal behavior detected. "
            print "Your highest bid price: $%s is lower than the lowest ask: $%s" % (highest,bookside[0].price)

            # print "[P]roceed / [C]ancel: "
            # choice = raw_input()
            # if choice =='P' or choice =='Proceed':
            #     pass                 #buy_on_mtgox
    
    if fail == False:
        totalBTC,totalprice = depthsumrange(bookside,amount,lowest,highest)
        depthprice(bookside,amount,lowest,highest)

    #time.sleep(D(waittime))


#get update the entire order book
def refreshbook():
    #get the entire order book  (already sorted.)
    entirebook = bitstamp.entirebook()
    return entirebook

#start printing part of the order book (first 15 asks and 15 bids)
def printorderbook(length=15):
    entirebook = refreshbook()
    #start printing part of the order book (first 15 asks and 15 bids)
    printbothbooks(entirebook.asks,entirebook.bids,length)   #otherwise use the length from the arguments


#################################      
#Console
class Shell(cmd.Cmd):
    def emptyline(self):      
        pass                #Do nothing on empty input line instead of re-executing the last command
    def __init__(self):
        cmd.Cmd.__init__(self)
        self.prompt = 'Bitstamp CMD>'   # The prompt for a new user input command
        self.onecmd('help')

    #Shut down all threads cleanly.        
    def threadshutdown(self):
        threads = False
        for k,v in threadlist.iteritems():
            v.set()
            threads = True
        if threads:
            print "Shutting down threads..."        

    #CTRL+C Handling
    def cmdloop(self):
        try:
            cmd.Cmd.cmdloop(self)
        except KeyboardInterrupt:
            print "Press CTRL+C again to exit, or ENTER to continue."
            try:
                wantcontinue = raw_input()
            except KeyboardInterrupt:
                self.threadshutdown()
                self.do_exit(self)
                return
            self.cmdloop()
        except:                     #catch every exception!
            traceback.print_exc()
            self.cmdloop()

#end of nuts and bolts section
#################################

    #start out by printing the order book
    printorderbook()

    #give a little user interface       
    print 'To exit: exit,Ctrl+C,Ctrl+Z or Ctrl+Pause/Break to force quit'
    print 'Type help to show the available commands.'
    print "syntax: command subcommand <required> [optional] ['word']"


    def do_balance(self,args):
        """Shows your current account balance and value of your portfolio based on last ticker price"""
        """Can show total, available(available for trading), or reserved(reserved in open orders)"""
        """usage: balance [available/reserved](optional)"""
        args = stripoffensive(args)
        if 'available' in args:
            btc,usd = available()    
        elif 'reserved' in args:
            btc,usd = reserved()
        else:
            btc,usd = bal()
        word = args if args else "total"
        print 'Your %s balance is %.8f BTC and $%.2f USD ' % (word,btc,usd)
        if word == "total":
            last = D(bitstamp.ticker()['last'])
            print 'Account Value: $%.2f @ Last BTC Price of $%.2f' % (btc*last+usd,last)


    def do_balancenotifier(self,args):
        """Check your balance every 30 seconds and BEEP and print something out when you receive the funds (either btc or usd)"""
        """usage: balancenotifier"""
        def bn(firstarg,notifier_stop,btc,usd):
            while(not notifier_stop.is_set()):
                btcnew,usdnew = bal()
                if btcnew > btc or usdnew > usd:
                    last = D(bitstamp.ticker()['last'])
                    print '\nBalance: %s BTC + $%s USD = $%.5f @ $%.5f (Last)' % (btcnew,usdnew,(btcnew*last)+usdnew,last)
                    for x in xrange(0,3):
                        if os.name == 'nt':
                            winsound.Beep(1200,1000)
                            winsound.Beep(1800,1000)
                        else:
                            print '\a\a'
                    btc,usd = btcnew,usdnew
                notifier_stop.wait(30)

        global notifier_stop
        btc,usd = bal()
        args = stripoffensive(args)
        args = args.split()
        if 'exit' in args:
            print "Shutting down background thread..."
            notifier_stop.set()
        else:   
            notifier_stop = threading.Event()
            threadlist["balancenotifier"] = notifier_stop
            notifier_thread = threading.Thread(target = bn, args=(None,notifier_stop,btc,usd))
            notifier_thread.daemon = True
            notifier_thread.start()



    def do_book(self,length):
        """Download and print the order book of current bids and asks, up to length [length]"""
        """usage: book [length](optional)"""
        try:
            length = int(length)
            printorderbook(length)
        except:
            printorderbook()        

#################################

    def do_buy(self, args):
        """(market order): buy <#BTC> \n""" \
        """(limit  order): buy <#BTC> <price> \n""" \
        """(spend-X market order): buy usd <#USD>         \n(specify the $ amount in #USD, and use the last ticker price-market)\n"""\
        """(spend-X limit  order): buy usd <#USD> <price> \n(same as above, but specify a price so it goes as a limit order)\n"""\
        """(spread order): buy <volume> <price_lower> <price_upper> <chunks> ['random'] \n(random makes chunk amounts slightly different)\n"""\
        """ ^-adds a multitude of orders between price A and price B of equal volumed # of chunks on Bitstamp."""
        try:
            args = stripoffensive(args)
            args = args.split()
            newargs = tuple(decimalify(args))
            if "usd" in newargs:                                        #places an order of $X USD 
                newargs = list(newargs);newargs.remove("usd");newargs = tuple(newargs)  #remove usd arg once found
                if len(newargs) == 1:                                  #for a market order
                    rate = D(bitstamp.ticker()["ask"] )                  #use the opposite side's best price
                    amt = newargs[0] / rate
                    buyprice = 9999    
                elif len(newargs) == 2:                                  # or as a limit order  
                    buyprice = newargs[1]                           
                    amt = newargs[0] / buyprice                        #convert USD to BTC.
                newargs = (amt.quantize(bPrec),buyprice)         #get the arguments ready
            if len(newargs) in (1,2):
                bitstamp.order_new(0,*newargs) 
            elif len(newargs) >= 4:
                spread('bitstamp',bitstamp,0, *newargs)               #use spread logic
            else:
                raise UserError
        except Exception as e:
            traceback.print_exc()
            print "Invalid args given!!! Proper use is:"
            self.onecmd('help buy')


 
    def do_sell(self, args):
        """(market order): sell <#BTC> \n""" \
        """(limit  order): sell <#BTC> <price> \n""" \
        """(spend-X market order): sell usd <#USD>         \n(specify the $ amount in #USD, and use the last ticker price-market)\n"""\
        """(spend-X limit  order): sell usd <#USD> <price> \n(same as above, but specify a price so it goes as a limit order)\n"""\
        """(spread order): sell <volume> <price_lower> <price_upper> <chunks> ['random'] \n(random makes chunk amounts slightly different)\n"""\
        """ ^-adds a multitude of orders between price A and price B of equal volumed # of chunks on Bitstamp."""
        try:
            args = stripoffensive(args)
            args = args.split()
            newargs = tuple(decimalify(args))
            if "usd" in newargs:                                        #places an order of $X USD 
                newargs = list(newargs);newargs.remove("usd");newargs = tuple(newargs)  #remove usd arg once found
                if len(newargs) == 1:                                  #for a market order
                    rate = D(bitstamp.ticker()["bid"] )                 #use the opposite side's best price
                    amt = newargs[0] / rate
                    sellprice = 9999    
                elif len(newargs) == 2:                                  # or as a limit order  
                    sellprice = newargs[1]                           
                    amt = newargs[0] / sellprice                        #convert USD to BTC.
                newargs = (amt.quantize(bPrec),sellprice)         #get the arguments ready
            if len(newargs) in (1,2):
                bitstamp.order_new(0,*newargs) 
            elif len(newargs) >= 4:
                spread('bitstamp',bitstamp,0, *newargs)               #use spread logic
            else:
                raise UserError
        except Exception as e:
            traceback.print_exc()
            print "Invalid args given!!! Proper use is:"
            self.onecmd('help buy')


#################################

    def do_cancel(self,args):
        """Cancel an order by number,ie: 7 or by range, ie: 10 - 25\n""" \
        """Use with arguments after the cancel command, or without to view the list and prompt you\n""" \
        """usage: cancel <number/range>"""
        try:
            useargs = False
            if args:
                useargs = True
            orders = bitstamp.open_orders()
            orders = sorted(orders, key=lambda x: float(x['price']))
            numorder = 0
            numcancelled = 0
            for order in orders:
                ordertype="Sell" if order['type'] == 1 else "Buy"
                numorder += 1
                print '%s = %s | $%s @ %s BTC %s' % (numorder,ordertype,order['price'],order['amount'],order['id'])
            print "Use spaces or commas to seperate order numbers: 1,2,3"
            print "Use a - to specify a range: 1-20. "
            while True:         #loop until quit
                userange=False
                numorder = 0
                if useargs == True:
                    orderlist = args
                    useargs = False
                else:
                    orderlist = ""
                    orderlist = raw_input("Which order numbers would you like to cancel?: [ENTER] quits.\n")
                if orderlist == "":
                    if numcancelled > 1:
                        print "%s Orders have been Cancelled!!!!!" % numcancelled
                    break
                orderlist = stripoffensive(orderlist,',-')
                if "," in orderlist:
                    orderlist = orderlist.split(',')
                if '-' in orderlist:
                    userange = True
                    orderlist = orderlist.split('-')
                else:
                    orderlist = orderlist.split()
                for order in orders:
                    cancel = False
                    numorder += 1
                    if userange == True:
                        if numorder >= int(orderlist[0]) and numorder <= int(orderlist[1]):
                            cancel = True
                    elif str(numorder) in orderlist:
                        cancel = True
                    if cancel == True:
                        result = bitstamp.cancel_order(order['id'])
                        if result:
                            numcancelled += 1
                            print "Order %s Cancelled" % order['id']
        except Exception as e:
            print "Unexpected Error: %s" % e
            self.onecmd('help cancel')        

    def do_cancelall(self,args):
        """Cancel every single order you have on the books"""
        try:
            bitstamp.cancel_all()
        except Exception as e:
            print "Unexpected Error: %s" % e
            self.onecmd('help cancelall')


#####################################################################
#bunch of small function utilities.
#
    def do_bitinstant(self,args):
        """Just print out the BitInstant reserves"""
        try:
            ppdict(bitstamp.bitinstant_reserves())
        except Exception as e:
            print "Unexpected Error: %s" % e
            self.onecmd('help bitinstant')

    def do_eurusd(self,args):
        """Just print out the exchange rate for EUD to USD conversion"""
        try:
            ppdict(bitstamp.eur_usd())
        except Exception as e:
            print "Unexpected Error: %s" % e
            self.onecmd('help eurusd')

    def do_create_bitstampcode(self,args):
        """Create a Bitstamp code of either BTC or USD"""
        """usage: create_bitstampcode [usd]/[btc] amount"""
        try:
            if not(args):
                btcusd = prompt("Create the code as BTC?",True)
                amount = raw_input("Amount to create the code for?")
            else:
                btcusd, amount = args.split()
            kwargs = {}
            if btcusd == True or btcusd.lower() == "btc":
                print "BTC Selected as the Code creation method"
                kwargs["btc"]=amount
            elif btcusd == False or btcusd.lower() == "usd":
                print "USD Selected as the Code creation method"
                kwargs["usd"]=amount

            bitstamp.create_bitstampcode(**kwargs)
        except:
            print "Incorrect Usage. Invalid args given."
            self.onecmd('help create_bitstampcode')

    def do_redeem_bitstampcode(self,args):
        """Redeem a Bitstamp code"""
        """usage: redeem_bitstampcode code"""
        try:
            bitstamp.redeem_bitstampcode(args)
        except:
            print "Incorrect Usage. Invalid args given."
            self.onecmd('help redeem_bitstampcode')

    def do_send_touser(self,customer_id,currency,amount):
        """Send funds to a customerID"""
        """usage: send_touser customerID currency amount"""
        try:
            bitstamp.send_touser(customer_id,currency,amount)
        except:
            print "Incorrect Usage. Invalid args given."
            self.onecmd('help send_touser')

    def do_withdrawal_requests(self,args):
        """Just print a list of all withdrawal requests"""
        try:
            ppdict(bitstamp.withdrawal_requests())
        except Exception as e:
            print "Unexpected Error: %s" % e
            self.onecmd('help withdrawal_requests')
#
#####################################################################


#For testing thread activity only. REMOVE.
    def do_fakethread(self,args):
        """Fake thread for testing"""
        def ft(firstarg,fakethread_stop,btc,usd):
            while(not fakethread_stop.is_set()):
                print "THIS IS A FAKE THREAD!!!!!!"
                fakethread_stop.wait(3)

        global fakethread_stop
        btc,usd = bal()
        args = stripoffensive(args)
        args = args.split()
        if 'exit' in args:
            print "Shutting down background thread..."
            fakethread_stop.set()
        else:   
            fakethread_stop = threading.Event()
            threadlist["fakethread"] = fakethread_stop
            fake_thread = threading.Thread(target = ft, args=(None,fakethread_stop,btc,usd))
            fake_thread.daemon = True
            fake_thread.start()


    def do_fee(self,args):
        """Checks your 30 day volume and prints your fee, and how far you are from the next tier"""
        totalamount,fee,howmanyto,nexttier = bitstamp.fee_schedule()
        print "Your 30 day volume is: %.5f. Your trade fee is: %.2f%%" % (totalamount,fee)
        print "You are $%s away from the next tier of: $%s" % (howmanyto,nexttier)


    def do_gethistory(self,args):
    #Very rough. pretty print it 
        """Prints out your user transactions in the past [timdelta]"""
        history=bitstamp.get_usertransactions()
        ppdict(history)


    def do_getaddress(self,args):
        """Find out your bitcoin deposit address"""
        ppdict(bitstamp.get_depositaddress())

######################################

    def do_checkmarketbuy(self, args):
        """Dummy Simulation. working on new market trade buy function\n"""\
        """usage: checkmarketbuy <amount> <lowprice> <highprice>"""
        entirebook = refreshbook()
        try:
            args = args.split()
            newargs = tuple(decimalify(args))
            side = entirebook.asks
            markettrade(side,'buy',*newargs)
        except Exception as e:
            traceback.print_exc()
            print "Invalid args given. Proper use is: "
            self.onecmd('help checkmarketbuy')

    def do_checkmarketsell(self, args):
        """Dummy Simulation. working on new market trade sell function\n"""\
        """usage: checkmarketsell <amount> <lowprice> <highprice>"""
        entirebook = refreshbook()
        try:
            args = args.split()
            newargs = tuple(decimalify(args))
            side = entirebook.bids
            side.reverse()
            markettrade(side,'sell',*newargs)    
        except Exception as e:
            traceback.print_exc()
            print "Invalid args given. Proper use is: "
            self.onecmd('help checkmarketsell')

###################################### 


    def do_orders(self,args):
        """Print a list of all your open orders"""
        try:
            orders = bitstamp.open_orders()
            orders = sorted(orders, key=lambda x: float(x['price']))
            buytotal,selltotal = 0,0
            numbuys,numsells = 0,0
            amtbuys,amtsells = 0,0
            buyavg,sellavg = 0,0
            numorder = 0        
            for order in orders:
                ordertype="Sell" if order['type'] == 1 else "Buy"
                numorder += 1
                print '%s = %s | $%s @ %s BTC %s' % (numorder,ordertype,order['price'],order['amount'],order['id'])              
                if order['type'] == 0:
                    buytotal += D(order['price'])*D(order['amount'])
                    numbuys += D('1')
                    amtbuys += D(order['amount'])
                elif order['type'] == 1:
                    selltotal += D(order['price'])*D(order['amount'])
                    numsells += D('1')
                    amtsells += D(order['amount'])
            if amtbuys:
                buyavg = D(buytotal/amtbuys).quantize(cPrec)
            if amtsells:
                sellavg = D(selltotal/amtsells).quantize(cPrec)
            print "There are %s Buys. There are %s Sells" % (numbuys,numsells)
            print "Avg Buy Price: $%s. Avg Sell Price: $%s" % (buyavg,sellavg)
        except Exception as e:
            print e

######################################
#coded for but not tested on bitstamp.
    def do_sellwhileaway(self,args):
        """#coded for but not tested on bitstamp."""
        """Check balance every 60 seconds for <amount> and once we have received it, sell! But only for more than <price>.\n""" \
        """Usage: sellwhileaway <amount> <price>"""
        args = args.split()
        amount,price = tuple(decimalify(args))
        #seed initial balance data so we can check it during first run of the while loop
        balance = decimalify(bitstamp.accounts())
        #seed the last price just in case we have the money already and the while loop never triggers
        last = D(bitstamp.ticker()['price'])
        while btc < amount:
            btc,usd = bal()
            last = D(bitstamp.ticker()['last'])
            print 'Your balance is %.8f BTC and $%.2f USD ' % (btc,usd)
            print 'Account Value: $%.2f @ Last BTC Price of $%.2f' % (btc*last+usd,last)
            time.sleep(60)
        while btc > 6:
            if last > price+3:
                bitstamp.cancel_all()
                spread('bitstamp',bitstamp,1,5,last,last,1)
            if last > price:
                if balance > 5:
                    bitstamp.cancel_all()
                    spread('bitstamp',bitstamp,1,5,price,last+1,3)
            if price > last:
                if balance > 5 and price-last < 3:
                    bitstamp.cancel_all()
                    spread('bitstamp',bitstamp,1,5,last,price,2)

            time.sleep(45)
            last = D(bitstamp.ticker()['last'])
            btc,usd = bal()


    def do_sellwhileaway2(self,args):
        """#coded for but not tested on bitstamp."""
        """Check balance every 60 seconds for <amount> and once we have received it, sell! But only for more than <price>.\n""" \
        """Usage: sellwhileaway2 <amount> <price>"""
        try:
            args = args.split()
            amount,price = tuple(decimalify(args))
            #seed initial balance data so we can check it during first run of the while loop
            btc,usd = bal()
            #seed the last price just in case we have the money already and the while loop never triggers
            last = D(bitstamp.ticker()['last'])
            while btc < amount:
                btc,usd = bal()
                last = D(bitstamp.ticker()['last'])
                print 'Your balance is %.8f BTC and $%.2f USD ' % (btc,usd)
                print 'Account Value: $%.2f @ Last BTC Price of $%.2f' % (btc*last+usd,last)
                time.sleep(60)
            sold=False
            while sold==False:
                if last > price:
                    bitstamp.cancel_all()
                    result = spread('bitstamp',bitstamp,1,btc,last,last+1,2)
                    if result:
                        sold = True
                else:
                    bitstamp.cancel_all()
                    spread('bitstamp',bitstamp,1,btc,((last+price)/2)+0.5,price,2)
                    if result: 
                        sold = True
                time.sleep(45)
                last = D(bitstamp.ticker()['last'])
                btc,usd = bal()
        except:
            print "Retrying:"
            self.onecmd(self.do_sellwhileaway2(amount,price))

######################################


    def do_spread(self,args):
        """Print out the bid/ask spread"""
        try:
            entirebook = refreshbook()
            print "Lowest ask is: $%f"  % entirebook.asks[0][0]
            print "Highest Bid is: $%f" % entirebook.bids[0][0]
            print "The spread is: $%f" % (entirebook.asks[0][0] - entirebook.bids[0][0])
        except Exception as e:
            print "Unexpected Error: %s" % e
            self.onecmd('help spread')


    def do_ticker(self,args):
        """Print the entire ticker out or use one of the following options:\n""" \
        """usage: ticker [bid|ask|last|volume|low|high]"""
        args = stripoffensive(args)
        ticker = floatify(bitstamp.ticker())
        last = ticker['last']
        low,high,vol = ticker['low'],ticker['high'],ticker['volume']
        bid,ask = ticker['bid'],ticker['ask']
        if not args:
            print "BTCUSD ticker | Best bid: %.2f, Best ask: %.2f, Bid-ask spread: %.2f, Last trade: %.2f, " \
                "24 hour volume: %d, 24 hour low: %.2f, 24 hour high: %.2f" % (bid,ask,ask-bid,last,vol,low,high)
        else:
            try:
                print "BTCUSD ticker | %s = %s" % (args,ticker[args])
            except:
                print "Invalid args. Expecting a valid ticker subkey."
                self.onecmd('help ticker')


    def do_tradehist24(self,args):
        """Download the entire trading history of bitstamp for the past 24 hours. Write it to a file"""
        try:
            print "Starting to download entire trade history from bitstamp....",
            eth = bitstamp.get_transactions(86400)
            with open(os.path.join(partialpath + 'bitstamp_entiretrades.txt'),'w') as f:
                depthvintage = str(time.time())
                f.write(depthvintage)
                f.write('\n')
                json.dump(eth,f)
                f.close()
                print "Finished."
        except Exception as e:
            print "Unexpected Error: %s" % e
            self.onecmd('help tradehist24')


    def do_withdraw(self,args):
        """Withdraw Bitcoins to an address"""
        try:
            address = raw_input("Enter the address you want to withdraw to: ")
            totalbalance = prompt("Do you want to withdraw your ENTIRE balance?",False)
            if totalbalance == False:
                amount = D(raw_input("Enter the amount of BTC to withdraw: "))
            else:
                amount,_ = bal()
            
            result = bitstamp.bitcoin_withdraw(address,amount)
            if result:
                print "%s BTC successfully sent to %s" % (amount,address)
            else:
                print "There was an error withdrawing."
        except Exception as e:
            traceback.print_exc()
            print "Unexpected Error: %s" % e
            self.onecmd('help withdraw')

######################################
#exit out if Ctrl+Z is pressed
    def do_exit(self,args):      #standard way to exit
        """Exits the program"""
        print "\n"
        print "Session Terminating......."
        print "Exiting......"           
        return True

    def do_EOF(self,args):        #exit out if Ctrl+Z is pressed
        """Exits the program"""
        return self.do_exit(args)

    def help_help(self):
        print 'Prints the help screen'

######################################
if __name__ == '__main__':
    Shell().cmdloop()