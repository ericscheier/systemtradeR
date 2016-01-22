import threading
import websocket
import socket
import cjson
import time
import urllib2
import json
import json_ascii
import winsound         #plays beeps for alerts 
import time
from decimal import Decimal as D    #renamed to D for simplicity.
import os

# data partial path directory
fullpath = os.path.dirname(os.path.realpath(__file__))
if os.name == 'nt':
    partialpath=os.path.join(fullpath + '\\..\\data\\')
else:
    partialpath=os.path.join(fullpath + '/../data/')

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

# def get_httpticker():
#     url = "http://data.mtgox.com/api/1/BTCUSD/ticker"
#     req = urllib2.Request(url)
#     resp = urllib2.urlopen(req)
#     data = json.load(resp)
#     return data

def serialize(obj):
    return cjson.encode(obj)

def deserialize(msg):
    return cjson.decode(msg)

CHANNELS = {}
#CHANNELS["dbf1dee9-4f2e-4a08-8cb7-748919a71b21"] = "trades"
CHANNELS["d5f06780-30a8-4a48-a2f8-7ed181b4a13f"] = "ticker"
#CHANNELS["85174711-be64-4de1-b783-0628995d7914"] = "lag"
#CHANNELS["24e67e0d-1cad-4cc0-9e7a-f8523ef460fe"] = "depth"

# CURRENCY = "USD"


# def int2str(value_int, CURRENCY):
#     """return currency integer formatted as a string"""
#     if CURRENCY == "BTC":
#         return ("%s" % (value_int / 1E8))
#     if CURRENCY == "JPY":
#         return ("%s" % (value_int / 1E3))
#     else:
#         return ("%s" % (value_int / 1E5))

# def on_op_private_depth(msg):
#     """handle incoming depth message (op=private, private=depth)"""
#     msg = msg["depth"]
#     if msg["currency"] != CURRENCY:
#         return
#     type_str = msg["type_str"]
#     price = int(msg["price_int"])
#     volume = int(msg["volume_int"])
#     total_volume = int(msg["total_volume_int"])

#     print "depth:  ", type_str+":", int2str(price, CURRENCY),"vol:", int2str(volume, "BTC"),"total:", int2str(total_volume, "BTC")


# def on_op_private_trade(msg):
#     """handle incoming trade mesage (op=private, private=trade)"""
#     msg = msg["trade"]
#     if msg["price_currency"] != CURRENCY:
#         return
#     typ = msg["trade_type"]
#     date = int(msg["date"])
#     price = int(msg["price_int"])
#     volume = int(msg["amount_int"])

#     print "TRADE: ", typ+":", int2str(price, CURRENCY),"\tvol:", int2str(volume, "BTC")

def on_error(error):
    print error
def on_close(ws):
    ws.close()
    print "####  closed  ####"
def on_open():
    print "#### connected ####"
def on_reconnect():
    print "#### reconnecting... ####"
    time.sleep(15)      #wait 15 seconds before trying to reconnect.


def on_op_private_ticker(msg):
    """handle incoming ticker message (op=private, private=ticker)"""
    msg = msg["ticker"]
    if msg["sell"]["currency"] != CURRENCY:
        return
    ask = int(msg["sell"]["value_int"])
    bid = int(msg["buy"]["value_int"])

    # print "\nBid:", int2str(bid, CURRENCY)
    # print "Ask:", int2str(ask, CURRENCY)
    # print " "
    #return int2str(bid, CURRENCY),int2str(ask, CURRENCY)
    return bid/1E5,ask/1E5

def on_message(ws,message):
    data = deserialize(message)
    channel = CHANNELS.get(data.get('channel'))
    # if channel == "trades":
    #     on_op_private_trade(data)        
    # elif channel == "depth":
    #     on_op_private_depth(data)
    # elif channel == "ticker":
    #     now = float(data["ticker"]["now"]) / 1E6
    #     if now - ws.LASTTICKER > 30:    #only show the ticker every 30 seconds.
    #         ws.LASTTICKER = now
    #         on_op_private_ticker(data)
    # elif channel == "lag":
    #     now = float(data["lag"]["stamp"]) / 1E6
    #     if now - ws.LASTLAG > 15:
    #         ws.LASTLAG = now
    #         lag = str(float(data["lag"]["age"] / 1E6))
    #         print " LAG: ",lag, "seconds"
    if channel == "ticker":
        # now = float(data["ticker"]["now"]) / 1E6
        # if now - ws.LASTTICKER > 30:    #only show the ticker every 30 seconds.
        #     ws.LASTTICKER = now
        #     on_op_private_ticker(data)   
        #return on_op_private_ticker(data)
        bidticker,askticker = on_op_private_ticker(data)
        avgticker = (bidticker+askticker) /2
        text = tickeralert(avgticker)

