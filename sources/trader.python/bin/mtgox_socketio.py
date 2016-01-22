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

#THIS IS A TESTING PROGRAM (yes it works but it has replacements and improvements elsewhere)
#This is set up using goxapi.py from the prof7bit goxtool github and I edited that file from the original 
#The editing consisted of modifying the way it writes the log so it prints to the screen as well,


import inspect
import json
import logging
import Queue
import sys
import time
import traceback
import threading
from urllib2 import Request as URLRequest
from urllib2 import urlopen
from urllib import urlencode
import weakref
import websocket


input = raw_input # pylint: disable=W0622,C0103


PY_VERSION = sys.version_info

if PY_VERSION < (2, 7):
    print("Sorry, minimal Python version is 2.7, you have: %d.%d"
        % (PY_VERSION.major, PY_VERSION.minor))
    sys.exit(1)



def int2str(value_int, currency):
    """return currency integer formatted as a string"""
    if currency == "BTC":
        return ("%12.8f" % (value_int / 100000000.0))
    if currency == "JPY":
        return ("%12.3f" % (value_int / 1000.0))
    else:
        return ("%7.5f" % (value_int / 100000.0))

def start_thread(thread_func):
    """start a new thread to execute the supplied function"""
    thread = threading.Thread(target=thread_func)
    thread.daemon = True
    thread.start()
    return thread


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
                    logging.critical(error)

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
        logging.debug(msg)
        print msg


class BaseClient(BaseObject):
    """abstract base class for SocketIOClient"""

    SOCKETIO_HOST = "socketio.mtgox.com"

    _last_nonce = 0
    _nonce_lock = threading.Lock()

    def __init__(self, currency):
        BaseObject.__init__(self)

        self.signal_recv        = Signal()

        self.currency = currency

        self.socket = None
        self.http_requests = Queue.Queue()

        self._recv_thread = None
        self._http_thread = None
        self._terminating = False
        self.connected = False
        self._time_last_received = 0

    def start(self):
        """start the client"""
        self._recv_thread = start_thread(self._recv_thread_func)

    def stop(self):
        """stop the client"""
        self._terminating = True
        if self.socket:
            self.debug("""closing socket""")
            self.socket.sock.close()

    def _try_send_raw(self, raw_data):
        """send raw data to the websocket or disconnect and close"""
        if self.connected:
            try:
                self.socket.send(raw_data)
            except Exception as exc:
                self.debug(exc)
                self.connected = False
                self.socket.close()

class SocketIO(websocket.WebSocket):
    """This is the WebSocket() class with added Super Cow Powers. It has a
    different connect method so that it can connect to socket.io. It will do
    the initial HTTP request with keep-alive and then use that same socket
    to upgrade to websocket"""
    def __init__(self, get_mask_key = None):
        websocket.WebSocket.__init__(self, get_mask_key)

    def connect(self, url, **options):
        """connect to socketio and then upgrade to websocket transport. Example:"""

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
        self.io_sock.send("User-Agent: genBTC-bot\r\n")
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

    def __init__(self, currency):
        BaseClient.__init__(self, currency)
        self.hostname = self.SOCKETIO_HOST

    def _recv_thread_func(self):
        """this is the main thread that is running all the time. It will
        connect and then read (blocking) on the socket in an infinite
        loop. SocketIO messages ('2::', etc.) are handled here immediately
        and all received json strings are dispathed with signal_recv."""
        use_ssl = True
        wsp = {True: "wss://", False: "ws://"}[use_ssl]
        while not self._terminating: #loop 0 (connect, reconnect)
            try:
                self.debug("*** Hint: connection problems? try: use_plain_old_websocket=True")
                
                self.debug("trying Socket.IO: %s%s ..." % (wsp,self.hostname))

                self.debug("starting to open socket")

                self.socket = SocketIO()
                self.debug("socket opened")
                self.socket.connect(wsp + self.hostname + "/socket.io/1", query="Currency=" + self.currency)

                self.connected = True
                self.debug("connected")
                self.debug("subscribing to channels")
                
                self.socket.send("1::/mtgox")
                self.send(json.dumps({"op":"mtgox.subscribe", "type":"lag"}))
                self.send(json.dumps({"op":"unsubscribe", "channel":"24e67e0d-1cad-4cc0-9e7a-f8523ef460fe"}))   #depth
                #self.send(json.dumps({"op":"unsubscribe", "channel":"d5f06780-30a8-4a48-a2f8-7ed181b4a13f"}))   #ticker

                """subscribe to the needed channels"""
                """CHANNELS is a dict because this was copied over for information purposes only..."""
                # CHANNELS = 
                #     "dbf1dee9-4f2e-4a08-8cb7-748919a71b21": "trades",
                #     "d5f06780-30a8-4a48-a2f8-7ed181b4a13f": "ticker",
                #     "24e67e0d-1cad-4cc0-9e7a-f8523ef460fe": "depth",
