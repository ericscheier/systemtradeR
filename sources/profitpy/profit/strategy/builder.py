#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase, Yichun Wei
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>
#         Yichun Wei <yichun.wei@gmail.com>

from cPickle import load, loads
from time import time, strftime

from PyQt4.QtCore import QObject

from profit.lib import BasicHandler, Signals, instance, logging
from profit.series import Series, KAMA

from ib.ext.Contract import Contract
from ib.ext.Order import Order


class StrategyBuilderTicker(object):
    def __init__(self):
        self.series = {}


class SessionStrategyBuilder(QObject, BasicHandler):
    default_paramsHistoricalData = {
        ## change to use datetime
        "endDateTime"       :   strftime("%Y%m%d %H:%M:%S PST", (2007,1,1,0,0,0,0,0,0)),
        "durationStr"       :   "6 D",
        "barSizeSetting"    :   "1 min",
        "whatToShow"        :   "TRADES",   #"BID_ASK",  # "TRADES"
        "useRTH"            :   1,          # 0 for not
        "formatDate"        :   2,          # 2 for seconds since 1970/1/1
        }

    def __init__(self, parent=None):
        QObject.__init__(self, parent)
        self.tickerItems = []
        self.isActive = self.loadMessage = False
        self.threads = []
        self.tickers = []
        self.reflectSignals(Signals.contract.created)
        app = instance()
        if app:
            connect = self.connect
            connect(app, Signals.strategy.fileUpdated,
                    self.externalFileUpdated)
            connect(app, Signals.strategy.requestActivate,
                    self.requestActivation)

    @classmethod
    def paramsHistoricalData(cls, **kwds):
        cls.default_paramsHistoricalData.update(kwds)
        return cls.default_paramsHistoricalData

    def makeAccountSeries(self, *k):
        s = Series()
        return s

    def makeContract(self, symbol, **kwds):
        contract = Contract()
        kwds['symbol'] = symbol
        attrs = [k for k in dir(contract) if k.startswith('m_')]
        for attr in attrs:
            kwd = attr[2:]
            if kwd in kwds:
                setattr(contract, attr, kwds[kwd])
        ## set these even if they're already set
        contract.m_secType = kwds.get('secType', 'STK')
        contract.m_exchange = kwds.get('exchange', 'SMART')
        contract.m_currency = kwds.get('currency', 'USD')
        return contract

    def makeContracts(self):
        symids = self.symbols()
        for symbol, tickerId in symids.items():
            yield tickerId, self.makeContract(symbol)

    def makeOrder(self, **kwds):
        order = Order()
        attrs = [k for k in dir(order) if k.startswith('m_')]
        for attr in attrs:
            kwd = attr[2:]
            if kwd in kwds:
                setattr(order, attr, kwds[kwd])
        return order

    def makeTicker(self, tickerId):
        ticker = StrategyBuilderTicker()
        return ticker

    def makeTickerSeries(self, tickerId, field):
        s = Series()
        s.addIndex('ema-40', KAMA, s, 40)
        return s

    def symbols(self):
        syms = [(i.get('symbol'), i.get('tickerId'))
                for i in self.tickerItems]
        syms = [(k, v) for k, v in syms if k is not None and v is not None]
        return dict(syms)

    def load(self, source):
        if not hasattr(source, 'read'):
            source = open(source)
        try:
            instance = load(source)
        except (Exception, ), exc:
            raise Exception('Exception "%s" loading strategy.' % exc)
        for item in instance:
            methName = 'load_%s' % item.get('type', 'Unknown')
            call = getattr(self, methName, None)
            try:
                call(item)
            except (TypeError, ):
                logging.debug('Could not load strategy item: %s', item)
        for tickerId, contract in self.makeContracts():
            self.emit(Signals.contract.created, tickerId, contract)

    def load_RunnerItem(self, item):
        pass

    def load_TickerItem(self, item):
        self.tickerItems.append(item)
        self.emit(Signals.createdTicker, item['tickerId'], item)

    def requestActivation(self, strategy, activate=False):
        print '## ding ding requestActivation', strategy
        filename = strategy.get('filename', None)
        if activate:
            if filename:
                self.load(filename)
                ## cheater!
                self.parent().requestTickers()
        else:
            ## must deactivate somehow
            pass

    def externalFileUpdated(self, filename):
        print '## strategy external file updated'

    def __load(self, params):
        origintype = params.get('type', '') or 'empty'
        try:
            call = getattr(self, 'from%s' % origintype.title())
            okay, message = call(**params)
            self.loadMessage = message
            signal = Signals.strategy.loaded if okay else \
                     Signals.strategy.loadFailed
            self.emit(signal, message)
            if okay and params.get('reload', False):
                self.emit(signal, 'Strategy reloaded')
        except (Exception, ), ex:
            self.emit(Signals.strategy.loadFailed, str(ex))
