"""Mt.Gox API"""

#  Copyright (c) 2013 Bernd Kreuss <prof7bit@gmail.com>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.

# pylint: disable=C0302,C0301,R0902,R0903,R0912,R0913,W0703

import sys
PY_VERSION = sys.version_info

if PY_VERSION < (2, 7):
    print("Sorry, minimal Python version is 2.7, you have: %d.%d"
        % (PY_VERSION.major, PY_VERSION.minor))
    sys.exit(1)

from ConfigParser import SafeConfigParser
import base64
import binascii
import contextlib
from Crypto.Cipher import AES
from decimal import Decimal as D
import getpass
import gzip
import hashlib
import hmac
import inspect
import io
import json
import logging
import Queue
import time
import traceback
import threading
from urllib2 import Request as URLRequest
from urllib2 import urlopen, HTTPError
from urllib import urlencode
import weakref
import websocket

import unlock_api_key

input = raw_input # pylint: disable=W0622,C0103

FORCE_PROTOCOL = "socketio"
FORCE_NO_FULLDEPTH = False
FORCE_NO_HISTORY = False
FORCE_HTTP_API = False
SOCKETIO_HOST = "socketio.mtgox.com"
WEBSOCKET_HOST = "websocket.mtgox.com"
HTTP_HOST = "data.mtgox.com"

USER_AGENT = "trader.genbtc"

def int2str(value_int, currency):
    """return currency integer formatted as a string"""
    if currency == "BTC":
        return ("%16.8f" % (value_int / 1E8))
    if currency == "JPY":
        return ("%12.3f" % (value_int / 1E3))
    if currency == "USD":
        return ("%12.5f" % (value_int / 1E5))
    else:
        return ("%12.5f" % (value_int / 1E5))

def int2float(value_int, currency):
    """convert integer to float, determine the factor by currency name"""
    if currency == "BTC":
        return value_int / 1E8
    if currency == "JPY":
        return value_int / 1E3
    if currency == "USD":
        return value_int / 1E5
    else:
        return value_int / 1E5

def float2int(value_float, currency):
    """convert float value to integer, determine the factor by currency name"""
    if currency == "BTC":
        return int(value_float * 1E8)
    if currency == "JPY":
        return int(value_float * 1E3)
    if currency == "USD":
        return int(value_float * 1E5)
    else:
        return int(value_float * 1E5)

def http_request(url, post=None, headers=None):
    """request data from the HTTP API, returns a string"""

    def read_gzipped(response):
        """read data from the response object,
        unzip if necessary, return text string"""
        if response.info().get('Content-Encoding') == 'gzip':
            with io.BytesIO(response.read()) as buf:
                with gzip.GzipFile(fileobj=buf) as unzipped:
                    data = unzipped.read()
        else:
            data = response.read()
        return data

    if not headers:
        headers = {}
    request = URLRequest(url, post, headers)
    request.add_header('Accept-encoding', 'gzip')
    request.add_header('User-Agent', USER_AGENT)
    data = ""
    try:
        with contextlib.closing(urlopen(request, post)) as res:
            data = read_gzipped(res)
    except HTTPError as err:
        data = read_gzipped(err)

    return data

def start_thread(thread_func):
    """start a new thread to execute the supplied function"""
    thread = threading.Thread(None, thread_func)
    thread.daemon = True
    thread.start()
    return thread

def pretty_format(something):
    """pretty-format a nested dict or list for debugging purposes.
    If it happens to be a valid json string then it will be parsed first"""
    try:
        return pretty_format(json.loads(something))
    except Exception:
        try:
            return json.dumps(something, indent=5)
        except Exception:
            return str(something)


# pylint: disable=R0904
class GoxConfig(SafeConfigParser):
    """return a config parser object with default values. If you need to run
    more Gox() objects at the same time you will also need to give each of them
    them a separate GoxConfig() object. For this reason it takes a filename
    in its constructor for the ini file, you can have separate configurations
    for separate Gox() instances"""

    _DEFAULTS = [["gox", "currency", "USD"]
                ,["gox", "use_ssl", "True"]
                ,["gox", "use_plain_old_websocket", "False"]
                ,["gox", "prefer_http_api", "False"]
                ,["gox", "load_fulldepth", "True"]
                ,["gox", "load_history", "False"]
                ]

    def __init__(self): 
        SafeConfigParser.__init__(self)
        for (sect, opt, default) in self._DEFAULTS:
            self._default(sect, opt, default)

    def get_safe(self, sect, opt):
        """get value without throwing exception."""
        try:
            return self.get(sect, opt)
        # pylint: disable=W0702
        except:
            for (dsect, dopt, default) in self._DEFAULTS:
                if dsect == sect and dopt == opt:
                    self._default(sect, opt, default)
                    return default
            return ""

    def get_bool(self, sect, opt):
        """get boolean value from config"""
        return self.get_safe(sect, opt) == "True"

    def get_string(self, sect, opt):
        """get string value from config"""
        return self.get_safe(sect, opt)

    def get_int(self, sect, opt):
        """get int value from config"""
        vstr = self.get_safe(sect, opt)
        try:
            return int(vstr)
        except ValueError:
            return 0

    def _default(self, section, option, default):
        """create a default option if it does not yet exist"""
        if not self.has_section(section):
            self.add_section(section)
        if not self.has_option(section, option):
            self.set(section, option, default)


class Signal():
    """callback functions (so called slots) can be connected to a signal and
    will be called when the signal is called (Signal implements __call__).
    The slots receive two arguments: the sender of the signal and a custom
    data object. Two different threads won't be allowed to send signals at the
    same time application-wide, concurrent threads will have to wait until
    the lock is releaesed again. The lock allows recursive reentry of the same
    thread to avoid deadlocks when a slot wants to send a signal itself."""

    _lock = threading.RLock()
    signal_error = None

    def __init__(self):
        self._functions = weakref.WeakSet()
        self._methods = weakref.WeakKeyDictionary()

        # the Signal class itself has a static member signal_error where it
        # will send tracebacks of exceptions that might happen. Here we
        # initialize it if it does not exist already
        if not Signal.signal_error:
            Signal.signal_error = 1
            Signal.signal_error = Signal()

    def connect(self, slot):
        """connect a slot to this signal. The parameter slot can be a funtion
        that takes exactly 2 arguments or a method that takes self plus 2 more
        arguments, or it can even be even another signal. the first argument
        is a reference to the sender of the signal and the second argument is
        the payload. The payload can be anything, it totally depends on the
        sender and type of the signal."""
        if inspect.ismethod(slot):
            if slot.__self__ not in self._methods:
                self._methods[slot.__self__] = set()
            self._methods[slot.__self__].add(slot.__func__)
        else:
            self._functions.add(slot)

    def __call__(self, sender, data, error_signal_on_error=True):
        """dispatch signal to all connected slots. This is a synchronuos
        operation, It will not return before all slots have been called.
        Also only exactly one thread is allowed to emit signals at any time,
        all other threads that try to emit *any* signal anywhere in the
        application at the same time will be blocked until the lock is released
        again. The lock will allow recursive reentry of the seme thread, this
        means a slot can itself emit other signals before it returns (or
        signals can be directly connected to other signals) without problems.
        If a slot raises an exception a traceback will be sent to the static
        Signal.signal_error() or to logging.critical()"""
        with self._lock:
            sent = False
            errors = []
            for func in self._functions:
                try:
                    func(sender, data)
                    sent = True

                # pylint: disable=W0702
                except:
                    errors.append(traceback.format_exc())

            for obj, funcs in self._methods.items():
                for func in funcs:
                    try:
                        func(obj, sender, data)
                        sent = True

                    # pylint: disable=W0702
                    except:
                        errors.append(traceback.format_exc())

            for error in errors:
                if error_signal_on_error:
                    Signal.signal_error(self, (error), False)
                else:
                    logging.critical("###Error:",error)

            return sent


