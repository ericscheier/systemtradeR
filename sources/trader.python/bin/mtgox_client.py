#!/usr/bin/env python
# Created by genBTC 3/10/2013 Updated 4/20/2013 
# mtgox_client.py
# Universal Client for all things mtgox
# A complete command line Client with a menu
# Functionality _should_ be listed in README (functions in alpahabetical order)

import sys
import cmd
import time
import json
import traceback
import threading        #for subthreads
import datetime
from decimal import Decimal as D    #renamed to D for simplicity.
import os
import logging
import csv
import sys
if os.name == 'nt':
    import winsound         #plays beeps for alerts 
    import pyreadline
    import commandhistory   #enable command line completion and command history

from book import *
from common import *
import depthparser
import mtgox_prof7bitapi
import mtgoxhmac

mtgox = mtgoxhmac.Client()

bPrec = mtgox.bPrec
cPrec = mtgox.cPrec

threadlist = {}
whenlist = []

class LogWriter():
    """connects to gox.signal_debug and logs it all to the logfile"""
    def __init__(self, gox):
        self.gox = gox
        logging.basicConfig(filename='goxclient.log'
                           ,filemode='a'
                           ,format='%(asctime)s:%(levelname)s %(message)s'
                           ,level=logging.DEBUG
                           )
        console_logger = logging.getLogger('')
        console = logging.StreamHandler()
        console.setLevel(logging.INFO)
        console_logger.addHandler(console)        
        self.gox.signal_debug.connect(self.slot_debug)

    def close(self):
        """stop logging"""
        #not needed
        pass

    # pylint: disable=R0201
    def slot_debug(self, sender, (msg)):
        """handler for signal_debug signals"""
        if "https://data.mtgox.com/api/2/money/order/lag" in msg:
            return
        else:
            logging.debug("%s:%s", sender.__class__.__name__, msg)       #change this to .info to see the messages on screen.


config = mtgox_prof7bitapi.GoxConfig()
secret = mtgox_prof7bitapi.Secret()
secret.decrypt(mtgox.enc_password)
gox = mtgox_prof7bitapi.Gox(secret, config)
logwriter = LogWriter(gox)
logging.debug("### Initializing the mtgox_client.")
gox.start()
socketbook = gox.orderbook
def request_socketbook():
    if not socketbook.fulldepth_time == 0:
        fdtdelta = str(time.time() - socketbook.fulldepth_time)+" ago."
    else:
        fdtdelta = "never."
    print "Starting to download fulldepth from MtGox. (Last updated: %s)...." % (fdtdelta),
    while socketbook.fulldepth_downloaded == False:
        time.sleep(0.1)
    print "Finished."
request_socketbook()


# data partial path directory
fullpath = os.path.dirname(os.path.realpath(__file__))
if ".exe" in sys.argv[0]:
    partialpath=os.path.join(fullpath + '\\data\\')
elif os.name == 'nt':
    partialpath=os.path.join(fullpath + '\\..\\data\\')
else:
    partialpath=os.path.join(fullpath + '/../data/')


"""
def decideto():
  #experimental, not working yet. Decide to sell or buy based on the ticker.

"""


def refreshbook(maxage=180):
    #get the FULL depth (current trade order) (API 2,gzip)
    depthvintage,fulldepth = updatedepthdata(mtgox,maxage)
    entirebook = Book.parse(fulldepth["data"],goxfulldepth=True)
    entirebook.sort()      #sort it
    return entirebook
def printorderbookapi0(length=15):
    entirebook = Book.parse(mtgox.get_depth())
    entirebook.sort()
    #start printing part of the order book (first 15 asks and 15 bids)
    printbothbooks(entirebook.asks,entirebook.bids,length)   #otherwise use the length from the arguments
def bal():
    balance = mtgox.get_balance()
    btcbalance = D(balance['btcs'])
    usdbalance = D(balance['usds'])
    return btcbalance,usdbalance
def get_tradefee():
    return (D(mtgox.get_info()['Trade_Fee'])/100)
def calc_fees(amount,feerate):
    last = D(mtgox.get_tickerfast()['last']['value'])
    totalfees = amount * feerate * last
    return totalfees,last
def print_calcedfees(amount,last,totalfees):
    print '%f BTC worth $%.2f USD Value total' % (amount,amount*last)
    print 'Total Fees are $%.5f USD @ $%.5f per BTC' % (totalfees,last)

class Feesubroutine(cmd.Cmd):
    def emptyline(self): 
        pass                    #do nothing on a blank line.

    def __init__(self):
        cmd.Cmd.__init__(self)
        # The prompt for a new user input command
        self.prompt = 'Fees> '
        self.doc_header = "Type back to go back."
        self.onecmd('help')
        self.feerate = get_tradefee()
        self.onecmd('getfee')
        
    def do_getfee(self,args):
        """Print out the current trade fee"""
        print "Your current trading fee is: {:.2%}".format(self.feerate)
    def do_price(self,price):
        """Calculate the price you need to break even"""
        """Usage: price <price>"""
        try:
            if not(price):
                price = raw_input("Enter the price: ")
            price = D(str(price))
            print "Was this your buy price or your sell price?"
            buysell = prompt("YES = buy / no = sell ",True)
            if buysell:
                print "The minimum sell price is: $%.5f" % (price*(1+self.feerate)*(1+self.feerate))
            else:
                print "The maximum buy price is: $%.5f" % (price/(1+self.feerate)/(1+self.feerate))

        except Exception as e: 
            self.onecmd('help price')
            print "Invalid Args. Expected: <price>"

    def do_balance(self,args):
        """Calculate how much fees will cost if you sold off your entire BTC Balance"""
        btcbalance,_ = bal()
        totalfees,last = calc_fees(btcbalance,self.feerate)
        print_calcedfees(btcbalance,last,totalfees)
    def do_btc(self,amount):
        """Calculate how much fees will cost on X amount BTC\n""" \
        """Give BTC_amount as a paramter ie: calc 5.3513"""
        try:
            if not(amount):
                amount = raw_input("Enter the amount in BTC you want to calculate the fee of: ")
            amount = D(str(amount))
            totalfees,last = calc_fees(amount,self.feerate)
            print_calcedfees(amount,last,totalfees)
        except Exception as e: 
            self.onecmd('help amount')
            print "Invalid Args. Expected: <amount>"
    def do_back(self,args):
        """Exits out of the fee menu and goes back to the main level"""
        print '\nGoing back a level...'
        return True
    def do_exit(self,args):
        """Exits out of the fee menu and goes back to the main level"""
        print '\nReturning to the main level...'
        return True
    def do_EOF(self,args):
        """Exits out of the fee menu and goes back to the main level"""
        self.do_exit(self)
    def help_help(self):
        print 'Prints the help screen'