def start_socket(idk,stop_event):
    while(not stop_event.is_set()):
        websocket.enableTrace(False)
        url = 'ws://websocket.mtgox.com/mtgox'
        ws = websocket.WebSocket()
        #ws.LASTTICKER = time.time() - 15        #sets the last ticker 30 seconds prior to now, so it shows up on first run.
        #ws.LASTLAG = time.time() - 30           #same for the lag counter
        try:
            ws.connect(url)         #try to connect
        except socket.error as error:
            on_error(error)
            on_reconnect()
            continue
        on_open()
        #subscribeto = serialize({"op":"mtgox.subscribe", "type":"lag"})        
                     #serialize({"op":"unsubscribe", "channel":"24e67e0d-1cad-4cc0-9e7a-f8523ef460fe"})
        #ws.send(subscribeto)
        
        try:
            while(not stop_event.is_set()):
                data = ws.recv()    #start receiving data
                on_message(ws,data)
        except KeyboardInterrupt as e:
            on_close(ws)
            return
        except Exception as error:
            on_error(error)
            on_close(ws)
            on_reconnect()                       #try to reconnect

"""Logs ticker to file, spits out an alert and beeps if last price is above or below the range given\n""" \
"""Range window is modified and readjusted\n""" \
"""NOTE: RUNS AS A BACKGROUND PROCESS!!!!!!\n""" \
"""usage: updown <low> <high>\n""" \
"""Shutdown: updown exit  """
def tickeralert(last):
    if last > low and last < high:
        pass
        #last falls between given variance range, keep tracking
    elif last >= high:
        print "ALERT!! Ticker has risen above range %s-%s. Price is now: %s" % (low,high,last)
        for x in range(2,25):
            winsound.Beep(x*100,90)  #frequency(Hz),duration(ms)
        low = high - 0.5
        lowsell = low*(1+txfee*2)
        high = low + 3
        print "New range is: %s-%s" % (low,high)
    elif last == low or last == high:
        print "ALERT!! Ticker is exactly on the boundary of %s" % (last)
    else:
        print "ALERT!! Ticker has fallen below range %s-%s. Price is now: %s" % (low,high,last)
        for x in range(25,2,-1):
            winsound.Beep(x*100,90)
        high = low + 1
        low = high -3
        print "New range is: %s-%s" % (low,high)
    return json.dumps({"time":time.time(),"lastprice":last})
    
def main():
    class Shell(cmd.Cmd):
        def __init__(self):
            self.onecmd(do_start)
        def do_start:
            args = raw_input("Enter the low range and the high range for the ticker alarm: ")
            try:
                low, high = floatify(args.split())
            except Exception as e:
                print "You need to give a high and low range: low high"
                return
            global stop_event

            if args == 'exit':
                print "Shutting down background thread..."
                stop_event.set()
            else:
                stop_event = threading.Event()
                thread1 = threading.Thread(target = start_socket, args=(None,stop_event)).start()
                
    Shell().cmdloop()

main()



# """Logs ticker to file, spits out an alert and beeps if last price is above or below the range given\n""" \
# """Range window is modified and readjusted\n""" \
# """NOTE: RUNS AS A BACKGROUND PROCESS!!!!!!\n""" \
# """usage: updown <low> <high>\n""" \
# """Shutdown: updown exit  """
# def tickeralert(firstarg,stop_event):
#     try:
#         low, high = floatify(args.split())
#     except Exception as e:
#         print "You need to give a high and low range: low high"
#         return
#     #Log lastprice to the ticker log file
#     with open(os.path.join(partialpath + 'mtgox_last.txt'),'a') as f:
#         while(not stop_event.is_set()):
#             ticker = mtgox.get_ticker()
#             last = float(ticker['last'])
#             #svrtime = float(D(float(ticker["now"]) / 1E6).quantize(D("0.001")))
#             text = json.dumps({"time":time.time(),"lastprice":last})
#             f.write(text)
#             f.write("\n")
#             f.flush()
#             if last > low and last < high:
#                 #last falls between given variance range, keep tracking
#                 pass
#             elif last >= high:
#                 print "ALERT!! Ticker has risen above range %s-%s. Price is now: %s" % (low,high,last)
#                 for x in range(2,25):
#                     winsound.Beep(x*100,90)  #frequency(Hz),duration(ms)
#                 low = high - 0.5
#                 lowsell = low*(1+txfee*2)
#                 high = low + 3
#                 #spread('mtgox',mtgox,'sell', 1, lowsell, lowsell+1, 3)
#                 print "New range is: %s-%s" % (low,high)
#             elif last == low or last == high:
#                 print "ALERT!! Ticker is exactly on the boundary of %s" % (last)
#             else:
#                 print "ALERT!! Ticker has fallen below range %s-%s. Price is now: %s" % (low,high,last)
#                 for x in range(25,2,-1):
#                     winsound.Beep(x*100,90)
#                 high = low + 1
#                 low = high -3
#                 #spread('mtgox',mtgox,'buy', 1, low+1, high-1, 5)
#                 print "New range is: %s-%s" % (low,high)
#             stop_event.wait(40)