class BaseObject():
    """This base class only exists because of the debug() method that is used
    in many of the goxtool objects to send debug output to the signal_debug."""

    def __init__(self):
        self.signal_debug = Signal()

    def debug(self, *args):
        """send a string composed of all *args to all slots who
        are connected to signal_debug or send it to the logger if
        nobody is connected"""
        msg = " ".join([str(x) for x in args])
        if not self.signal_debug(self, (msg)):
            logging.debug(msg)
        #print msg


class Timer(Signal):
    """a simple timer (used for stuff like keepalive)"""

    def __init__(self, interval):
        """create a new timer, interval is in seconds"""
        Signal.__init__(self)
        self._interval = interval
        self._timer = None
        self._start()

    def _fire(self):
        """fire the signal and restart it"""
        self.__call__(self, None)
        self._start()

    def _start(self):
        """start the timer"""
        self._timer = threading.Timer(self._interval, self._fire)
        self._timer.daemon = True
        self._timer.start()

    def cancel(self):
        """cancel the timer"""
        self._timer.cancel()


class Secret:
    """Manage the MtGox API secret. This class has methods to decrypt the
    entries in the ini file and it also provides a method to create these
    entries. The methods encrypt() and decrypt() will block and ask
    questions on the command line, they are called outside the curses
    environment (yes, its a quick and dirty hack but it works for now)."""

    def __init__(self):
        """initialize the instance"""
        self.key = ""
        self.secret = ""

    def decrypt(self, password=""):
        """decrypt "secret_secret" from the file with the given password.
        This will return false if decryption did not seem to be successful.
        After this menthod succeeded the application can access the secret"""
        if self.know_secret():
            return 1
        try:
            self.key,self.secret, _ = unlock_api_key.unlock("mtgox",password)
            return 1
        except:
            return False
        
    def prompt_decrypt(self,password=""):
        """ask the user for password on the command line
        and then try to decrypt the secret."""
        self.decrypt(password)


    def know_secret(self):
        """do we know the secret key? The application must be able to work
        without secret and then just don't do any account related stuff"""
        return(self.secret != "") and (self.key != "")


class OHLCV():
    """represents a chart candle. tim is POSIX timestamp of open time,
    prices and volume are integers like in the other parts of the gox API"""

    def __init__(self, tim, opn, hig, low, cls, vol):
        self.tim = tim
        self.opn = opn
        self.hig = hig
        self.low = low
        self.cls = cls
        self.vol = vol

    def update(self, price, volume):
        """update high, low and close values and add to volume"""
        if price > self.hig:
            self.hig = price
        if price < self.low:
            self.low = price
        self.cls = price
        self.vol += volume


class History(BaseObject):
    """represents the trading history"""

    def __init__(self, gox, timeframe):
        BaseObject.__init__(self)

        self.signal_changed = Signal()

        self.gox = gox
        self.candles = []
        self.timeframe = timeframe

        gox.signal_trade.connect(self.slot_trade)
        gox.signal_fullhistory.connect(self.slot_fullhistory)

    def add_candle(self, candle):
        """add a new candle to the history"""
        self._add_candle(candle)
        self.signal_changed(self, (self.length()))

    def slot_trade(self, dummy_sender, data):
        """slot for gox.signal_trade"""
        (date, price, volume, dummy_typ, own) = data
        if not own:
            time_round = int(date / self.timeframe) * self.timeframe
            candle = self.last_candle()
            if candle:
                if candle.tim == time_round:
                    candle.update(price, volume)
                    self.signal_changed(self, (1))
                else:
                    self.debug("### opening new candle")
                    self.add_candle(OHLCV(
                        time_round, price, price, price, price, volume))
            else:
                self.add_candle(OHLCV(
                    time_round, price, price, price, price, volume))

    def _add_candle(self, candle):
        """add a new candle to the history but don't fire signal_changed"""
        self.candles.insert(0, candle)

    def slot_fullhistory(self, dummy_sender, data):
        """process the result of the fullhistory request"""
        (history) = data

        def get_time_round(date):
            """round timestamp to current candle timeframe"""
            return int(date / self.timeframe) * self.timeframe

        #remove existing recent candle(s) if any, we will create them fresh
        date_begin = get_time_round(int(history[0]["date"]))
        while len(self.candles) and self.candles[0].tim >= date_begin:
            self.candles.pop(0)

        new_candle = OHLCV(0, 0, 0, 0, 0, 0) #this is a dummy, not actually inserted
        count_added = 0
        for trade in history:
            date = int(trade["date"])
            price = int(trade["price_int"])
            volume = int(trade["amount_int"])
            time_round = get_time_round(date)
            if time_round > new_candle.tim:
                if new_candle.tim > 0:
                    self._add_candle(new_candle)
                    count_added += 1
                new_candle = OHLCV(
                    time_round, price, price, price, price, volume)
            new_candle.update(price, volume)

        # insert current (incomplete) candle
        self._add_candle(new_candle)
        count_added += 1
        self.debug("### got %d updated candle(s)" % count_added)
        self.signal_changed(self, (self.length()))

    def last_candle(self):
        """return the last (current) candle or None if empty"""
        if self.length() > 0:
            return self.candles[0]
        else:
            return None

    def length(self):
        """return the number of candles in the history"""
        return len(self.candles)


