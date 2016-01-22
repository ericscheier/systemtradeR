# list of commonly used and useful functions
# NOW contains common client interface function calls to each individual API framework

import time
import random
import math
import time
import os
import json
import time
import collections
import decimal
from decimal import Decimal as D
import random
import re
from functools import wraps


class UserError(Exception):
    def __init__(self, errmsg):
        self.errmsg = errmsg
    def __str__(self):
        return self.errmsg

class ServerError(Exception):
    def __init__(self, ret):
        self.ret = ret
    def __str__(self):
        return "Server error: %s" % self.ret

        
fullpath = os.path.dirname(os.path.realpath(__file__))
if os.path == 'nt':
  partialpath=os.path.join(fullpath + '\\..\\data\\')
else:
  partialpath=os.path.join(fullpath + '/../data/')

#write the FULL depth to a log file
def writedepth(mtgox):
    with open(os.path.join(partialpath + "mtgox_fulldepth.txt"),'w') as f:
        print "Starting to download fulldepth from mtgox....",
        fulldepth = mtgox.get_fulldepth()
        depthvintage = str(time.time())
        f.write(depthvintage)
        f.write('\n')
        json.dump(fulldepth,f)
        f.close()
        print "Finished."
    return depthvintage,fulldepth
def readdepth():            
    with open(os.path.join(partialpath + "mtgox_fulldepth.txt"),'r') as f:
        everything = f.readlines()
    depthvintage = everything[0]
    fulldepth = json.loads(everything[1])
    return depthvintage, fulldepth

def updatedepthdata(mtgox,maxage=120):
    global depthvintage
    global fulldepth
    depthvintage,fulldepth = readdepth()
    if (time.time() - float(depthvintage)) > maxage:   # don't fetch from gox more often than every 2 min
        depthvintage,fulldepth = writedepth(mtgox)
    return depthvintage,fulldepth

def movavg(trades):
    #movingavg = sum(map(lambda x: x['price'], trades)) / len(trades)
    movingavg = sum(x['price'] for x in trades) / len(trades)       #uses list comprehension instead of a map and lambda
    return movingavg

#return the last N (window) lines of a file, ie: linux's tail command"
def tail(f, window=20):
    BUFSIZ = 1024
    f.seek(0, 2)
    bytes = f.tell()
    volume = window
    block = -1
    data = []
    while volume > 0 and bytes > 0:
        if (bytes - BUFSIZ > 0):
            # Seek back one whole BUFSIZ
            f.seek(block*BUFSIZ, 2)
            # read BUFFER
            data.append(f.read(BUFSIZ))
        else:
            # file too small, start from begining
            f.seek(0,0)
            # only read what was not read
            data.append(f.read(bytes))
        linesFound = data[-1].count('\n')
        volume -= linesFound
        bytes -= BUFSIZ
        block -= 1
    return '\n'.join(''.join(data).splitlines()[-window:])

#turn a whole list or tuple into a float
def floatify(l):
    if isinstance(l, (list, tuple)):
        return [floatify(v) for v in l]
    elif isinstance(l, collections.Mapping):
        return {floatify(k): floatify(l[k]) for k in l}
    try:
        return float(l)
    except:
        pass
    if isinstance(l, basestring) and len(l):
        return l
    return 0.0

#turn a whole list or tuple into a decimal
def decimalify(l):
    if isinstance(l, (list, tuple)):
        return [decimalify(v) for v in l]
    elif isinstance(l, collections.Mapping):
        return {decimalify(k): decimalify(l[k]) for k in l}
    try:
        return D(l)
    except:
        pass
    if isinstance(l, basestring) and len(l):
        return l
    return 0.0    

#get the mean of an entire list or tuple
def mean(l):
    l = floatify(l)
    if getattr(l,'__len__',[].__len__)():
        if isinstance(l, (list, tuple)) and len(l[0])==2 and all(isinstance(v, (float, int)) for v in l[0]) :
            return float(sum(p * v for p, v in l))/sum(v for p, v in l)
        elif isinstance(l, collections.Mapping):
            return {k: mean(l[k]) for k in l}
        elif isinstance(l, (tuple, list)):
            return float(sum(l))/len(l) if len(l) else None
    return floatify(l)

def average(s): return sum(s) * 1.0 / len(s)

def variance(thing,avg):
    return map(lambda x: (x - avg)**2, thing)

def stddev(x):
    import math
    return math.sqrt(average(x))