#                self.send(json.dumps({"op":"mtgox.subscribe", "type":"depth"}))
#                self.send(json.dumps({"op":"mtgox.subscribe", "type":"ticker"}))
#                self.send(json.dumps({"op":"mtgox.subscribe", "type":"trades"}))
#                # Once you join 1::/mtgox these are automaticlaly subscribed to

                self.debug("waiting for data...")
                while not self._terminating: #loop1 (read messages)
                    msg = self.socket.recv()
                    self._time_last_received = time.time()
                    if msg == "2::":

                        self.socket.send("2::")
                        continue
                    prefix = msg[:10]
                    if prefix == "4::/mtgox:":
                        str_json = msg[10:]
                        if str_json[0] == "{":
                            #print str_json
                            self.signal_recv(self, (str_json))

            except Exception as exc:
                self.connected = False
                if not self._terminating:
                    self.debug(exc.__class__.__name__, exc, \
                        "reconnecting in 5 seconds...")
                    if self.socket:
                        self.socket.close()
                    time.sleep(5)

    def send(self, json_str):
        """send a string to the websocket. This method will prepend it
        with the 1::/mtgox: that is needed for the socket.io protocol
        (as opposed to plain websockts) and the underlying websocket
        will then do the needed framing on top of that."""
        self._try_send_raw("4::/mtgox:" + json_str)

    def slot_keepalive_timer(self, _sender, _data):
        """send a keepalive, just to make sure our socket is not dead"""
        self.debug("sending keepalive")
        self._try_send_raw("2::")


# pylint: disable=R0902
class Gox(BaseObject):
    """represents the API of the MtGox exchange. An Instance of this
    class will connect to the streaming socket.io API, receive live
    events, it will emit signals you can hook into for all events,
    it has methods to buy and sell"""

    def __init__(self):
        """initialize the gox API but do not yet connect to it."""
        BaseObject.__init__(self)

        self.signal_depth           = Signal()
        self.signal_trade           = Signal()
        self.signal_ticker          = Signal()

#added
        self.LASTTICKER = time.time() - 20
        self.LASTLAG = time.time() - 20  

        self.currency = "USD"

        Signal.signal_error.connect(self.signal_debug)

        self.client = SocketIOClient(self.currency)

        self.client.signal_debug.connect(self.signal_debug)
        self.client.signal_recv.connect(self.slot_recv)

    def start(self):
        """connect to MtGox and start receiving events."""
        self.debug("starting gox streaming API, currency=" + self.currency)
        self.client.start()

    def stop(self):
        """shutdown the client"""
        self.debug("shutdown...")
        self.client.stop()

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

    def _on_op_error(self, msg):
        """handle error mesages (op:error)"""
        self.debug("_on_op_error()", msg)

    def _on_op_subscribe(self, msg):
        """handle subscribe messages (op:subscribe)"""
        self.debug("subscribed channel", msg["channel"])

    def _on_op_unsubscribe(self, msg):
        """handle unsubscribe messages (op:unsubscribe)"""
        self.debug("unsubscribed channel", msg["channel"])


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

    def _on_op_private_lag(self,msg):
        """handle incoming ticker message (op=private, private=lag)"""
        msg = msg["lag"]
        lag = str(float(msg["age"] / 1E6))
#added
        stamp = msg["stamp"]
        if stamp:
            now = float(stamp) / 1E6
        else:
            now = time.time()              #dummy
        if now - self.LASTLAG > 20:
            self.LASTLAG = now
            lag = str(float(msg["age"] / 1E6))
            self.debug(" LAG: ",lag, "seconds")

    def _on_op_private_ticker(self, msg):
        """handle incoming ticker message (op=private, private=ticker)"""
        msg = msg["ticker"]
        if msg["sell"]["currency"] != self.currency:
            return
        ask = int(msg["sell"]["value_int"])
        bid = int(msg["buy"]["value_int"])

#added        
        now = float(msg["now"]) / 1E6
        if now - self.LASTTICKER > 20:    #only show the ticker every 20 seconds.
            self.LASTTICKER = now
            self.debug("\nBid:", int2str(bid, self.currency),"\nAsk:", int2str(ask, self.currency),"\n")    
        
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

        self.debug("depth:  ", type_str+":", int2str(price, self.currency),"vol:", int2str(volume, "BTC"),"total:", int2str(total_volume, "BTC"))
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

        self.debug("TRADE: ", typ+":", int2str(price, self.currency),"\tvol:", int2str(volume, "BTC"))
        self.signal_trade(self, (date, price, volume, typ, own))

    def _on_op_remark(self, msg):
        """handler for op=remark messages"""

        if "success" in msg and not msg["success"]:
            if msg["message"] == "Invalid call":
                self._on_invalid_call(msg)
                return

        # we should log this, helps with debugging
        self.debug(msg)

    def _on_invalid_call(self, msg):
        """this comes as an op=remark message and is a strange mystery"""
        self.debug("_on_invalid_call() ignoring:", msg)


class LogWriter():
    """connects to gox.signal_debug and logs it all to the logfile"""
    def __init__(self, gox):
        self.gox = gox
        logging.basicConfig(filename='socketio_mtgox.log'
                           ,filemode='w'
                           ,format='%(asctime)s:%(levelname)s: %(message)s'
                           ,level=logging.DEBUG
                           )
        self.gox.signal_debug.connect(self.slot_debug)

    # pylint: disable=R0201
    def slot_debug(self, sender, (msg)):
        """handler for signal_debug signals"""
        logging.debug("%s:%s", sender.__class__.__name__, msg)


def main():
    """main funtion"""

    gox = Gox()
    logwriter = LogWriter(gox)
    gox.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt as e:
        print "got Ctrl+C, trying to shut down cleanly."
        gox.stop()
    except Exception:
        gox.debug(traceback.format_exc())
# The End.


if __name__ == "__main__":
    main()