class BaseClient(BaseObject):
    """abstract base class for SocketIOClient and WebsocketClient"""

    _last_nonce = 0
    _nonce_lock = threading.Lock()

    def __init__(self, gox, secret, config):
        BaseObject.__init__(self)

        self.signal_recv        = Signal()
        self.signal_fulldepth   = Signal()
        self.signal_fullhistory = Signal()

        self._keepalive_timer = Timer(60)
        
        self.currency = gox.currency
        self.gox = gox
        self.secret = secret
        self.config = config

        self.public_http_thread_queue = Queue.Queue()
        self.http_to_websocket_requests = Queue.Queue()
        self.socket = None
        self.connected = False
        self.created = 0
        self._terminate_recv_thread = threading.Event()
        self._terminate_recv_thread.set()
        self._terminate_http = threading.Event()
        self._time_last_received = 0
        self.http_threads_active = False

    def start(self):
        """start the client"""
        if self.http_threads_active == False:
            self.public_http_thread = start_thread(self.public_http_thread_func)
            self.signed_http_thread = start_thread(self.reroute_http_to_socket)
            self.http_threads_active = True
        if self._terminate_recv_thread.isSet():
            self._terminate_recv_thread.clear()
            self.debug("Starting Client, currency=" + self.currency)
            self._recv_thread = start_thread(self._recv_thread_func)
            
    def stop(self):
        """stop the client"""
        self.debug("Shutting down client & closing socket")
        self._terminate_recv_thread.set()
        self.connected = False
        self.socket.close()
        self.socket = None

    def _try_send_raw(self, raw_data):
        """send raw data to the websocket or disconnect and close"""
        if self.connected:
            try:
                #self.debug("Sending %s" % raw_data)
                self.socket.send(raw_data)
            except Exception as exc:
                self.debug(exc)
                self.socket.close()

    def get_nonce(self):
        """produce a unique nonce that is guaranteed to be ever increasing"""
        with self._nonce_lock:
            nonce = int(time.time()*1E6)
            if nonce <= self._last_nonce:
                nonce = self._last_nonce + 1
            self._last_nonce = nonce
            return nonce

    def request_order_lag(self):
        """request the current order-lag"""
        if FORCE_HTTP_API or self.config.get_bool("gox", "prefer_http_api"):
            self.enqueue_http_to_socket("money/order/lag", {}, "order_lag")
        else:
            self.send_signed_call("order/lag", {}, "order_lag")


    def request_fulldepth(self):
        self.public_http_thread_queue.put("request_fulldepth")
    def request_fetchdepth(self):
        self.public_http_thread_queue.put("request_fetchdepth")
    def request_history(self):
        self.public_http_thread_queue.put("request_history")
    def request_ticker(self):
        self.public_http_thread_queue.put("request_ticker")
    def request_getdepthapi0(self):
        self.public_http_thread_queue.put("request_getdepthapi0")


    def public_http_thread_func(self):
        use_ssl = self.config.get_bool("gox", "use_ssl")
        self.proto = {True: "https", False: "http"}[use_ssl]    
        def request_fulldepth(self):
            """request the full market depth, initialize the order book
            and then terminate. This is called in a separate thread after
            the streaming API has been connected."""
            try:
                fdtdelta = time.time() - self.gox.orderbook.fulldepth_time
                self.debug("### Requesting /api/2/BTC" + self.currency + "/money/depth/full. Updated %.3f ago" % fdtdelta)
                url = self.proto + "://" +  HTTP_HOST + "/api/2/BTC" + self.currency + "/money/depth/full"
                self.httpqueues[0].put(url)
                self.starthttp.put("go")                
                result = self.resultqueues[0].get(True)
                self.signal_fulldepth(self, (json.loads(result)))
            except Exception as e:
                self.debug("###request_fulldepth: Error:",e)
        def request_fetchdepth(self):
            """request the partial market depth, initialize the order book
            and then terminate. This is called in a separate thread after
            the streaming API has been connected."""
            try:
                fdtdelta = time.time() - self.gox.orderbook.fulldepth_time
                self.debug("### Requesting /api/2/BTC" + self.currency + "/money/depth/fetch. Updated %.3f ago" % fdtdelta)
                url = self.proto + "://" + HTTP_HOST + "/api/2/BTC" + self.currency + "/money/depth/fetch"
                self.httpqueues[1].put(url)
                self.starthttp.put("go")                
                result = self.resultqueues[1].get(True)
                self.signal_fulldepth(self, (json.loads(result)))
            except Exception as e:
                self.debug("###request_fetchdepth: Error:",e)
        def request_history(self):
            """request 24h trading history"""
            try:
                since = self.history_last_candle
                if since:
                    querystring = "?since=" + str(since * 1000000)
                else:
                    querystring = ""
                self.debug("Requesting /api/2/BTC" + self.currency + "/money/trades")
                url = self.proto + "://" + HTTP_HOST + "/api/2/BTC" + self.currency + "/money/trades" + querystring
                self.httpqueues[2].put(url)
                self.starthttp.put("go")
                result = self.resultqueues[2].get(True)
                history = json.loads(result)
                if history["result"] == "success":
                    self.signal_fullhistory(self, history["data"])
            except Exception as e:
                self.debug("###request_history: Error:",e)      
        def request_ticker(self):
            """request ticker using API 2 - most accurate."""
            try:
                self.debug("Requesting /api/2/" + self.currency + "/money/ticker_fast")
                url = self.proto + "://" + HTTP_HOST + "/api/2/BTC" + self.currency + "/money/ticker_fast"
                self.httpqueues[3].put(url)
                self.starthttp.put("go")
                result = self.resultqueues[3].get(True)
                ticker = json.loads(result)["data"]
                data = (float2int(ticker["buy"]["value"],self.currency), \
                    float2int(ticker["sell"]["value"],self.currency))
                self.gox.signal_backupticker(self,data)
            except Exception as e:
                self.debug("###request_ticker: Error:",e)
        def request_getdepthapi0(self):
            """request getDepth using API 0 - fastest"""
            try:
                self.debug("Requesting /api/0/getDepth.php")
                url = self.proto + "://" + HTTP_HOST + "/api/0/data/getDepth.php?Currency=" + self.currency
                starthttp.put("go")
                httpqueues[4].put(url)
                result = resultqueues[4].get(True)
                smalldepth = json.loads(result)
                bids = smalldepth["bids"]
                smalldepthmaindict = {}
                newbids = []
                for bid in bids:
                    eachbid = {}
                    eachbid["price_int"] = float2int(bid[0],self.currency)
                    eachbid["amount_int"] = float2int(bid[1],"BTC")
                    newbids.append(eachbid)
                asks = smalldepth["asks"]
                newasks = []
                for ask in asks:
                    eachask = {}
                    eachask["price_int"] = float2int(ask[0],self.currency)
                    eachask["amount_int"] = float2int(ask[1],"BTC")
                    newasks.append(eachask)
                smalldepthmaindict["data"] = {}
                smalldepthmaindict["data"]["bids"]=newbids
                smalldepthmaindict["data"]["asks"]=newasks
                self.signal_fulldepth(self, smalldepthmaindict)
            except Exception as e:
                self.debug("###request_getdepthapi0: Error:",e)
        
        start_thread(self.http_request_thread)
        funcdict = {"request_fulldepth":request_fulldepth,"request_fetchdepth":request_fetchdepth,"request_history":request_history,"request_ticker":request_ticker,"request_getdepthapi0":request_getdepthapi0}
        while True:
            name = None; handler = None
            name = self.public_http_thread_queue.get(True)
            funcdict[name](self)
            self.public_http_thread_queue.task_done()


    def http_request_thread(self):
        self.starthttp = Queue.Queue()
        self.stophttp = threading.Event()

        self.httpqueues = []
        for x in xrange(0,5):
            self.httpqueues.append(Queue.Queue())

        self.resultqueues = []
        for x in xrange(0,5):
            self.resultqueues.append(Queue.Queue())
   
        while not self.stophttp.isSet():
            self.starthttp.get(True)
            for x in xrange(0,4):
                g = None;p = None
                if not self.httpqueues[x].empty():
                    g = self.httpqueues[x].get_nowait()
                    p = http_request(g)
                    self.resultqueues[x].put(p)



    def channel_subscribe(self):
        """subscribe to the needed channels and alo initiate the
        download of the initial full market depth"""
        # Once you join 1::/mtgox these are automaticlaly subscribed to
        # CHANNELS = 
        #     "dbf1dee9-4f2e-4a08-8cb7-748919a71b21": "trades",
        #     "d5f06780-30a8-4a48-a2f8-7ed181b4a13f": "ticker",
        #     "24e67e0d-1cad-4cc0-9e7a-f8523ef460fe": "depth",
        #self.send(json.dumps({"op":"mtgox.subscribe", "type":"depth"}))
        #self.send(json.dumps({"op":"mtgox.subscribe", "type":"ticker"}))
        #self.send(json.dumps({"op":"mtgox.subscribe", "type":"trades"}))
        #This lag one is not automatic.        
        #self.send(json.dumps({"op":"mtgox.subscribe", "type":"lag"}))

        if self.gox.client.connected == True:
            if not(self.gox._idkey):
                if FORCE_HTTP_API or self.config.get_bool("gox", "prefer_http_api"):
                    self.enqueue_http_to_socket("money/idkey", {}, "idkey")
                else:
                    self.send_signed_call("private/idkey", {}, "idkey")
            else:
                self.debug("### already have idkey, subscribing to account messages:")
                self.gox.client.send(json.dumps({"op":"mtgox.subscribe", "key":self.gox._idkey}))
            self.enqueue_http_to_socket("money/orders", {}, "orders")
            self.send_signed_call("private/orders", {}, "orders")
                    #self.debug("Calling HTTP API's for: orders/idkey/info")
                     #self.enqueue_http_to_socket("money/info", {}, "info")
                #else:
                    #self.debug("Sending Socket messages requesting: orders/idkey/info")
                     #self.send_signed_call("private/info", {}, "info")

            # if self.config.get_bool("gox", "load_history"):
            #     if not FORCE_NO_HISTORY:
            #         self.request_history()

            fdtdelta = time.time() - self.gox.orderbook.fulldepth_time
            if fdtdelta > 120:
                if self.config.get_bool("gox", "load_fulldepth"):
                    if not FORCE_NO_FULLDEPTH:
                        self.request_fulldepth()


    def reroute_http_to_socket(self):
        """send queued http requests to the http API (only used when
        http api is forced, normally this is much slower)"""
        while not(self._terminate_http.isSet()):
            (api_endpoint, params, reqid) = self.http_to_websocket_requests.get(True)
            try:
                answer = self.http_signed_call(api_endpoint, params)
                if answer["result"] == "success":
                    # the following will reformat the answer in such a way
                    # that we can pass it directly to signal_recv()
                    # as if it had come directly from the websocket
                    ret = {"op": "result", "id": reqid, "result": answer["data"]}
                    self.signal_recv(self, (json.dumps(ret)))
                else:
                    self.debug("### http error result:", answer, reqid)
                    retry = True

                    if "error" in answer and answer["error"] == "Order not found":
                        self.debug("### could not cancel non existing order")
                        # the owns list is out of sync. Translate it into an
                        # op:remark message and send it to the recv signal as if
                        # this had come from the streming API, that will make
                        # it properly handle this condition and remove it.
                        fake_remark_msg = {
                            "op": "remark",
                            "success": False,
                            "message": "Order not found",
                            "id": reqid
                        }
                        self.signal_recv(self, (json.dumps(fake_remark_msg)))
                        retry = False

                    if retry:
                        self.enqueue_http_to_socket(api_endpoint, params, reqid)

            except Exception as exc:
                # should this ever happen? HTTP 5xx wont trigger this,
                # something else must have gone wrong, a totally malformed
                # reply or something else. Log the error and don't retry
                self.debug("### exception in _http_thread_func:",
                    exc, api_endpoint, params, reqid)

            self.http_to_websocket_requests.task_done()

    def enqueue_http_to_socket(self, api_endpoint, params, reqid):
        """enqueue a request for sending to the HTTP API, returns
        immediately, behaves exactly like sending it over the websocket."""
        if self.secret and self.secret.know_secret():
            self.http_to_websocket_requests.put((api_endpoint, params, reqid))

    def http_signed_call(self, api_endpoint, params):
        """send a signed request to the HTTP API V2"""
        if (not self.secret) or (not self.secret.know_secret()):
            self.debug("### don't know secret, cannot call %s" % api_endpoint)
            return

        key = self.secret.key
        sec = self.secret.secret

        params["nonce"] = self.get_nonce()
        post = urlencode(params)
        prefix = api_endpoint + chr(0)
        # pylint: disable=E1101
        sign = hmac.new(base64.b64decode(sec), prefix + post, hashlib.sha512).digest()

        headers = {
            'Rest-Key': key,
            'Rest-Sign': base64.b64encode(sign)
        }

        use_ssl = self.config.get_bool("gox", "use_ssl")
        proto = {True: "https", False: "http"}[use_ssl]
        url = proto + "://" + HTTP_HOST + "/api/2/" + api_endpoint

        self.debug("### (%s) calling %s" % (proto, url))
        return json.loads(http_request(url, post, headers))

    def send_signed_call(self, api_endpoint, params, reqid):
        """send a signed (authenticated) API call over the socket.io.
        This method will only succeed if the secret key is available,
        otherwise it will just log a warning and do nothing."""
        if (not self.secret) or (not self.secret.know_secret()):
            self.debug("### don't know secret, cannot call %s" % api_endpoint)
            return

        key = self.secret.key
        sec = self.secret.secret

        nonce = self.get_nonce()

        call = json.dumps({
            "id"       : reqid,
            "call"     : api_endpoint,
            "nonce"    : nonce,
            "params"   : params,
            "currency" : self.currency,
            "item"     : "BTC"
        })

        # pylint: disable=E1101
        sign = hmac.new(base64.b64decode(sec), call, hashlib.sha512).digest()
        signedcall = key.replace("-", "").decode("hex") + sign + call

        self.debug("### (socket) calling %s" % api_endpoint)
        self.send(json.dumps({
            "op"      : "call",
            "call"    : base64.b64encode(signedcall),
            "id"      : reqid,
            "context" : "mtgox.com"
        }))

    def send_order_add(self, typ, price, volume):
        """send an order"""
        reqid = "order_add:%s:%d:%d" % (typ, price, volume)
        if price > 0:
            params = {"type": typ, "price_int": price, "amount_int": volume}
        else:
            params = {"type": typ, "amount_int": volume}

        if FORCE_HTTP_API or self.config.get_bool("gox", "use_http_api"):
            api = "BTC%s/money/order/add" % self.currency
            self.enqueue_http_to_socket(api, params, reqid)
        else:
            api = "order/add"
            self.send_signed_call(api, params, reqid)

    def send_order_cancel(self, oid):
        """cancel an order"""
        params = {"oid": oid}
        reqid = "order_cancel:%s" % oid
        if FORCE_HTTP_API or self.config.get_bool("gox", "prefer_http_api"):
            api = "money/order/cancel"
            self.enqueue_http_to_socket(api, params, reqid)
        else:
            api = "order/cancel"
            self.send_signed_call(api, params, reqid)


