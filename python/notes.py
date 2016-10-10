import sys
import os

sys.path.append('/home/eric/Documents/GitHub/pysystemtrade')

from private.bitmex.estimatedsystem import futures_system
system=futures_system()
system.portfolio.get_notional_position("XBTUSD")


from private.bitmex.basesystem import futures_system

from sysdata.configdata import Config

my_config=Config("private.bitmex.config.yaml")
my_data=csvFuturesData("private.bitmex.data")

from systems.provided.futures_chapter15.estimatedsystem import futures_system
system=futures_system(config=my_config, data=my_data)
system.portfolio.get_notional_position("XBTUSD")