#calculate and print the total BTC between price A and B
#match any order to the opposite site of the order book (ie: if buying find a seller) - market order
#given the amount of BTC and price range check to see if it can be filled as a market order
def depthsumrange (bookside,amount,lowest=1,highest=2000,ismtgox=False):
    """Usage is: bookside(Book object) amount lowest(optional) highest(optional)"""
    totalBTC,totalprice = (0,0)
    if ismtgox:
        cdiv = D(1E5)
        bdiv = D(1E8)
    else:
        cdiv = D(1)
        bdiv = D(1)
    lowest *= cdiv
    highest *= cdiv

    for order in bookside:
        if order.price >= lowest and order.price <= highest:
            totalBTC+=order.volume
            totalprice+=order.volume * order.price
    word = "IS" if amount <= totalBTC else "is NOT"
    print "%s BTC %s available." % (amount,word),
    print 'There are %s BTC total between $%s and $%s' % (totalBTC/bdiv,lowest/cdiv,highest/cdiv)
    return totalBTC/bdiv,totalprice/(cdiv*bdiv)


#match any order to the opposite side of the order book (ie: if selling find a buyer) - market order
#calculate the total price of the order and the average weighted price of each bitcoin 
def depthprice (bookside,amount,lowest,highest,ismtgox=False):
    """Usage is: bookside(Book object) amount lowest highest"""
    totalBTC, totalprice, weightedavgprice = (0,0,0)
    if ismtgox:
        cdiv = D(1E5)
        bdiv = D(1E8)
    else:
        cdiv = D(1)
        bdiv = D(1)
    lowest *= cdiv
    highest *= cdiv
    amount *= bdiv

    for order in bookside:
        if order.price >= lowest and order.price <= highest:
            print "order.price %s / order.volume %s " % (order.price,order.volume)
            if totalBTC < amount:
                totalBTC+=order.volume
                totalprice+=order.volume * order.price
            if totalBTC >= amount:
                totalprice-=order.price*(totalBTC-amount)
                totalBTC=amount
                weightedavgprice=totalprice/totalBTC
                break
    if weightedavgprice > 0:
        print '%s BTC @ $%.5f/BTC equals: $%.5f' % (totalBTC/bdiv, weightedavgprice/cdiv,totalprice/(cdiv*bdiv))
        return totalBTC/bdiv,weightedavgprice/cdiv,totalprice/(cdiv*bdiv)
    else: 
        print 'Your order cannot be serviced.'    

#print the order books out to howmany length you want
def printbothbooks(asks,bids,howmany):
    for order in reversed(asks[:howmany]):
        pcstr = str(order[0])
        szstr = str(order[1])
        if len(szstr) <= 5:
            szstr += "   "
        print ' '*34,'$%s,\t%s  \t-----ASK-->' % (pcstr,szstr)
    print ' '*15,'|'*9,'First %s Orders' % howmany,'|'*9
    for order in bids[:howmany]:
        pcstr = str(order[0])
        szstr = str(order[1])        
        print '<--BID-----$%s,\t%s' % (pcstr,szstr)

def printOrderBooks(asks,bids,howmany=15):
    for order in reversed(asks[:howmany]):
        pcstr = str(order.price/1E5)
        szstr = str(order.volume/1E8)
        if len(szstr) <= 5:
            szstr += "   "
        print ' '*34,'$%s,\t%s  \t-----ASK-->' % (pcstr,szstr)
    print ' '*15,'|'*9,'First %s Orders' % howmany,'|'*9
    for order in bids[:howmany]:
        pcstr = str(order.price/1E5)
        szstr = str(order.volume/1E8)        
        print '<--BID-----$%s,\t%s' % (pcstr,szstr)        