class WebsocketClient(BaseClient):
    """this implements a connection to MtGox through the older (but faster)
    websocket protocol. Unfortuntely its just as unreliable as the socket.io."""

    def __init__(self, gox, secret, config):
        BaseClient.__init__(self, gox, secret, config)
        self.hostname = WEBSOCKET_HOST

    def _recv_thread_func(self):
        """connect to the websocket and start receiving in an infinite loop.
        Try to reconnect whenever connection is lost. Each received json
        string will be dispatched with a signal_recv signal"""
        reconnect_time = 1
        use_ssl = self.config.get_bool("gox", "use_ssl")
        wsp = {True: "wss://", False: "ws://"}[use_ssl]
        port = {True: 443, False: 80}[use_ssl]
        ws_origin = "%s:%d" % (self.hostname, port)
        ws_headers = ["User-Agent: %s" % USER_AGENT]
        while not self._terminating:  #loop 0 (connect, reconnect)
            try:
                ws_url = wsp + self.hostname \
                    + "/mtgox?Currency=" + self.currency

                self.debug("trying plain old Websocket: %s ... " % ws_url)

                self.socket = websocket.WebSocket()
                self.socket.connect(ws_url, origin=ws_origin, header=ws_headers)
                self._time_last_received = time.time()
                self.connected = True
                self.debug("connected, subscribing needed channels")
                self.channel_subscribe()

                self.debug("waiting for data...")
                while not self._terminating: #loop1 (read messages)
                    str_json = self.socket.recv()
                    self._time_last_received = time.time()
                    if str_json[0] == "{":
                        self.signal_recv(self, (str_json))

            except Exception as exc:
                self.connected = False
                if not self._terminating:
                    self.debug(exc.__class__.__name__, exc,
                        "reconnecting in %i seconds..." % reconnect_time)
                    if self.socket:
                        self.socket.close()
                    time.sleep(reconnect_time)

    def send(self, json_str):
        """send the json encoded string over the websocket"""
        self._try_send_raw(json_str)

