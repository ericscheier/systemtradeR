import websocket # websocket-client>=0.4.1 (included, otherwise downloadble)
import socket
import cjson
import time
import traceback

def serialize(obj):
    return cjson.encode(obj)

def deserialize(msg):
    return cjson.decode(msg)

CHANNELS = {}
CHANNELS["dbf1dee9-4f2e-4a08-8cb7-748919a71b21"] = "trades"
CHANNELS["d5f06780-30a8-4a48-a2f8-7ed181b4a13f"] = "ticker"
CHANNELS["85174711-be64-4de1-b783-0628995d7914"] = "lag"
#CHANNELS["24e67e0d-1cad-4cc0-9e7a-f8523ef460fe"] = "depth"

CURRENCY = "USD"


def int2str(value_int, CURRENCY):
    """return currency integer formatted as a string"""
    if CURRENCY == "BTC":
        return ("%s" % (value_int / 1E8))
    if CURRENCY == "JPY":
        return ("%s" % (value_int / 1E3))
    else:
        return ("%s" % (value_int / 1E5))

def on_op_private_ticker(msg):
    """handle incoming ticker message (op=private, private=ticker)"""
    msg = msg["ticker"]
    if msg["sell"]["currency"] != CURRENCY:
        return
    ask = int(msg["sell"]["value_int"])
    bid = int(msg["buy"]["value_int"])

    print "\nBid:", int2str(bid, CURRENCY)
    print "Ask:", int2str(ask, CURRENCY)
    print " "


def on_op_private_depth(msg):
    """handle incoming depth message (op=private, private=depth)"""
    msg = msg["depth"]
    if msg["currency"] != CURRENCY:
        return
    type_str = msg["type_str"]
    price = int(msg["price_int"])
    volume = int(msg["volume_int"])
    total_volume = int(msg["total_volume_int"])

    print "depth:  ", type_str+":", int2str(price, CURRENCY),"vol:", int2str(volume, "BTC"),"total:", int2str(total_volume, "BTC")


def on_op_private_trade(msg):
    """handle incoming trade mesage (op=private, private=trade)"""
    msg = msg["trade"]
    if msg["price_currency"] != CURRENCY:
        return
    typ = msg["trade_type"]
    date = int(msg["date"])
    price = int(msg["price_int"])
    volume = int(msg["amount_int"])

    print "TRADE: ", typ+":", int2str(price, CURRENCY),"\tvol:", int2str(volume, "BTC")

def on_message(ws,message):
    data = deserialize(message)
    channel = CHANNELS.get(data.get('channel'))
    if channel == "trades":
        on_op_private_trade(data)        
    elif channel == "depth":
        on_op_private_depth(data)
    elif channel == "ticker":
        now = float(data["ticker"]["now"]) / 1E6
        if now - ws.LASTTICKER > 20:    #only show the ticker every 20 seconds.
            ws.LASTTICKER = now
            on_op_private_ticker(data)
    elif channel == "lag":
        if data["lag"]["stamp"]:
            now = float(data["lag"]["stamp"]) / 1E6
        else:
            now = time.time()              #dummy
        if now - ws.LASTLAG > 20:
            ws.LASTLAG = now
            lag = str(float(data["lag"]["age"] / 1E6))
            print " LAG: ",lag, "seconds"


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

def main():
    while True:                     #infinite loop  
        websocket.enableTrace(False)
        url = 'wss://websocket.mtgox.com/mtgox'
        ws = websocket.WebSocket()
        ws.LASTTICKER = time.time() - 20        #sets the last ticker 20 seconds prior to now, so it shows up on first run.
        ws.LASTLAG = time.time() - 20           #same for the lag counter
        # ws.LASTRECEIVED = time.time()
        try:
            ws.connect(url)         #try to connect
        except (socket.error,websocket.WebSocketConnectionClosedException) as error:
            on_error(error)
            on_reconnect()
            continue
        on_open()
        subscribeto = serialize({"op":"mtgox.subscribe", "type":"lag"})        
                     #serialize({"op":"unsubscribe", "channel":"24e67e0d-1cad-4cc0-9e7a-f8523ef460fe"})
        ws.send(subscribeto)
        
        try:
            while True:
                data = ws.recv()    #start receiving data                
                on_message(ws,data)
                # ws.LASTRECEIVED = time.time()
                # if data == "2::":
                #     print "sending keepalive"
                #     ws.send("2::")
                #     continue
        except KeyboardInterrupt as e:
        	on_close(ws)
        	return
        except Exception as error:
            #traceback.print_exc()
            on_error(error)
            on_close(ws)
            on_reconnect()                       #try to reconnect
main()