# spread trade function including Chunk Trade spread logic & Confirmation
def spread(exchangename,exchangeobject, side, volume, price_lower, price_upper=100000,chunks=1,dorandom='',silent=False,useSocket=False):
    """Sell some BTC between price A and price B of equal volumed chunks"""
    """Format is sell amount(BTC) price_lower price_upper chunks(#)"""
    """ie:   sell 6.4 40 41 128 = buys 6.4 BTC between $40 to $41 using 128 chunks"""
    """Simple trade also allowed: (buy/sell) amount price"""
    """Added in some optional randomness to it"""
    orderids = []
    sidedict = {0:"Buy",1:"Sell","bid":"Buy","ask":"Sell"}
    mapdict = {"bitfloor":"order_id","mtgox":"data","bitstamp":"id"}
    randomnesstotal = 0
    loop_price = D(str(price_lower))
    price_range = D(str(price_upper)) - D(str(price_lower))
    bPrec = exchangeobject.bPrec
    cPrec = exchangeobject.cPrec
    price_chunk = D(price_range/ D(chunks)).quantize(cPrec)
    chunk_volume = D(D(volume) / D(chunks)).quantize(bPrec)
    for x in range (0, int(chunks)):
        randomchunk = chunk_volume
        if dorandom.lower()=='random':
            if chunks > 1:
                if x+1 == int(chunks):
                    randomchunk -= randomnesstotal
                else:
                    randomness = D((random.random()/100) + (random.random()/100)).quantize(bPrec)
                    randomnesstotal += randomness
                    randomchunk += randomness
        if silent == False:
            print '%sing... Chunk #%s = %s BTC @ $%s' % (sidedict[side],x+1,randomchunk,loop_price)
        if useSocket == False:
            result = exchangeobject.order_new(side, randomchunk, loop_price)  
            if result:
                if not("error" in result):
                    orderids.append(result[mapdict[exchangename]])
            else:
                return
            if silent == False:
                if result:
                    if not("error" in result):
                        print "Order ID is : %s" % result[mapdict[exchangename]]
                    elif "error" in result:
                        print "Order was submitted but failed because: %s" % result["error"]
                else:
                    print "Order failed."                
        elif useSocket == True:
            api = "order/add"
            price = int(loop_price*(1/cPrec))
            volume = int(randomchunk*(1/bPrec))
            params = {"type": side, "price_int": price,"amount_int": volume}
            reqid = "order_add:%s:%d:%d" % (side, price, volume)
            exchangeobject.client.send_signed_call(api, params, reqid)

        loop_price += price_chunk

    return orderids
        
def ppdict(d):
    #pretty print a dict
    print "-"*40
    try:
        for key in d.keys():
            print key,':',d[key]      
    except:
        print d
    return d

def pwdict(d,filename):
    #pretty write a dict
    f = open(filename,'w')
    try:
        for key in d.keys():
            f.write(key + " : " + str(d[key]) + "\n")
    except:
        pass
    f.write('\n' + '-'*80 + '\n')
    f.write(str(d))
    f.close()
    return d

def getSlope(values):
    points = []
    for i in range(len(values)):
      points.append({'x':i, 'y':values[i]})
    n = len(values)
    sx = sum([x['x'] for x in points])
    sy = sum([x['y'] for x in points])
    sxy = sum([x['x']*x['y'] for x in points])
    sxx = sum([x['x']*x['x'] for x in points])
    delta = (n*sxx)-(sx**2)
    if delta == 0:
      return UNDEFINED_SLOPE
    return ((n*sxy)-(sx*sy))/delta

def validatenum(strng):
    search=re.compile(r'[^0-9. ]').search
    return not bool(search(strng))

def validatechar(strng):
    search=re.compile(r'[^a-zA-Z ]').search
    return not bool(search(strng))

def validateboth(strng):
    search = re.compile(r'[^a-zA-Z0-9. ]').search
    return not bool(search(strng))

def stripoffensive(strng,additional=""):
    pattern = r'[^a-zA-Z0-9. ]'
    if additional:
        pattern = pattern[:-1] + additional + ']'
    new = re.sub(pattern, '', strng)
    return new

def prompt(prompt,default):
    y = ("y","yes") 
    n = ("n","no")
    defaultcapital = "[YES]/no" if default else "[NO]/yes"
    a = " "
    while a.lower() not in (y+n):
        a = raw_input("%s %s: " % (prompt,defaultcapital)).lower()
        if a.lower() == "":
            return default
    if a.lower() in y:
        return True
    elif a.lower() in n:
        return False

class onlyevery(object):    
    ''' Usage (decorator): @onlyevery(delay=2,block=False)
        if block=False, will return cached values if called again within delay seconds.
        if block=True, if called again within delay seconds, will delay for delay-last seconds '''
    def __init__(self, delay=2, block=False):
        self.delay = delay
        self.block = block
        self.cachedValue = None
        self.cachedAt = None
    def __call__(self, f, *args, **kwargs):
        @wraps(f)
        def wrapper(*fargs,**kw):
            t = time.time()
            calledTooSoon = False
            if self.cachedAt and t - self.cachedAt < self.delay:
                calledTooSoon = True
            if calledTooSoon and self.block:
                tts = self.delay
                if self.cachedAt: tts = tts - (t - self.cachedAt)
                time.sleep(self.delay)
            elif calledTooSoon and self.cachedValue:
                return self.cachedValue
            self.cachedValue = f(*fargs, **kw)
            self.cachedAt = time.time()
            return self.cachedValue
        return wrapper