class SocketIO(websocket.WebSocket):
    """This is the WebSocket() class with added Super Cow Powers. It has a
    different connect method so that it can connect to socket.io. It will do
    the initial HTTP request with keep-alive and then use that same socket
    to upgrade to websocket"""
    def __init__(self, get_mask_key = None):
        websocket.WebSocket.__init__(self, get_mask_key)

    def connect(self, url, **options):
        """connect to socketio and then upgrade to websocket transport. Example:
        connect('wss://websocket.mtgox.com/socket.io/1', query='Currency=EUR')"""

        def read_block(sock):
            """read from the socket until empty line, return list of lines"""
            lines = []
            line = ""
            while True:
                res = sock.recv(1)
                line += res
                if res == "":
                    return None
                if res == "\n":
                    line = line.strip()
                    if line == "":
                        return lines
                    lines.append(line)
                    line = ""

        # pylint: disable=W0212
        hostname, port, resource, is_secure = websocket._parse_url(url)
        self.sock.connect((hostname, port))
        if is_secure:
            self.io_sock = websocket._SSLSocketWrapper(self.sock)

        path_a = resource
        if "query" in options:
            path_a += "?" + options["query"]
        self.io_sock.send("GET %s HTTP/1.1\r\n" % path_a)
        self.io_sock.send("Host: %s:%d\r\n" % (hostname, port))
        self.io_sock.send("User-Agent: %s\r\n" % USER_AGENT)
        self.io_sock.send("Accept: text/plain\r\n")
        self.io_sock.send("Connection: keep-alive\r\n")
        self.io_sock.send("\r\n")

        headers = read_block(self.io_sock)
        if not headers:
            raise IOError("disconnected while reading headers")
        if not "200" in headers[0]:
            raise IOError("wrong answer: %s" % headers[0])
        result = read_block(self.io_sock)
        if not result:
            raise IOError("disconnected while reading socketio session ID")
        if len(result) != 3:
            raise IOError("invalid response from socket.io server")

        ws_id = result[1].split(":")[0]
        resource += "/websocket/" + ws_id
        if "query" in options:
            resource += "?" + options["query"]

        self._handshake(hostname, port, resource, **options)


class SocketIOClient(BaseClient):
    """this implements a connection to MtGox using the new socketIO protocol.
    This should replace the older plain websocket API"""

    def __init__(self, gox, secret, config):
        BaseClient.__init__(self, gox, secret, config)
        self.hostname = SOCKETIO_HOST
        self._keepalive_timer.connect(self.slot_keepalive_timer)


    def _recv_thread_func(self):
        """this is the main thread that is running all the time. It will
        connect and then read (blocking) on the socket in an infinite
        loop. SocketIO messages ('2::', etc.) are handled here immediately
        and all received json strings are dispathed with signal_recv."""
        use_ssl = self.config.get_bool("gox", "use_ssl")
        wsp = {True: "wss://", False: "ws://"}[use_ssl]
        while not(self._terminate_recv_thread.is_set()): #loop 0 (connect, reconnect)
            try:
                ws_url = wsp + self.hostname + "/socket.io/1"

                self.debug("trying Socket.IO: %s" % ws_url)
                self.socket = SocketIO()
                self.socket.connect(ws_url, query="Currency=" + self.gox.currency)

                if self.socket.connected:
                    self.debug("connected.")
                    self.connected = True
                    self.created = time.time()
                
                self.socket.send("1::/mtgox")
                self.debug(self.socket.recv())
                self.debug(self.socket.recv())
                self.channel_subscribe()
                self.debug("waiting for data...")
                while not self._terminate_recv_thread.is_set(): #loop1 (read messages)
                    msg = self.socket.recv()
                    if msg == "2::":
#                        self.debug("### ping -> pong")
#                        self.socket.send("2::")
                        continue
                    prefix = msg[:10]
                    if prefix == "4::/mtgox:":
                        str_json = msg[10:]
                        if str_json[0] == "{":
                            self._time_last_received = time.time()
                            self.signal_recv(self, (str_json))
            except Exception as exc:
                self.connected = False
                self.debug(exc.__class__.__name__, exc, "reconnecting in 1 seconds...")
                self.socket.close()
                self._terminate_recv_thread.wait(1)
    def send(self, json_str):
        """send a string to the websocket. This method will prepend it
        with the 1::/mtgox: that is needed for the socket.io protocol
        (as opposed to plain websockts) and the underlying websocket
        will then do the needed framing on top of that."""
        self._try_send_raw("4::/mtgox:" + json_str)

    def slot_keepalive_timer(self, _sender, _data):
        """send a keepalive, just to make sure our socket is not dead"""
        self._try_send_raw("2::")
        self.request_order_lag()


# pylint: disable=R0902
class Gox(BaseObject):
    """represents the API of the MtGox exchange. An Instance of this
    class will connect to the streaming socket.io API, receive live
    events, it will emit signals you can hook into for all events,
    it has methods to buy and sell"""

    def __init__(self, secret, config):
        """initialize the gox API but do not yet connect to it."""
        BaseObject.__init__(self)

        self.signal_depth           = Signal()
        self.signal_trade           = Signal()
        self.signal_ticker          = Signal()
        self.signal_fulldepth       = Signal()
        self.signal_fullhistory     = Signal()
        self.signal_wallet          = Signal()
        self.signal_userorder       = Signal()
        self.signal_orderlag        = Signal()

        self.signal_backupticker = Signal()

        # the following are not fired by gox itself but by the
        # application controlling it to pass some of its events
        self.signal_keypress        = Signal()
        self.signal_strategy_unload = Signal()

        self._idkey = None
        self.wallet = {}
        self.order_lag = 0
#added 
        self.cPrec = D('0.00001')
        self.bPrec = D('0.00000001')
        self.last_tid = 0
        self.count_submitted = 0  # number of submitted orders not yet acked
        self._time_last_received = 0
        self.LASTTICKER = time.time() - 20
        self.LASTLAG = time.time() - 20  

        self.config = config
        self.currency = config.get("gox", "currency", "USD")

        Signal.signal_error.connect(self.signal_debug)

        timeframe = 60 * config.get_int("gox", "history_timeframe")
        if not timeframe:
            timeframe = 60 * 15
        self.history = History(self, timeframe)
        self.history.signal_debug.connect(self.signal_debug)
        self.history.signal_changed.connect(self.slot_history_changed)
        self.orderbook = OrderBook(self)
        self.orderbook.signal_debug.connect(self.signal_debug)

        use_websocket = self.config.get_bool("gox", "use_plain_old_websocket")
        if "socketio" in FORCE_PROTOCOL:
            use_websocket = False
        if "websocket" in FORCE_PROTOCOL:
            use_websocket = True
        if use_websocket:
            self.client = WebsocketClient(self, secret, config)
        else:
            self.client = SocketIOClient(self, secret, config)
        self.client.signal_debug.connect(self.signal_debug)
        self.client.signal_recv.connect(self.slot_recv)
        self.client.signal_fulldepth.connect(self.signal_fulldepth)
        self.client.signal_fullhistory.connect(self.signal_fullhistory)
