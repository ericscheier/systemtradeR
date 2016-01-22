"""
MtGoxHMAC v0.33

Copyright 2011 Brian Monkaba
Modified 4/13/2013 by genBTC 

This file *was* part of ga-bitbot. It was modified heavily and is now part of genBTC's program.

    ga-bitbot is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    ga-bitbot is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with ga-bitbot.  If not, see <http://www.gnu.org/licenses/>.
"""

from contextlib import closing
from Crypto.Cipher import AES
import getpass
import base64
import hmac
import hashlib
import time
import json
import json_ascii
import urllib
import urllib2
import urlparse
import ssl
import gzip
import io
from decimal import Decimal as D
import traceback

from common import UserError,ServerError,prompt

CURRENCY = "USD"
PRODUCT = "BTC"     #maybe future litecoin implementations can work off this
PAIR = PRODUCT + CURRENCY

import unlock_api_key   #comment this out and read below if you dont need authenticated commands

class Client:
    def __init__(self, enc_password=""):
        #This is part of my encrypt_api_key and unlock_api_key file.
        #without these, set self.key and self.secret to your API Key/Secret in " " 
        self.key,self.secret,self.enc_password = unlock_api_key.unlock("mtgox")
        
        self.buff = ""
        self.__url_parts = "https://data.mtgox.com/api/"
        
        self.query_now = time.time()
        self.query_last = time.time()
        self.query_count = 0
        self.query_limit_per_time_slice = 40
        self.query_time_slice = 20
        self.query_timeout = 5
        
        self.order_first = 0
        self.order_now = time.time()
        self.order_last = time.time()
        self.order_count = 0
        self.order_limit_per_time_slice = 5
        self.order_time_slice = 6
        self.order_timeout = 0.1
        self.order_ban = 0

        self.cPrec = D('0.00001')
        self.bPrec = D('0.00000001')

        self.orders = []
        self.fulldepth = []

    def throttle(self,ordering=False):
        if ordering == False:
            self.query_now = time.time()
            tdelta = self.query_now - self.query_last
            if tdelta > self.query_time_slice:
                self.query_count = 0
                self.query_last = time.time()
            self.query_count += 1
            if self.query_count > self.query_limit_per_time_slice:
                print "### Throttled ###"
                time.sleep(self.query_timeout)    #throttle the connection
        if ordering == True:
            if not self.order_first:
                self.order_first = time.time()
            self.order_now = time.time()
            print("Unix time is: %.3f" % self.order_now),
            tdelta = self.order_now - self.order_last
            if tdelta > self.order_time_slice:
                self.order_count = 0
                self.order_last = time.time()
            self.order_count += 1
            if self.order_count > self.order_limit_per_time_slice:
                print "### Throttled ###"
                self.order_window_length = self.order_now-self.order_first
                time.sleep(self.order_timeout+(self.order_time_slice-self.order_window_length))    #throttle the connection
                self.order_first = time.time()
            else:
                self.order_first = 0
                self.order_last = time.time()
            if self.order_ban:    
                time.sleep(self.order_ban)      #wait for the ban timeout to elapse
                self.order_ban = 0


       
    def perform(self, path, params,JSON=True,API_VERSION=0,GZIP=True,GET=False):
        while True:
            if "/money/order/add" in path:
                self.throttle(ordering=True)
            else:
                self.throttle()
            try:
                nonce =  str(int(time.time()*1E6))
                if params != None:
                    if isinstance(params, dict):
                        params = params.items()
                else:
                    params = []

                params += [(u'nonce',nonce)]
                post_data = urllib.urlencode(params)
                ahmac = base64.b64encode(str(hmac.new(base64.b64decode(self.secret),post_data,hashlib.sha512).digest()))

                if API_VERSION == 0:
                    url = self.__url_parts + '0/' + path
                elif API_VERSION == 1: 
                    url = self.__url_parts + '1/' + path
                else: #assuming API_VERSION 2
                    url = self.__url_parts + '2/' + path
                    api2postdatatohash = path + chr(0) + post_data          #new way to hash for API 2, includes path + NUL
                    ahmac = base64.b64encode(str(hmac.new(base64.b64decode(self.secret),api2postdatatohash,hashlib.sha512).digest()))
                
                # Create header for auth-requiring operations
                header = {
                    "User-Agent": 'genBTC-bot',
                    "Rest-Key": self.key,
                    "Rest-Sign": ahmac
                    }
                # Create the request
                if GET:
                    req = urllib2.Request(url)
                else:
                    req = urllib2.Request(url, post_data, header)
                # if GZIP was set, accept gzip encoding
                if GZIP:
                    req.add_header('Accept-encoding', 'gzip')
                # Send the request to the server and receive the response
                if GET:
                    resp = urllib2.urlopen(req)
                else:
                    resp = urllib2.urlopen(req, post_data)
                # Un-Gzip the response
                if resp.info().get('Content-Encoding') == 'gzip':
                    buf = io.BytesIO(resp.read())
                    resp = gzip.GzipFile(fileobj=buf)
                # if JSON was set, json-ify the response, or say what went wrong, otherwise return plain data
                if JSON == True:
                    try:
                        data = json.load(resp,object_hook=json_ascii.decode_dict)
                        if "error" in data:
                            if data["error"] == "Not logged in.":
                                print UserError(data["error"])
                            else:
                                print ServerError(data["error"])
                    except ValueError as e:
                        print "JSON Error: %s." % e
                        continue
                else:
                    data = resp.read()
                return data
            #Try to catch a number of possible errors. 
            #Since this is used for debugging, logging.debug() should really be used instead
            except urllib2.HTTPError as e:
                #HTTP Error ie: 500/502/503 etc
                print 'HTTP Error %s: %s' % (e.code, e.msg)
                print "URL: %s" % (e.filename)
                if e.fp:
                    datastring = e.fp.read()
                    if "error" in datastring:
                        if "<!DOCTYPE HTML>" in datastring:
                            print "Error: Cloudflare - Website Currently Unavailable."
                        elif "Order not found" in datastring:
                            return json.loads(datastring)
                        elif "Too many orders" in datastring:
                            self.wait = int(datastring[datastring.find("wait")+5:datastring.find("secs")-1])
                            self.order_ban = self.wait - self.order_timeout
                            print "ERROR: Too many orders. Please wait %s seconds..." % self.wait
                        else:
                            print "Error: %s" % datastring                            
            except urllib2.URLError as e:
                print "URL Error:", e 
            except ssl.SSLError as e:
                print "SSL Error: %s." % e  #Read error timeout. (Removed timeout variable)
            except Exception as e:
                print "General Error: %s" % e
            else:
            #print this before going back up to the While Loop and running this entire function over again
                print "Retrying Connection...."


    def request(self, path, params,JSON=True,API_VERSION=0,GZIP=True,GET=False):
        return self.perform(path, params,JSON,API_VERSION,GZIP,GET)

    #public api
    def get_bid_history(self,OID):
        params = {"type":'bid',"order":OID}
        return self.request('generic/order/result',params,API_VERSION=1)
    
    def get_ask_history(self,OID):
        params = {"type":'ask',"order":OID}
        return self.request('generic/order/result',params,API_VERSION=1)

    def get_bid_tids(self,OID):
        #used to link an OID from an API order to a list of TIDs reported in the account history log
        try:
            history = self.get_bid_history(OID)
        except:
            #OID not found, return an empty list
            return []
        else:
            trade_ids = []
            if history['result'] == 'success':
                for trade in history['return']['trades']:
                    trade_ids.append(trade['trade_id'])
                    #return the list of trade ids
                    return trade_ids
            else:
                return []

    def get_ask_tids(self,OID):
        #used to link an OID from an API order to a list of TIDs reported in the account history log
        try:
            history = self.get_ask_history(OID)
        except:
            #OID not found, return an empty list
            return []
        else:
            trade_ids = []
            if history['result'] == 'success':
                for trade in history['return']['trades']:
                    trade_ids.append(trade['trade_id'])
                    #return the list of trade ids
                    return trade_ids
            else:
                return []

    def lag(self):
        return self.request('generic/order/lag',None,API_VERSION=1,GET=True)["return"]

    def get_history_btc(self):
        return self.request('history_' + PRODUCT + '.csv',None,JSON=False)
    def get_history_usd(self):
        return self.request('history_' + CURRENCY + '.csv',None,JSON=False)

    def get_info(self):
        return self.request('generic/info',None,API_VERSION=1)["return"]
    def get_balance(self):
        info = self.get_info()["Wallets"]
        balance = { "usds":info[CURRENCY]["Balance"]["value"], "btcs":info[PRODUCT]["Balance"]["value"] }
        return balance

    def get_ticker(self):
        return self.request("ticker.php",None,GET=True)["ticker"]
    def get_ticker2(self):
        return self.request(PAIR + "/money/ticker",None,API_VERSION=2,GET=True)["data"]
    def get_tickerfast(self):
        return self.request(PAIR + "/money/ticker_fast",None,API_VERSION=2,GET=True)["data"]

    def get_depth(self):
        return self.request("data/getDepth.php", {"Currency":CURRENCY})
    def get_fetchdepth(self):
        return self.request(PAIR + "/money/depth/fetch",None,API_VERSION=2,GET=True)
    def get_fulldepth(self):
        return self.request(PAIR + "/money/depth/full",None,API_VERSION=2,GET=True)

    def get_trades(self):
        return self.request("data/getTrades.php",None,GET=True)
    def entire_trade_history(self):
        return self.request(PAIR + "/money/trades/fetch",None,API_VERSION=2,GET=True)

    def get_spread(self):
        depth = self.get_depth()
        lowask = depth["asks"][0][0]
        highbid = depth["bids"][-1][0]
        spread = lowask - highbid
        return spread

    def get_orders(self):
        self.orders = self.request("getOrders.php",None)
        return self.orders
        
    def last_order(self):
        try:
            orders = self.get_orders()['orders']
            max_date = 0
            last_order = orders[0]
            for o in orders:
                if o['date'] > last_order['date']:
                    last_order = o
                return last_order
        except:
            print 'no orders found'
            return
    
    def order_new(self, typ, amount, price=None, protection=True):
        if amount < D('0.01'):
            print "Minimum amount is 0.01 %s" % PRODUCT
            return None
        if protection == True:
            if amount > D('100.0'):
                yesno = prompt("You are about to {0} >100 {1}.".format(typ,PRODUCT),True)
                if not(yesno):
                    return None
        amount_int = int(D(amount) * (1/self.bPrec))
        params = {"type":str(typ),
                "amount_int":amount_int
                }
        if price:
            price_int = int(D(price) * (1/self.cPrec))
            params["price_int"] = price_int
        response = self.request(PAIR + "/money/order/add", params, API_VERSION=2)
        if response.get("result") == "success":
            return response
        else:
            return None

    def cancel_one(self,oid):
        params = {"oid":str(oid)}
        result = self.request(PAIR + "/money/order/cancel", params, API_VERSION=2)
        if result.get("result") == "success":
            print 'OID: %s Successfully Cancelled!' % (oid)
        else:
            print "Order not found!!"
        return result

    def cancel_all(self):
        orders = self.get_orders()['orders']
        orders = sorted(orders, key=lambda x: float(x['price']))
        for order in orders:
            typ = order['type']
            ordertype="Sell" if typ == 1 else "Buy"
            oid = order['oid']
            params = {"oid":str(oid)}
            if oid[0] != 'X':
                result = self.request(PAIR + "/money/order/cancel", params, API_VERSION=2)
                if result.get("result") == 'success':
                    print '%s OID: %s Successfully Cancelled!' % (ordertype,oid)
                else:
                    print "Cancelling Order Failed for some reason!"
        if orders:
            print "All Orders have been Cancelled!!!!!"
        else:
            print "No Orders found!!"

