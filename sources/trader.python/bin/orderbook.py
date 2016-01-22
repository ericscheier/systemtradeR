#!/usr/bin/env python
# Created by genBTC 3/10/2013 Updated 4/21/2013 
#Just prints out the orderbook over and over.
#makes a seperate connection to the socket to do this.

import time
import traceback
import os
import logging

from common import *
import mtgox_prof7bitapi

class LogWriter():
    """connects to gox.signal_debug and logs it all to the logfile"""
    def __init__(self, gox):
        self.gox = gox
        logging.basicConfig(filename='orderbook.log'
                           ,filemode='a'
                           ,format='%(asctime)s:%(levelname)s %(message)s'
                           ,level=logging.DEBUG
                           )
        console_logger = logging.getLogger('')
        console = logging.StreamHandler()
        console.setLevel(logging.INFO)
        console_logger.addHandler(console)        
        self.gox.signal_debug.connect(self.slot_debug)

    # pylint: disable=R0201
    def slot_debug(self, sender, (msg)):
        """handler for signal_debug signals"""
        if "https://data.mtgox.com/api/2/money/order/lag" in msg:
            return
        else:
            logging.debug("%s:%s", sender.__class__.__name__, msg)       #change this to .info to see the messages on screen.


config = mtgox_prof7bitapi.GoxConfig()
secret = mtgox_prof7bitapi.Secret()
gox = mtgox_prof7bitapi.Gox(secret, config)
logwriter = LogWriter(gox)
gox.start()
print "Starting to download fulldepth from mtgox....",
socketbook = gox.orderbook
while socketbook.fulldepth_downloaded == False:
    time.sleep(0.1)
print "Finished."


while True:                                            #infinite loop
    try:
        vintage = (time.time() - socketbook.fulldepth_time)
        if vintage > 240:
            print "Starting to download fulldepth from mtgox....",
            gox.client.request_fulldepth()
            while socketbook.fulldepth_downloaded == False:
                time.sleep(0.1)
            print "Finished."
        elif vintage > 60:
            gox.client.request_smalldepth()
        os.system(['clear','cls'][os.name == 'nt'])     #stop screen from flashing
        print ""
        printOrderBooks(socketbook.asks,socketbook.bids,20)
        time.sleep(1)                                   #refresh every 1 second
    except KeyboardInterrupt as e:                      #catch ctrl+c to exit
        print "got Ctrl+C, trying to shut down cleanly."
        gox.stop()
        break
    except Exception:
        gox.debug(traceback.format_exc())