##New
        self._switchclient = Timer(15)
        self._switchclient.connect(self.slot_switchclient)
        self.signal_backupticker.connect(self.orderbook.slot_ticker)
##Code to switch between SocketIO/websocket/HTTP ticker
    def slot_switchclient(self, _sender, _data):
        """find out if the socket is blank in regular intervals, and if it is, request new HTTP depth"""

        silent = time.time() - self.client._time_last_received
        if silent > 60:
            if time.time() - self.client.created > 60:
                self.debug("NO DATA received over SocketIO for %d seconds!!!!!! Restarting SocketIO Client" % silent)
                self.client.socket.close()
            if time.time() - self.orderbook.fulldepth_time > 30:
                self.client.request_fulldepth()


    def start(self):
        """connect to MtGox and start receiving events."""
        self.client.start()

    def stop(self):
        """shutdown the client"""
        self.client.stop()
        
    def order(self, typ, price, volume):
        """place pending order. If price=0 then it will be filled at market"""
        self.client.send_order_add(typ, price, volume)

    def buy(self, price, volume):
        """new buy order, if price=0 then buy at market"""
        self.order("bid", price, volume)

    def sell(self, price, volume):
        """new sell order, if price=0 then sell at market"""
        self.order("ask", price, volume)

    def cancel(self, oid):
        """cancel order"""
        self.client.send_order_cancel(oid)

    def cancel_by_price(self, price):
        """cancel all orders at price"""
        for i in reversed(range(len(self.orderbook.owns))):
            order = self.orderbook.owns[i]
            if order.price == price:
                if order.oid != "":
                    self.cancel(order.oid)

    def cancel_by_type(self, typ=None):
        """cancel all orders of type (or all orders if type=None)"""
        sentacancel = False
        for i in reversed(range(len(self.orderbook.owns))):
            order = self.orderbook.owns[i]
            if typ == None or typ == order.typ:
                if order.oid != "":
                    self.cancel(order.oid)
                    sentacancel = True
        return sentacancel

    def slot_recv(self, dummy_sender, data):
        """Slot for signal_recv, handle new incoming JSON message. Decode the
        JSON string into a Python object and dispatch it to the method that
        can handle it."""
        (str_json) = data
        handler = None
        msg = json.loads(str_json)
        if "op" in msg:
            try:
                msg_op = msg["op"]
                handler = getattr(self, "_on_op_" + msg_op)

            except AttributeError:
                self.debug("slot_recv() ignoring: op=%s" % msg_op)
        else:
            self.debug("slot_recv() ignoring:", msg)

        if handler:
            handler(msg)
    
    def slot_history_changed(self, _sender, _data):
        """this is a small optimzation, if we tell the client the time
        of the last known candle then it won't fetch full history next time"""
        last_candle = self.history.last_candle()
        if last_candle:
            self.client.history_last_candle = last_candle.tim

    def _on_op_error(self, msg):
        """handle error mesages (op:error)"""
        self.debug("_on_op_error()", msg)

    def _on_op_subscribe(self, msg):
        """handle subscribe messages (op:subscribe)"""
        self.debug("subscribed channel", msg["channel"])
        
    def _on_op_unsubscribe(self, msg):
        """handle unsubscribe messages (op:unsubscribe)"""
        self.debug("unsubscribed channel", msg["channel"])        

    def _on_op_result(self, msg):
        """handle result of authenticated API call (op:result, id:xxxxxx)"""
        result = msg["result"]
        reqid = msg["id"]

        if reqid == "idkey":
            self.debug("### got idkey, subscribing to account messages")
            self._idkey = result
            self.client.send(json.dumps({"op":"mtgox.subscribe", "key":result}))

        elif reqid == "orders":
            self.debug("### got own order list")
            self.count_submitted = 0
            self.orderbook.init_own(result)
            self.debug("### have %d own orders for BTC/%s" %
                (len(self.orderbook.owns), self.currency))

        elif reqid == "info":
            self.debug("### got account info")
            gox_wallet = result["Wallets"]
            self.wallet = {}
            for currency in gox_wallet:
                self.wallet[currency] = int(
                    gox_wallet[currency]["Balance"]["value_int"])
            self.signal_wallet(self, ())

        elif reqid == "order_lag":
            lag_usec = result["lag"]
            lag_text = result["lag_text"]
            self.debug("### got order lag: %s" % lag_text)
            self.order_lag = lag_usec
            self.signal_orderlag(self, (lag_usec, lag_text))

        elif "order_add:" in reqid:
            # order/add has been acked and we got an oid, now we can already
            # insert a pending order into the owns list (it will be pending
            # for a while when the server is busy but the most important thing
            # is that we have the order-id already).
            parts = reqid.split(":")
            typ = parts[1]
            price = int(parts[2])
            volume = int(parts[3])
            oid = result
            self.debug("### got ack for order/add:", typ, price, volume, oid)
            self.orderbook.add_own(Order(price, volume, typ, oid, "pending"))
            self.count_submitted -= 1
        elif "order_cancel:" in reqid:
            # cancel request has been acked but we won't remove it from our
            # own list now because it is still active on the server.
            # do nothing now, let things happen in the user_order message
            parts = reqid.split(":")
            oid = parts[1]
            self.debug("### got ack for order/cancel:", oid)

        else:
            self.debug("_on_op_result() ignoring:", msg)

    def _on_op_private(self, msg):
        """handle op=private messages, these are the messages of the channels
        we subscribed (trade, depth, ticker) and also the per-account messages
        (user_order, wallet, own trades, etc)"""
        private = msg["private"]
        handler = None
        try:
            handler = getattr(self, "_on_op_private_" + private)
        except AttributeError:
            self.debug("_on_op_private() ignoring: private=%s" % private)
        if handler:
            handler(msg)

    def _on_op_private_ticker(self, msg):
        """handle incoming ticker message (op=private, private=ticker)"""
        msg = msg["ticker"]
        if msg["sell"]["currency"] != self.currency:
            return
        ask = int(msg["sell"]["value_int"])
        bid = int(msg["buy"]["value_int"])

        now = float(msg["now"]) / 1E6
        if now - self.LASTTICKER > 20:    #only show the ticker every 20 seconds.
            self.LASTTICKER = now
            self.debug(" tick:  bid:", int2str(bid, self.currency),"   ask:", int2str(ask, self.currency))

        self.signal_ticker(self, (bid, ask))

    def _on_op_private_depth(self, msg):
        """handle incoming depth message (op=private, private=depth)"""
        msg = msg["depth"]
        if msg["currency"] != self.currency:
            return
        type_str = msg["type_str"]
        price = int(msg["price_int"])
        volume = int(msg["volume_int"])
        total_volume = int(msg["total_volume_int"])

#commented out to clean up log
#        self.debug(
#            "depth: ", type_str+":", int2str(price, self.currency),
#            "vol:", int2str(volume, "BTC"),
#            "total:", int2str(total_volume, "BTC"))
        self.signal_depth(self, (type_str, price, volume, total_volume))

    def _on_op_private_trade(self, msg):
        """handle incoming trade mesage (op=private, private=trade)"""
        if msg["trade"]["price_currency"] != self.currency:
            return
        if msg["channel"] == "dbf1dee9-4f2e-4a08-8cb7-748919a71b21":
            own = False
        else:
            own = True
        date = int(msg["trade"]["date"])
        price = int(msg["trade"]["price_int"])
        volume = int(msg["trade"]["amount_int"])
        typ = msg["trade"]["trade_type"]