#EXPERIMENTAL API

#(barely useful in testing)
#puts in a "bid/ask"(typ) order of the specified amount and tells you the total as if it were making a market order
    def order_quote(self,typ,amount,price=""):
        params = {"type":str(typ),
                "amount":amount
                }
        if price:
            #price = int(D(price) * (1/self.cPrec))
            params["price"] = price
        result = self.request(PAIR + "/money/order/quote", params, API_VERSION=2)
        if result["result"] == "success":
            print 'The result was ' % (result)
            return result["data"]
        else:
            print "Error!! %s" % result["result"]        

#tested, not 100%, hence the traceback
    def bitcoin_address(self,desc=""):
        #gets a bitcoin address linked to your account
        #a new description creates a new address
        try:
            if desc:
                params = {"description":str(desc)}
            else:
                params = None
            response = self.request("generic/private/bitcoin/address",params,API_VERSION=1)
            if "error" in response:
                print "Error!! %s" % response["error"]
            elif "success" in response:
                print response["return"]["addr"]
        except Exception as e:
            traceback.print_exc()            

#tested, not 100%, hence the traceback
    def bitcoin_withdraw(self,address,amount_int,fee_int="",no_instant=False,green=False):
    #string, int, (int, bool, bool)are optional
        try:
            params = {"address":str(address),
                    "amount_int":int(amount_int),
                    "fee_int":int(fee_int),
                    "no_instant":no_instant,
                    "green":green
                    }
            response = self.request("generic/private/bitcoin/send_simple",params,API_VERSION=1)
            if "error" in response:
                print "Error!! %s" % response["error"]
            elif "success" in response:
                print response
        except Exception as e:
            traceback.print_exc()

#not sure if this one is still allowed
    def bitcoin_withdraw_api0(self,address,amount,fee):
    #string, int, (int, bool, bool)are optional
        try:
            params = {"group1":"BTC",
                    "btca":str(address),
                    "amount":int(amount),
                    "fee":int(fee)#,
                    #"no_instant":no_instant,
                    #"green":green
                    }
            response = self.request("withdraw.php",params,API_VERSION=0)
            print response
            if "error" in response:
                print "Error!! %s" % response["error"]
            else:
                print response['status']
        except Exception as e:
            traceback.print_exc()                