class Shell(cmd.Cmd):
    def emptyline(self): 
        self.onecmd('book')     #changed, so we are re-printing the orderbook on every blank press of ENTER.
        #pass                   #don't re-execute the last command
    def __init__(self):
        cmd.Cmd.__init__(self)
        self.prompt = 'MtGox> '      # The prompt for a new user input commands
        self.onecmd('help')             #print out the possible commands (help) on first run
        
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


    #start out by printing the order book (the new socket book)
    printOrderBooks(socketbook.asks,socketbook.bids,15)

    #give a little user interface       
    print 'To exit: exit,Ctrl+C,Ctrl+Z or Ctrl+Pause/Break to force quit'
    print 'Type help to show the available commands.'
    print "syntax: command subcommand <required> [optional] ['word']"

    def do_asks(self,args):
        """Calculate the amount of bitcoins for sale at or UNDER(default) the <targetprice>.\n""" \
        """If 'over' option is given, find coins or at or OVER(optional) the <targetprice>."""
        """usage: asks ['over'] <targetprice>"""
        #Using the Socketbook 

        args = stripoffensive(args)
        try:
            targetprice = float(args)
            response = 'under'
        except:
            try:
                response, targetprice = args.split()
                targetprice = float(targetprice)
            except:
                self.onecmd('help asks')
        if response == 'over':
            f = lambda price,targetprice: price*cPrec >= targetprice
        else:
            f = lambda price,targetprice: price*cPrec <= targetprice
        n_coins = D('0')
        total = D('0')

        for ask in reversed(socketbook.asks):
            if f(ask.price, targetprice):
                n_coins += ask.volume*bPrec
                total += (ask.volume*bPrec * ask.price*cPrec)
        print "There are %.11g BTC offered at or %s %s USD, worth $%.2f USD in total."  % (n_coins,response, targetprice, total)

    def do_bids(self,args):
        """Calculate the amount of bitcoin demanded at or OVER(default) the <targetprice> .\n""" \
        """If 'under' option is given, find coins or at or UNDER(optional) the <targetprice>"""
        """usage: bids ['under'] <targetprice>"""
        #Using the Socketbook 

        args = stripoffensive(args)
        try:
            targetprice = float(args)
            response = 'over'
        except:
            try:
                response, targetprice = args.split()
                targetprice = float(targetprice)
            except:
                self.onecmd('help bids')
        if response == 'under':
            f = lambda price,targetprice: price*cPrec <= targetprice
        else:
            f = lambda price,targetprice: price*cPrec >= targetprice
        n_coins = D('0')
        total = D('0')

        for bid in socketbook.bids:
            if f(bid.price, targetprice):
                n_coins += bid.volume*bPrec
                total += (bid.volume*bPrec * bid.price*cPrec)
        print "There are %.11g BTC demanded at or %s %s USD, worth $%.2f USD in total."  % (n_coins,response,targetprice, total)


    def do_balance(self,args):
        """Shows your current account balance and value of your portfolio based on last ticker price"""
        btc,usd = bal()
        last = D(mtgox.get_tickerfast()['last']['value'])
        print 'Your balance is %s BTC and $%.2f USD ' % (btc,usd)
        print 'Account Value: $%.2f @ Last BTC Price of $%s' % (btc*last+usd,last)


    def do_balancenotifier(self,args):
        """Check your balance every 30 seconds and BEEP and print something out when you receive the funds (either btc or usd)"""
        def bn(firstarg,notifier_stop,btc,usd):
            while(not notifier_stop.is_set()):
                btcnew,usdnew = bal()
                if btcnew > btc or usdnew > usd:
                    last = D(mtgox.get_tickerfast()['last']['value'])
                    print '\nBalance: %s BTC + $%s USD = $%.5f @ $%.5f (Last)' % (btcnew,usdnew,(btcnew*last)+usdnew,last)
                    for x in xrange(0,3):
                        if os.name == 'nt':
                            winsound.Beep(1200,1000)
                            winsound.Beep(1800,1000)
                        else:
                            print '\a\a'
                    btc,usd = btcnew,usdnew
                notifier_stop.wait(30)

        try:
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
        except Exception as e:
            traceback.print_exc()
            print "An error occurred."
            self.onecmd('help balancenotifier')


    def do_book(self,length):
        """Uses the constantly updated data from the websocket/socket.io depth/trades/ticker channels\n""" \
        """usage: book [length]"""
        try:
            vintage = (time.time() - socketbook.fulldepth_time)
            if vintage > 300:
                gox.client.request_fulldepth()
                request_socketbook()
            length = stripoffensive(length)
            length = int(length)

            printOrderBooks(socketbook.asks,socketbook.bids,length)
        except:
            printOrderBooks(socketbook.asks,socketbook.bids)

    def do_bookfull(self,length):
        """Downloads the API 2 Full Depth at most once every 3 minutes, then prints out the order book."""
        """usage: book [length]"""
        entirebook = refreshbook()
        try:
            length = stripoffensive(length)
            length = int(length)
            printbothbooks(entirebook.asks,entirebook.bids,length)
        except:
            printbothbooks(entirebook.asks,entirebook.bids,15)


    def do_bookgroup(self,args):
        """Group Order Book like on clarkmoody's by specified price increments (ie: 0.05, 1.00) """
        """Usage: bookgroup <minprice> <maxprice> <grouping>  (ie: bookgrouping 50 150 1)"""
        try:
            minprice,maxprice,grouping = decimalify(args.split())
        except:
            minprice = D(raw_input("Min Price: "))
            maxprice = D(raw_input("Max Price: "))
            grouping = D(raw_input("Price Grouping: "))
        askcumu = 0 ; bidcumu = 0
        totalaskcumu = 0; totalbidcumu = 0
        curprice = D(socketbook.ask*cPrec)
        curprice = curprice + (grouping - curprice % grouping)
        print "-"*20,"ASKS:","-"*20
        print "Price(USD)\t  Amount(BTC)\t\tSum(Total)"
        print "-"*45
        first = True
        for ask in socketbook.asks:
            price = D(ask.price*cPrec)
            volume = D(ask.volume*bPrec)
            if first == True:
                print "%10s\t%14s\t    (Current Ask)\n" % (price,volume)
                first = False
        
            if price <= maxprice + grouping:
                if price >= curprice:
                    totalaskcumu += askcumu
                    print "%10s\t%14s\t%16s" % (curprice-grouping,askcumu,totalaskcumu)
                    curprice += grouping
                    askcumu = 0
        
            askcumu += volume
        totalaskcumu += askcumu
        if len(str(askcumu)) >= 14:
            askcumu = askcumu.quantize(D('0.001'))
        if len(str(totalaskcumu)) >= 14:
            totalaskcumu = totalaskcumu.quantize(D('0.001'))
        print "%10s+\t%14s\t%16s" % (curprice-grouping,askcumu,totalaskcumu) 

        curprice = D(socketbook.bid*cPrec)
        curprice = curprice - (curprice % grouping)
        print "-"*20,"BIDS:","-"*20
        print "Price(USD)\t  Amount(BTC)\t\tSum(Total)"
        print "-"*45
        first = True
        for bid in socketbook.bids:
            price = D(bid.price*cPrec)
            volume = D(bid.volume*bPrec)
            if first == True:
                print "%10s\t%14s\t    (Current Bid)\n" % (price,volume)
                first = False
        
            if price >= minprice - grouping:
                if price < curprice:
                    totalbidcumu += bidcumu
                    print "%10s\t%14s\t%16s" % (curprice,bidcumu,totalbidcumu)
                    curprice -= grouping
                    bidcumu = 0
        
            bidcumu += volume
        totalbidcumu += bidcumu
        if len(str(bidcumu)) > 14:
            bidcumu = bidcumu.quantize(D('0.001'))
        if len(str(totalbidcumu)) > 14:
            totalbidcumu = totalbidcumu.quantize(D('0.001'))        
        print "%10s-\t%14s\t%16s" % (curprice,bidcumu,totalbidcumu) 


    def do_bookrefresh(self,length):
        """Refresh a new copy of the entire order book and then run the 'book' command to print it."""
        gox.client.request_fulldepth()
        request_socketbook()
        self.onecmd('book')

    def do_bookquick(self,length):
        """Downloads a new API 0 getDepth each time, then prints out the order book."""
        """usage: book [length]"""
        try:
            length = stripoffensive(length)
            length = int(length)
            printorderbookapi0(length=length)
        except:
            printorderbookapi0(length=15)

    def readcsv(self,csvfile):
        spamreader = csv.reader(csvfile, delimiter=',', quotechar='"')
        fulllist = []
        firstrow = True
        for row in spamreader:
            if firstrow == True:
                keys = row
                firstrow = False
                continue
            eachlist = []
            itemdict = []
            listoflist = []
            for x in xrange(len(row)):
                onelist = [keys[x],row[x]]
                listoflist.append(onelist)
                fulldict = {x[0]:x[1] for x in listoflist}
            fulllist.append(fulldict)
        return fulllist
    def printbtc(self,amtbtcin,amtbtcout,valuein,valueout):
        print "Sum of all BTC bought is: %s BTC." % amtbtcin
        print "Sum of all BTC  sold  is: %s BTC." % amtbtcout
        print "Value of all BTC bought is: $ %s" % valuein
        print "Value of all BTC  sold  is: $ %s" % valueout
        #the follow doesn't print anything if amounts are 0 thus causing a divide by 0 exception
        try:
            vwapin = valuein / amtbtcin
            print "Avg(VWAP) price of Buys = ",
            print "$ %f." % vwapin
        except:
            pass
        try:
            vwapout = valueout / amtbtcout
            print "Avg(VWAP) price of Sells = ",
            print "$ %f" % vwapout
        except:
            pass

    def do_btchistory(self,args):
        """Prints out your entire history of BTC transactions.\n""" \
        """This wil have problems if history has anything other than USD/EUR"""
        filename = os.path.join(partialpath + 'mtgox_btchistory.csv')
        f = open(filename,'r+')
        download = prompt("Download a new history?",False)
        if download:
            btchistory=mtgox.get_history_btc()
            f.write(btchistory)
            print "Finished writing file."
        else:
            btchistory = f.read()
        f.close()
        print "%s" % btchistory
        csvfile = open(filename, 'rb')
        fulllist = self.readcsv(csvfile)

        allfees = D('0');  amtbtcin = D('0');  valuein = D('0');  amtbtcout = D('0'); valueout = D('0')
        for item in fulllist:
            if item["Type"] == "fee":
                onefee = D(item["Value"])
                allfees += onefee.quantize(bPrec)
            if item["Type"] == "in" or item["Type"] == "out":
                info = item["Info"]
                try:
                    price=D(info[info.find("$")+1:])
                except:
                    price=D(info[info.find("BTC at")+7:info.find("\xe2")-2])     #Written for Euros
                amount=D(item["Value"])
            if item["Type"] == "in":
                amtbtcin += amount
                valuein += D(price*amount).quantize(cPrec)
            if item["Type"] == "out":
                amtbtcout += amount
                valueout += D(price*amount).quantize(cPrec)
        print "Sum of all fees charged as BTC is: %s BTC." % allfees
        self.printbtc(amtbtcin,amtbtcout,valuein,valueout)
        rerun = True
        while prompt("Re-run again with a certain range?",False):
            allfees = D('0');  amtbtcin = D('0');  valuein = D('0');  amtbtcout = D('0'); valueout = D('0')
            therange = raw_input("Enter the numbers of the range, (ie 1571-1589) : ")
            therange = stripoffensive(therange,',-')
            therange = therange.split('-')
            for item in fulllist:
                if int(item["Index"]) >= int(therange[0]) and int(item["Index"]) <= int(therange[1]):
                    if item["Type"] == "in" or item["Type"] == "out":
                        info = item["Info"]
                        try:
                            price=D(info[info.find("$")+1:])
                        except:
                            price=D(info[info.find("BTC at")+7:info.find("\xe2")-2])    #Written for Euros
                        amount=D(item["Value"])
                    if item["Type"] == "in":
                        amtbtcin += amount
                        valuein += D(price*amount).quantize(cPrec)
                    if item["Type"] == "out":
                        amtbtcout += amount
                        valueout += D(price*amount).quantize(cPrec)
            self.printbtc(amtbtcin,amtbtcout,valuein,valueout)

    def do_usdhistory(self,args):
        """Prints out your entire trading history of USD transactions"""
        filename = os.path.join(partialpath + 'mtgox_usdhistory.csv')
        download = prompt("Download a new history?",False)
        f = open(filename,'r+')
        if download:
            usdhistory=mtgox.get_history_usd()
            f.write(usdhistory)
            print "Finished writing file."
        else:
            usdhistory = f.read()
        f.close()
        print "%s" % usdhistory
        csvfile = open(filename, 'rb')
        fulllist = self.readcsv(csvfile)

        allfees = D('0');        amtusdin = D('0');        amtusdout = D('0')
        for item in fulllist:
            if item["Type"] == "fee":
                onefee = D(item["Value"])
                allfees += onefee.quantize(cPrec)
            amount=D(item["Value"])
            if item["Type"] == "earned":
                amtusdin+=amount
            elif item["Type"] == "spent":
                amtusdout+=amount
        print "Sum of all fees is: $ %s USD." % allfees
        print "Sum of all usd earned is: $ %s USD." % amtusdin
        print "Sum of all usd spent  is: $ %s USD." % amtusdout


    def do_buy(self, args):
        """(market order): buy <#BTC> \n""" \
        """(limit  order): buy <#BTC> <price> \n""" \
        """(spend-X market order): buy usd <#USD>         \n(specify the $ amount in #USD, and use the last ticker price-market)\n"""\
        """(spend-X limit  order): buy usd <#USD> <price> \n(same as above, but specify a price so it goes as a limit order)\n"""\
        """(spread order): buy <volume> <price_lower> <price_upper> <chunks> ['random'] \n(random makes chunk amounts slightly different)\n"""\
        """ ^-adds a multitude of orders between price A and price B of equal volumed # of chunks on MtGox."""
        try:
            args = stripoffensive(args)
            args = args.split()
            newargs = tuple(decimalify(args))
            if "usd" in newargs:                                        #places an order of $X USD 
                newargs = list(newargs);newargs.remove("usd");newargs = tuple(newargs)#remove usd arg once found
                if len(newargs) == 1:                                  #for a market order
                    rate = D(mtgox.get_tickerfast()["sell"]["value"])    #use the opposite side's best price
                    amt = newargs[0] / rate
                    buyprice = None    
                elif len(newargs) == 2:                                  # or as a limit order  
                    buyprice = newargs[1]                           
                    amt = newargs[0] / buyprice                        #convert USD to BTC.
                newargs = (amt.quantize(bPrec),buyprice)         #get the arguments ready
            if len(newargs) in (1,2):
                result = mtgox.order_new('bid',*newargs)
                if result: print "Order ID is :",result["data"]
            elif len(newargs) >= 4:
                spread('mtgox',mtgox,'bid', *newargs)               #use spread logic
            else:
                raise UserError("Invalid args given!!! Proper use is:")
                self.onecmd('help buy')
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
        """ ^-adds a multitude of orders between price A and price B of equal volumed # of chunks on Mtgox."""
        try:
            args = stripoffensive(args)
            args = args.split()
            newargs = tuple(decimalify(args))
            if "usd" in newargs:                                        #places an order of $X USD 
                newargs = list(newargs);newargs.remove("usd");newargs = tuple(newargs)#remove usd arg once found
                if len(newargs) == 1:                                  #for a market order
                    rate = D(mtgox.get_tickerfast()["buy"]["value"])     #use the opposite side's best price
                    amt = newargs[0] / rate
                    sellprice = None    
                elif len(newargs) == 2:                                  #or as a limit order  
                    sellprice = newargs[1]                           
                    amt = newargs[0] / sellprice                        #convert USD to BTC.
                newargs = (amt.quantize(bPrec),sellprice)         #get the arguments ready
            if len(newargs) in (1,2):
                result = mtgox.order_new('ask',*newargs)
                if result: print "Order ID is :",result["data"]
            elif len(newargs) >= 4:
                spread('mtgox',mtgox,'ask', *newargs)               #use spread logic
            else:
                raise UserError("Invalid args given!!! Proper use is:")
                self.onecmd('help sell')
        except Exception as e:
            traceback.print_exc()
            print "Invalid args given!!! Proper use is:"
            self.onecmd('help sell')


    def do_cancel(self,args):
        """Cancel an order by number,ie: 7 or by range, ie: 10 - 25\n""" \
        """Use with arguments after the cancel command, or without to view the list and prompt you"""
        try:
            orders = mtgox.get_orders()['orders']
            orders = sorted(orders, key=lambda x: float(x['price']))
            if not orders:
                print "No Orders found!!"
                return
            numorder = 0
            numcancelled = 0            
            useargs = False
            if args:
                useargs = True
            else:
                for order in orders:
                    ordertype="Sell" if order['type'] == 1 else "Buy"
                    numorder += 1
                    if order['status'] == 1:
                        OPX = 'O'
                    elif order['status'] == 2:
                        OPX = 'P'
                    elif order['status'] == 0:
                        OPX = 'X'
                    else:
                        OPX = '|'
                    print '%3s = %4s %s $%9s @ %12s BTC %s' % (numorder,ordertype,OPX,order['price'],order['amount'],order['oid'])
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
                    if numcancelled >= 1:
                        print "%s Orders have been Cancelled!!!!!" % numcancelled
                    break
                orderlist = stripoffensive(orderlist,',-')
                if "," in orderlist:
                    orderlist = orderlist.split(',')
                elif '-' in orderlist:
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
                        for wid,when in enumerate(whenlist):
                            if 'oid' in when and when['oid'] == order['oid']:
                                when['stop'].set()
                                print 'Removed related order fulfill when command'
                                del whenlist[wid]
                        result = mtgox.cancel_one(order['oid'])
                        if result:
                            numcancelled += 1                        
        except Exception as e:
            print e

    def remove_orderfulfillwhen(self):
        for wid,when in enumerate(whenlist):
            if 'oid' in when:
                print 'Removed order fulfill when command'
                when['stop'].set()
                del whenlist[wid]

    def do_cancelall(self,args):
        """Cancel every single order you have on the books (uses HTTP)"""
        self.remove_orderfulfillwhen()
        mtgox.cancel_all()

    def do_cancelsells(self,args):
        """Cancel any/all Sell orders (uses the websocket)"""
        yes = gox.cancel_by_type("ask")
        if yes:
            print "Any Sell Orders Have Been Cancelled!"

    def do_cancelbuys(self,args):
        """Cancel any/all Buy orders (uses the websocket)""" 
        yes = gox.cancel_by_type("bid")
        if yes:
            print "Any Buy Orders Have Been Cancelled!"

    def do_cancelboth(self,args):
        """Cancel every order. (uses the websocket)""" 
        yes = gox.cancel_by_type()
        if yes:
            "Any Buy OR Sell Orders Have Been Cancelled"
            self.remove_orderfulfillwhen()

    # def do_cancelunfunded(self,args):
    #     """Removes any orders that are completely unfunded."""
    #     try:
    #         orders = mtgox.get_orders()['orders']
    #         orders = sorted(orders, key=lambda x: float(x['price']))
    #         if not orders:
    #             print "No Orders found!!"
    #             return
    #         numcancelled = 0
    #         for order in orders:
    #             if order['status'] == 0 and order['oid'][0] != 'X':         #if un-funded:
    #                 numcancelled += 1
    #                 cancelresult = mtgox.cancel_one(order['oid'])
    #                 if cancelresult.get("error"):
    #                     print "Cancelling Order Failed for some reason!"
    #         if numcancelled >= 1:
    #             print "%s Orders have been Cancelled!!!!!" % numcancelled
    
    #     except Exception as e:
    #         print e        

    def do_cancelhalffunded(self,args):
        """Fixes half-funded orders by removing the unfunded part and re-ordering the funded part"""
        try:
            orders = mtgox.get_orders()['orders']
            orders = sorted(orders, key=lambda x: float(x['price']))
            if not orders:
                print "No Orders found!!"
                return
            replaceorders = []
            numcancelled = 0
            everythingDone = False
            while everythingDone == False:
                for numorder,order in enumerate(orders):
                    if order['status'] == 0 and order['oid'][0] == 'X':        #if half-funded:
                        numcancelled += 1
                        ordertype="ask" if order['type'] == 1 else "bid"
                        canceloid = order['oid'][1:]
                        cancelresult = mtgox.cancel_one(canceloid)
                        if cancelresult.get("error"):
                            print "Cancelling Order Failed for some reason!"
                        else:
                            index = numorder+1 if ordertype == "ask" else numorder-1
                            replaceorders.append((ordertype,
                                orders[index]['amount'],orders[index]['price']))
                    else:
                        everythingDone = True
                for order in replaceorders:
                    orderresult = mtgox.order_new(order[0], D(order[1]), D(order[2]))
                    if orderresult:
                        if not(orderresult.get("error")):
                            print "Order ID is : %s" % orderresult["data"]
                        else:
                            print "Order was submitted but failed because: %s" % orderresult["error"]
                    else:
                        print "Order failed."
            if numcancelled >= 1:
                print "%s Orders have been Cancelled!!!!!" % numcancelled
    
        except Exception as e:
            print e        

    def do_depth(self,args):
        """Shortcut for the 2 depth functions in common.py\n""" \
        """usage: depth <sum/price> <bids/asks>"""
        try:
            args = stripoffensive(args)
            args = args.split()
            mydict = {"buy":socketbook.asks,"bids":socketbook.asks,"bid":socketbook.asks,"sell":socketbook.bids,"ask":socketbook.bids,"asks":socketbook.bids}
            for x in mydict.keys():
                if x in args:
                    args.remove(x)
                    whichbook = mydict[x]
            functlist = ["sum","range","price"]
            for x in functlist:
                if x in args:
                    args.remove(x)
                    newargs = tuple(decimalify(args))
                    func = x
            functdict = {"sum":depthsumrange,"range":depthsumrange,"price":depthprice}[func](whichbook,*newargs,ismtgox=True)
        except:
            print "Invalid args given. Proper use is:"
            self.onecmd('help depth')


    def do_fees(self,args):
        """Loads the fee module to calculate fees"""
        Feesubroutine().cmdloop()


    def do_getaddress(self,args):
        """Generate a new personal bitcoin deposit address for your MtGox account (needs deposit priveleges to work)"""
        mtgox.bitcoin_address()


    def do_lag(self,args):
        """Shows the current Mt.Gox trading engine lag time"""
        lag = mtgox.lag()
        print "Current order lag is %r seconds. Queue length is: %s" % (lag['lag_secs'],lag['length'])

    
    def do_obip(self, args):
        """Calculate the "order book implied price", by finding the weighted\n""" \
        """average price of coins <width> BTC up and down from the spread.\n""" \
        """Order book implied price. Weighted avg price of BTC <width> up and down from the spread.\n""" \
        """Usage: obip <width> [BTC/USD] \n"""
        def obip(amount,isBTCUSD="BTC"):
            def calc_obip(depth,amount,isBTCUSD="BTC"):
                totalBTC = 0;  totalprice = 0
                if isBTCUSD.upper()=="BTC":
                    for x in depth:
                        if totalBTC < amount:
                            totalBTC+=(x.volume*bPrec)
                            totalprice+=(x.price * x.volume) * (cPrec*bPrec)
                            if totalBTC >= amount:
                                totalprice-=(totalBTC-amount) * (x.price*cPrec)
                                totalBTC=amount
                                break
                else:
                    for x in depth:
                        if totalprice < amount:
                            totalBTC+=(x.volume*bPrec)
                            totalprice+=(x.price * x.volume) * (cPrec*bPrec)
                            if totalprice >= amount:
                                overBTC = (totalprice-amount) / (x.price*cPrec)
                                totalBTC -= overBTC
                                totalprice -= (x.price*cPrec) * overBTC
                                break
                obip=(totalprice/totalBTC)
                return float(obip),float(totalBTC)
            amount = D(amount)
            obips,sbtc = calc_obip(socketbook.asks,amount,isBTCUSD)
            obipb,bbtc = calc_obip(socketbook.bids,amount,isBTCUSD)
            obip = (obips+obipb)/2.0
            if isBTCUSD.upper()=='USD':
                print "%s BTC on asks side. %s BTC on bids side." % (sbtc,bbtc)
            print "The ask side OBIP was: $%.5f. The bid side OBIP was: $%.5f" % (obips,obipb)
            print "The OBIP(vwap) %s %s up and down from the spread is: $%.5f USD." % (amount,isBTCUSD,obip)

        args = stripoffensive(args)
        args = args.split()
        newargs = tuple(args)
        obip(*newargs)


    def do_orders(self,args):
        """Print a list of all your open orders, including pending and lacking enough funds"""
        try:
            args = stripoffensive(args)
            orders = mtgox.get_orders()['orders']
            orders = sorted(orders, key=lambda x: float(x['price']))
            buytotal,selltotal = 0,0
            numbuys,numsells = 0,0
            amtbuys,amtsells = 0,0
            buyavg,sellavg = 0,0
            numorder = 0
            for order in orders:
                ordertype="Sell" if order['type'] == 1 else "Buy"
                numorder += 1
                if order['status'] == 1:
                    OPX = 'O'
                elif order['status'] == 2:
                    OPX = 'P'
                elif order['status'] == 0:
                    OPX = 'X'
                else:
                    OPX = '|'
                print '%3s = %4s %s $%9s @ %12s BTC %s' % (numorder,ordertype,OPX,order['price'],order['amount'],order['oid'])
                if order['type'] == 2:
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
            print "%s BTC in all Buys. %s BTC in all Sells." % (amtbuys,amtsells)
        except Exception as e:
            print e


    def do_readtickerlog(self,numlines=15):
        """Prints the last X lines of the mtgox ticker log file"""
        """Usage: readtickerlog <numlines>"""
        try:
            numlines = stripoffensive(numlines)
            numlines = int(numlines)
            with open(os.path.join(partialpath + 'mtgox_ticker.txt'),'r') as f:
                s = tail(f,numlines)
            print s
            l = s.splitlines()
            for x in l: pass
            j = json.loads(x)
            tickertime = j['time']
            print "Last ticker was:",datetime.datetime.fromtimestamp(tickertime).strftime("%Y-%m-%d %H:%M:%S")
            print "Current time is:",datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        except ValueError as e:
            self.onecmd('help readtickerlog')


    def do_readtradehist24h(self,args):
        """reading trade history data from a file and gathering stats on it"""
        import tradehistory
        filetype = prompt("Is this a Trade History file (not a full depth file)?",True)
        if filetype:
            tradehistory.readhist24()
        else:
            tradehistory.readdepth()


    def do_spread(self,args):
        """Print out the bid/ask spread"""
        try:
            print "High Bid is: $", socketbook.bid*cPrec
            print "Low ask is: $", socketbook.ask*cPrec
            print "The spread is: $", (socketbook.ask - socketbook.bid)*cPrec
        except:
            self.onecmd('help spread')


    def do_stoploss(self,args):
      #Finished. Works.
        """Usage: stoploss <amount of position> <avg position price> <percent willing to accept>\n""" \
        """   ie: stoploss 13.88512098 136.50 95"""
        def stoplossbot(firstarg,stop_event,amount,price,percent):
            try:
                found = False
                percent = percent / D('100')
                while(not stop_event.is_set()):
                    last = D(socketbook.ask)*cPrec
                    if last < price*percent:
                        order = mtgox.order_new('ask',amount,protection=False)
                        lag = gox.order_lag/1E6
                        while found == False:
                            stop_event.wait(lag)
                            response = mtgox.get_ask_history(order['data'])
                            if not(response["result"] == "error"):
                                found = True
                        avgprice = response['return']['avg_cost']['display']
                        print "\n%s Sold with stop-loss @of c %s\n" % (order['data'],avgprice)
                        stop_event.set()
                    stop_event.wait(2)
            except Exception as e:
                try:    #DEBUGGING ONLY
                    print "Order was: ", order, "Result was: ", result
                except:
                    traceback.print_exc()
                    print "An error occurred."
                    self.onecmd('help stoploss')

        try:
            global stopbot_stop
            args = stripoffensive(args)
            args = args.split()
            newargs = tuple(decimalify(args))
            if 'exit' in args:
                print "Shutting down background thread..."
                stopbot_stop.set()
            else:
                stopbot_stop = threading.Event()
                threadlist["stopbot"] = stopbot_stop
                args = (None,stopbot_stop) + newargs
                stopbot_thread = threading.Thread(target = stoplossbot, args=args)
                stopbot_thread.daemon = True
                stopbot_thread.start()
        except Exception as e:
            traceback.print_exc()
            print "An error occurred."
            self.onecmd('help stoploss')


    def do_ticker(self,arg):
        """Print the entire ticker out or use one of the following options:\n""" \
        """usage: ticker [buy|sell|last|high|low|vol|vwap|avg] """
        ticker = mtgox.get_ticker()
        if not arg:
            print "BTCUSD ticker | Best bid: %s, Best ask: %s, Bid-ask spread: %.5f, Last trade: %s, " \
                "24 hour volume: %s, 24 hour low: %s, 24 hour high: %s, 24 hour vwap: %s, 24 hour avg: %s" % \
                (ticker['buy'], ticker['sell'], \
                D(ticker['sell']) - D(ticker['buy']), \
                ticker['last'], ticker['vol'], \
                ticker['low'], ticker['high'], \
                ticker['vwap'],ticker['avg'])
        else:
            try:
                print "BTCUSD ticker | %s = %s" % (arg,ticker[arg])
            except:
                print "Invalid args. Expecting a valid ticker subkey."
                self.onecmd('help ticker')

    def do_ticker2(self,args):
        """Print the entire ticker out or use one of the following options:\n""" \
        """usage: ticker2 [buy|sell|last|high|low|vol|vwap|avg] """
        args = stripoffensive(args)
        ticker = mtgox.get_ticker2()
        svrtime = D(int(ticker["now"]) / 1E6).quantize(D("0.001"))
        if not args:
            print "BTCUSD ticker | Best bid: %s, Best ask: %s, Bid-ask spread: %.5f, Last trade: %s, " \
                "24 hour volume: %s, 24 hour low: %s, 24 hour high: %s, 24 hour vwap: %s, 24 hour avg: %s" % \
                (ticker['buy']['value'], ticker['sell']['value'], \
                D(ticker['sell']['value']) - D(ticker['buy']['value']), \
                ticker['last']['value'], ticker['vol']['value'], \
                ticker['low']['value'], ticker['high']['value'], \
                ticker['vwap']['value'],ticker['avg']['value'])
            print "Time of ticker: ", datetime.datetime.fromtimestamp(svrtime).strftime("%Y-%m-%d %H:%M:%S"), "Ticker Lag: %.3f" % (D(time.time())-svrtime)
        else:
            try:
                print "BTCUSD ticker | %s = %s" % (args,ticker[args])
            except:
                print "Invalid args. Expecting a valid ticker subkey."
                self.onecmd('help ticker2')

    def do_tickerfast(self,args):
        """Always has the best data. The daily data like high/low/vol/vwap/avg is only available in ticker2\n""" \
        """usage: tickerfast [buy|sell|last] """
        args = stripoffensive(args)
        ticker = mtgox.get_tickerfast()
        svrtime = D(int(ticker["now"]) / 1E6).quantize(D("0.001"))
        if not args:
            print "BTCUSD ticker | Best bid: %s, Best ask: %s, Bid-ask spread: %.5f, Last trade: %s, "  % \
                (ticker['buy']['value'], ticker['sell']['value'], \
                D(ticker['sell']['value']) - D(ticker['buy']['value']), \
                ticker['last']['value'])
            print "Time of ticker: ", datetime.datetime.fromtimestamp(svrtime).strftime("%Y-%m-%d %H:%M:%S"), "Ticker Lag: %.3f" % (D(time.time())-svrtime)
        else:
            try:
                print "BTCUSD ticker | %s = %s" % (args,ticker[args])
            except:
                print "Invalid args. Expecting a valid ticker subkey."
                self.onecmd('help tickerfast')


    def do_tradehist24h(self,args):
        """Download the entire trading history of mtgox for the past 24 hours. Write it to a file"""
        print "Starting to download entire trade history from mtgox....",
        eth = mtgox.entire_trade_history()
        filename = os.path.join(partialpath + 'mtgox_entiretrades.txt')
        with open(filename,'w') as f:
            depthvintage = str(time.time())
            f.write(depthvintage)
            f.write('\n')
            json.dump(eth,f)
            f.close()
            print "Finished."


    def do_updown(self,args):
        """Logs ticker to file, spits out an alert and beeps if last price is above or below the range given\n""" \
        """Range window is modified and readjusted\n""" \
        """NOTE: RUNS AS A BACKGROUND PROCESS!!!!!!\n""" \
        """usage: updown <low> <high>\n""" \
        """Shutdown: updown exit  """
        def tickeralert(firstarg,tickeralert_stop):
            try:
                low, high = floatify(args.split())
            except Exception as e:
                print "You need to give a high and low range: low high"
            #Log lastprice to the ticker log file
            with open(os.path.join(partialpath + 'mtgox_ticker.txt'),'a') as f:
                while(not tickeralert_stop.is_set()):
                    ticker = mtgox.get_tickerfast()
                    last = float(ticker['last']['value'])
                    text = json.dumps({"time":time.time(),"lastprice":last})
                    f.write(text)
                    f.write("\n")
                    f.flush()
                    if last > low and last < high:
                        #last falls between given variance range, keep tracking
                        pass
                    elif last >= high:
                        print "ALERT!! Ticker has risen above range %s-%s. Price is now: %s" % (low,high,last)
                        for x in range(2,25):           #ascending beeps
                            if os.name == 'nt':
                                winsound.Beep(x*100,90)  #frequency(Hz),duration(ms)
                            else:
                                print '\a\a\a\a\a\a'     #ascii beeps
                        low = high - 0.5
                        high = low + 3
                        #decideto()
                        #lowsell = low*(1+txfee*2)
                        #spread('mtgox',mtgox,'sell', 1, lowsell, lowsell+1, 3)
                        print "New range is: %s-%s" % (low,high)
                    elif last == low or last == high:
                        print "ALERT!! Ticker is exactly on the boundary of %s" % (last)
                    else:
                        print "ALERT!! Ticker has fallen below range %s-%s. Price is now: %s" % (low,high,last)
                        for x in range(25,2,-1):        #descending beeps
                            if os.name == 'nt':
                                winsound.Beep(x*100,90)  #frequency(Hz),duration(ms)
                            else:
                                print '\a\a\a\a\a\a'    #ascii beeps
                        high = low + 1
                        low = high -3
                        #decideto()
                        #spread('mtgox',mtgox,'buy', 1, low+1, high-1, 5)
                        print "New range is: %s-%s" % (low,high)
                    tickeralert_stop.wait(40)

        try:
            global tickeralert_stop
            args = stripoffensive(args)
            if args == 'exit':
                print "Shutting down background thread..."
                tickeralert_stop.set()
            else:
                tickeralert_stop = threading.Event()
                threadlist["tickeralert"] = tickeralert_stop
                tickeralert_thread = threading.Thread(target = tickeralert, args=(None,tickeralert_stop))
                tickeralert_thread.daemon = True
                tickeralert_thread.start()
        except Exception as e:
            traceback.print_exc()
            print "An error occurred."
            self.onecmd('help updown')


    def do_when(self, args):
        """when <ask|bid|last> (<|>) (#USD) <command> (any command can be used e.g. buy <#BTC> <price>)\n""" \
        """when fulfill <#OID> <command> (command as above)\n""" \
        """when cancel (#WhenID) - cancel one, or without WhenID, cancel all. \n"""
    
        #dependent test function 1 
        def test_askbidlast(askbidlast,oper,usd,*args):
            breach = False; value = None; message = ""
            ticker = {"ask":socketbook.ask*cPrec,"bid":socketbook.bid*cPrec,"last":socketbook.last_trade.price*cPrec}
            usd = D(usd)
            value = D(ticker[askbidlast])
            if (oper == '<' and value < usd) or (oper == '>' and value > usd): 
                breach = True
            command = ' '.join(args)
            if breach:
                message = "Ticker breach: %s %s %s %s, Dependent action Executing %s" % (askbidlast,value,oper,usd,command)
            return (breach,command,message)

        #dependent test function 2
        def test_fulfill(fulfill,oid,*args):
            breach = True; message = ""
            whenlist[wid]['oid'] = oid
            orders = mtgox.get_orders()['orders']
            orders = sorted(orders, key=lambda x: float(x['price']))
            for order in orders:
                if oid == order['oid']:
                    breach = False
            command = ' '.join(args)
            if breach:
                message = "Order fulfilled: %s, Dependent action Executing %s" % (oid,command)
            return (breach,command,message)

        #cancel one or all "when"s
        def when_cancel(whenlist,wid=None):
            for cwid,when in enumerate(whenlist):
                if cwid == wid or wid == None:
                    print 'Cancelled: %d: %s' % (cwid, when['command'])
                    when['stop'].set()
                    del whenlist[cwid]

        #thread function
        def when_bot(firstarg,wid,stop_event,test,delay,*args):
            try:
                while not stop_event.is_set():
                    (breach, command,message) = test(*args)
                    if breach:
                        print message
                        self.onecmd(command)
                        stop_event.set()
                    if not stop_event.is_set():
                        stop_event.wait(delay)

            except Exception as e:
                #Should not happen.
                traceback.print_exc()
                print "An error occurred in the thread."
                self.onecmd('help when')

            #once it completes, delete itself.
            when_cancel(whenlist,wid)


        #main function body
        try:
            added = False
            global when_stop
            args = stripoffensive(args,"<>\-")      #clean input
            args = args.split()
            if len(args) == 0:
                #List any existing "when"s
                for wid,when in enumerate(whenlist):
                    print '%d: %s' % (wid, when['command'])
            elif 'exit' in args[0] or 'cancel' in args[0] and len(args) == 1:
                #Cancel ALL "when"s
                when_cancel(whenlist)
            elif 'cancel' in args[0] and len(args) == 2:
                #Cancel ONE "when"
                when_cancel(whenlist,int(args[1]))
            else:
                #OK, add new "when"
                if args[0] in ('ask','bid','last'):
                    test = test_askbidlast
                    delay = 2
                elif args[0] in ('fulfil','fulfill'): 
                    test = test_fulfill
                    delay = 30
                else:
                    print "Error: Invalid when command."
                    return
                # prepare thread
                whenbot_stop = threading.Event()
                threadlist["whenbot"] = whenbot_stop
                wid = len(whenlist)
                targs = (None,wid,whenbot_stop,test,delay) + tuple(args)
                when_thread = threading.Thread(target = when_bot, args=targs)
                when_thread.daemon = True
                #add command to whenlist
                whenlist.append({
                    'command': ' '.join(args),
                    'tid': when_thread,
                    'stop': whenbot_stop
                })
                added = True
                #run command one time to check if already breached
                (breach,command,message) = test(*args)
                if breach:
                    print 'Error: Dependency is already breached! (or order not found)' 
                    anyway = prompt("Execute command anyway?",False)
                    if anyway:
                        self.onecmd(command)
                    else:
                        when_cancel(whenlist,len(whenlist)-1)   #remove last when item
                else:
                    #OK, start the new thread, for the new "when"
                    when_thread.start()
                added = False

        except Exception as e:
            if added == True:
                when_cancel(whenlist,len(whenlist)-1)     #remove last when item
            #Shouldn't happen. Safety net.
            traceback.print_exc()
            print "An unknown error occurred."
            self.onecmd('help when')

    def do_withdraw(self,args):
        """Withdraw Bitcoins to an address (needs withdraw priveleges to work)"""
        address = raw_input("Enter the address you want to withdraw to: ")
        normalfee = prompt("The default fee is 0.0005. Accept + Deduct this from the amount?",True)
        if normalfee == False:
            fee = D(raw_input("Enter the fee of the transaction: "))
        else:
            fee = D('0.0005')
        totalbalance = prompt("Do you want to withdraw your ENTIRE balance?",False)
        if totalbalance == False:
            amount = D(raw_input("Enter the amount of BTC to withdraw: "))
        else:
            amount,_ = bal()
        mtgox.bitcoin_withdraw(address,amount*D(ibPrec),fee*D(ibPrec))


    def do_EOF(self,args):        #exit out if Ctrl+Z is pressed
        """Exits the program"""
        return self.do_exit(args)

    def do_exit(self,args):      #standard way to exit
        """Exits the program"""   
        print "\n"
        print "Session Terminating......."
        print "Exiting......"           
        return True

    def help_help(self):
        print 'Prints the help screen'
        

if __name__ == '__main__':
    Shell().cmdloop()