#         self.debug(
#             "trade:      ", int2str(price, self.currency),
#             "vol:", int2str(volume, "BTC"),
#             "type:", typ
#         )
        self.debug("trade: ", typ+":", int2str(price, self.currency),"\tvol:", int2str(volume, "BTC"))
        self.signal_trade(self, (date, price, volume, typ, own))

    def _on_op_private_user_order(self, msg):
        """handle incoming user_order message (op=private, private=user_order)"""
        order = msg["user_order"]
        oid = order["oid"]
        if "price" in order:
            if order["currency"] == self.currency:
                price = int(order["price"]["value_int"])
                volume = int(order["amount"]["value_int"])
                typ = order["type"]
                status = order["status"]
                self.signal_userorder(self,
                    (price, volume, typ, oid, status))

        else: # removed (filled or canceled)
            self.signal_userorder(self, (0, 0, "", oid, "removed"))

    def _on_op_private_wallet(self, msg):
        """handle incoming wallet message (op=private, private=wallet)"""
        balance = msg["wallet"]["balance"]
        currency = balance["currency"]
        total = int(balance["value_int"])
        self.wallet[currency] = total
        self.signal_wallet(self, None)

    def _on_op_private_lag(self, msg):
        """handle the lag message"""
        self.order_lag = int(msg["lag"]["age"])
        if self.order_lag < 60000000:
            text = "%0.3f s" % (int(self.order_lag / 1000) / 1000.0)
        else:
            text = "%d s" % (int(self.order_lag / 1000000))
        self.signal_orderlag(self, (self.order_lag, text))

    def _on_op_remark(self, msg):
        """handler for op=remark messages"""

        if "success" in msg and not msg["success"]:
            if msg["message"] == "Invalid call":
                self._on_invalid_call(msg)
                return
            if msg["message"] == "Order not found":
                self._on_order_not_found(msg)
                return

        # we should log this, helps with debugging
        self.debug(msg)

    def _on_invalid_call(self, msg):
        """this comes as an op=remark message and is a strange mystery"""
        # Workaround: Maybe a bug in their server software,
        # I don't know what's missing. Its all poorly documented :-(
        # Sometimes some API calls fail the first time for no reason,
        # if this happens just send them again. This happens only
        # somtimes (10%) and sending them again will eventually succeed.

        if msg["id"] == "idkey":
            self.debug("### resending private/idkey")
            self.client.send_signed_call("private/idkey", {}, "idkey")

        elif msg["id"] == "info":
            self.debug("### resending private/info")
            self.client.send_signed_call("private/info", {}, "info")

        elif msg["id"] == "orders":
            self.debug("### resending private/orders")
            self.client.send_signed_call("private/orders", {}, "orders")

        elif msg["id"] == "order_lag":
            self.debug("### resending order/lag")
            self.client.send_signed_call("order/lag", {}, "order_lag")

        elif "order_add:" in msg["id"]:
            parts = msg["id"].split(":")
            typ = parts[1]
            price = int(parts[2])
            volume = int(parts[3])
            self.debug("### resending failed", msg["id"])
            self.client.send_order_add(typ, price, volume)

        elif "order_cancel:" in msg["id"]:
            parts = msg["id"].split(":")
            oid = parts[1]
            self.debug("### resending failed", msg["id"])
            self.client.send_order_cancel(oid)

        else:
            self.debug("_on_invalid_call() ignoring:", msg)

    def _on_order_not_found(self, msg):
        """this means we have sent order/cancel with non-existing oid"""
        parts = msg["id"].split(":")
        oid = parts[1]
        self.debug("### got 'Order not found' for", oid)
        # we are now going to fake a user_order message (the one we
        # obviously missed earlier) that will have the effect of
        # removing the order cleanly.
        fakemsg = {"user_order": {"oid": oid}}
        self._on_op_private_user_order(fakemsg)

class Level:
    """represents a level in the orderbook"""
    def __init__(self, price, volume):
        self.price = price
        self.volume = volume
        self.own_volume = 0

class Order:
    """represents an order in the orderbook"""

    def __init__(self, price, volume, typ, oid="", status=""):
        """initialize a new order object"""
        self.price = price
        self.volume = volume
        self.typ = typ
        self.oid = oid
        self.status = status


class OrderBook(BaseObject):
    """represents the orderbook. Each Gox instance has one
    instance of OrderBook to maintain the open orders. This also
    maintains a list of own orders belonging to this account"""

    def __init__(self, gox):
        """create a new empty orderbook and associate it with its
        Gox instance"""
        BaseObject.__init__(self)
        self.gox = gox

        self.signal_changed = Signal()
        self.signal_owns_changed = Signal()
#added to delay startup of main program until its downloaded and this variable is True.
        self.fulldepth_downloaded = False
        self.fulldepth_time = 0

        gox.signal_ticker.connect(self.slot_ticker)
        gox.signal_depth.connect(self.slot_depth)
        gox.signal_trade.connect(self.slot_trade)
        gox.signal_userorder.connect(self.slot_user_order)
        gox.signal_fulldepth.connect(self.slot_fulldepth)

        self.bids = [] # list of Order(), highest bid first
        self.asks = [] # list of Order(), lowest ask first
        self.owns = [] # list of Order(), unordered list

        self.bid = 0
        self.ask = 0
        self.last_trade = Order(0,0,"","","")
        self.total_bid = 0
        self.total_ask = 0

    def slot_ticker(self, dummy_sender, data):
        """Slot for signal_ticker, incoming ticker message"""
        (bid, ask) = data
        self.bid = bid
        self.ask = ask
        self._repair_crossed_asks(ask)
        self._repair_crossed_bids(bid)
        self.signal_changed(self, None)

    def slot_depth(self, dummy_sender, data):
        """Slot for signal_depth, process incoming depth message"""
        (typ, price, _voldiff, total_vol) = data
        toa, tob = self.total_ask, self.total_bid
        if typ == "ask":
            self._update_asks(price, total_vol)
        if typ == "bid":
            self._update_bids(price, total_vol)

        if (toa, tob) != (self.total_ask, self.total_bid):
            self.signal_changed(self, None)          

    def slot_trade(self, dummy_sender, data):
        """Slot for signal_trade event, process incoming trade messages.
        For trades that also affect own orders this will be called twice:
        once during the normal public trade message, affecting the public
        bids and asks and then another time with own=True to update our
        own orders list"""
        (dummy_date, price, volume, typ, own) = data
        if own:
            self.debug("own order was filled")
            # nothing special to do here, there will also be
            # separate user_order messages to update my owns list

        else:
            voldiff = -volume
            if typ == "bid":  # trade_type=bid means an ask order was filled
                self._repair_crossed_asks(price)
                if len(self.asks):
                    if self.asks[0].price == price:
                        self.asks[0].volume -= volume
                        if self.asks[0].volume <= 0:
                            voldiff -= self.asks[0].volume
                            self.asks.pop(0)
                            self._update_total_ask(voldiff)
                if len(self.asks):
                    self.ask = self.asks[0].price

            if typ == "ask":  # trade_type=ask means a bid order was filled
                self._repair_crossed_bids(price)
                if len(self.bids):
                    if self.bids[0].price == price:
                        self.bids[0].volume -= volume
                        if self.bids[0].volume <= 0:
                            voldiff -= self.bids[0].volume
                            self.bids.pop(0)
                            self._update_total_bid(voldiff, price)
                if len(self.bids):
                    self.bid = self.bids[0].price
        self.last_trade = Order(price,volume,typ,dummy_date,"last_trade")
        self.signal_changed(self, None)

    def slot_user_order(self, dummy_sender, data):
        """Slot for signal_userorder, process incoming user_order mesage"""
        (price, volume, typ, oid, status) = data
        if status == "removed":
            for i in range(len(self.owns)):
                if self.owns[i].oid == oid:
                    order = self.owns[i]
                    self.debug(
                        "### removing %s order %s " % (order.typ,oid),
                        "price:", int2str(order.price, self.gox.currency),
                        "volume:", int2str(order.volume, "BTC"),
                        "type:", order.typ)
                    self.owns.pop(i)
                    break
        else:
            found = False
            for order in self.owns:
                if order.oid == oid:
                    found = True
                    order.price = price
                    order.volume = volume
                    order.typ = typ
                    order.oid = oid
                    if not(status == order.status):
                        self.debug(
                            "### updating %s order %s " % (typ,oid),
                            "price", int2str(price, self.gox.currency),
                            "volume:", int2str(volume, "BTC"),
                            "status:", status)
                        order.status = status
                    break

            if not found:
                self.debug(
                    "### adding %s order %s " % (typ,oid),
                    "price", int2str(price, self.gox.currency),
                    "volume:", int2str(volume, "BTC"),
                    "status:", status)
                self.owns.append(Order(price, volume, typ, oid, status))

        self.signal_changed(self, None)
        self.signal_owns_changed(self, None)

    def slot_fulldepth(self, dummy_sender, data):
        """Slot for signal_fulldepth, process received fulldepth data.
        This will clear the book and then re-initialize it from scratch."""
        (depth) = data
        self.debug("### got full depth: updating orderbook...")
        self.bids = []
        self.asks = []
        self.total_ask = 0
        self.total_bid = 0
        if "error" in depth:
            self.debug("### ", depth["error"])
            return
        for order in depth["data"]["asks"]:
            price = int(order["price_int"])
            volume = int(order["amount_int"])
            self._update_total_ask(volume)
            self.asks.append(Order(price, volume, "ask"))
        for order in depth["data"]["bids"]:
            price = int(order["price_int"])
            volume = int(order["amount_int"])
            self._update_total_bid(volume, price)
            self.bids.insert(0, Order(price, volume, "bid"))

        self.bid = self.bids[0].price
        self.ask = self.asks[0].price
#added this        
        self.fulldepth_downloaded = True
        self.fulldepth_time = time.time()
        self.signal_changed(self, None)
        time.sleep(0.2)
        self.fulldepth_downloaded = False

    def _repair_crossed_bids(self, bid):
        """remove all bids that are higher that official current bid value,
        this should actually never be necessary if their feed would not
        eat depth- and trade-messages occaionally :-("""
        while len(self.bids) and self.bids[0].price > bid:
            price = self.bids[0].price
            volume = self.bids[0].volume
            self._update_total_bid(-volume, price)
            self.bids.pop(0)

    def _repair_crossed_asks(self, ask):
        """remove all asks that are lower that official current ask value,
        this should actually never be necessary if their feed would not
        eat depth- and trade-messages occaionally :-("""
        while len(self.asks) and self.asks[0].price < ask:
            volume = self.asks[0].volume
            self._update_total_ask(-volume)
            self.asks.pop(0)

    def _update_asks(self, price, total_vol):
        """update volume at this price level, remove entire level
        if empty after update, add new level if needed."""
        (index, level) = self._find_level_or_insert_new("ask", price)
        voldiff = total_vol - level.volume
        if total_vol == 0:
            self.asks.pop(index)
        else:
            level.volume = total_vol
        self._update_total_ask(voldiff)
#added this        
        self.ask = self.asks[0].price

    def _update_bids(self, price, total_vol):
        """update volume at this price level, remove entire level
        if empty after update, add new level if needed."""
        (index, level) = self._find_level_or_insert_new("bid", price)
        voldiff = total_vol - level.volume
        if total_vol == 0:
            self.bids.pop(index)
        else:
            level.volume = total_vol
        self._update_total_bid(voldiff, price)
#added this
        self.bid = self.bids[0].price

    def _update_total_ask(self, volume):
        """update total BTC on the ask side"""
        self.total_ask += int2float(volume, "BTC")

    def _update_total_bid(self, volume, price):
        """update total fiat on the bid side"""
        self.total_bid += int2float(volume, "BTC") * int2float(price, self.gox.currency)

    def _update_level_own_volume(self, typ, price, own_volume):
        """update the own_volume cache in the Level object at price"""
        (_index, level) = self._find_level_or_insert_new(typ, price)
        level.own_volume = own_volume

    def _find_level_or_insert_new(self, typ, price):
        """find the Level() object in bids or asks or insert a new
        Level() at the correct position. Returns tuple (index, level)"""
        lst = {"ask": self.asks, "bid": self.bids}[typ]
        comp = {"ask": lambda x, y: x < y, "bid": lambda x, y: x > y}[typ]
        low = 0
        high = len(lst)

        # binary search
        while low < high:
            mid = (low + high) // 2
            midval = lst[mid].price
            if comp(midval, price):
                low = mid + 1
            elif comp(price, midval):
                high = mid
            else:
                return (mid, lst[mid])

        # not found, create new Level() and insert
        level = Level(price, 0)
        lst.insert(low, level)
        return (low, level)

    def get_own_volume_at(self, price, typ=None):
        """returns the sum of the volume of own orders at a given price. This
        method will not look up the cache in the bids or asks lists, it will
        use the authoritative data from the owns list bacause this method is
        also used to calculate these cached values in the first place."""
        volume = 0
        for order in self.owns:
            if order.price == price and (not typ or typ == order.typ):
                volume += order.volume
        return volume

    def have_own_oid(self, oid):
        """do we have an own order with this oid in our list already?"""
        for order in self.owns:
            if order.oid == oid:
                return True
        return False

    def init_own(self, own_orders):
        """called by gox when the initial order list is downloaded,
        this will happen after connect or reconnect"""
        self.owns = []

        # also reset the own volume cache in bids and ass list
        for level in self.bids + self.asks:
            level.own_volume = 0

        if own_orders:
            for order in own_orders:
                if order["currency"] == self.gox.currency \
                and order["item"] == "BTC":
                    self._add_own(Order(
                        int(order["price"]["value_int"]),
                        int(order["amount"]["value_int"]),
                        order["type"],
                        order["oid"],
                        order["status"]
                    ))

        self.signal_changed(self, None)
        self.signal_owns_changed(self, None)

    def add_own(self, order):
        """called by gox when a new order has been acked
        after it has been submitted. This is a separate method because
        we need to fire the *_changed signals when this happens"""
        self._add_own(order)
        self.signal_changed(self, None)
        self.signal_owns_changed(self, None)

    def _add_own(self, order):
        """add order to the list of own orders. This method is used during
        initial download of complete order list and also when a new order
        is inserted after receiving the ack (after order/add)."""
        if not self.have_own_oid(order.oid):
            self.owns.append(order)

        # update own volume in that level:
        self._update_level_own_volume(
            order.typ,
            order.price,
            self.get_own_volume_at(order.price, order.typ)
        )
