#!/usr/bin/env python
# -*- coding: utf-8 -*-


# Copyright 2007 Troy Melhase, Yichun Wei
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>
#         Yichun Wei <yichun.wei@gmail.com>

import os
from cPickle import PicklingError, UnpicklingError, dump, load

from PyQt4.QtCore import QObject, QThread
from profit.lib import logging
from profit.lib import Signals


class DataCollection(QObject):
    sessionResendSignals = []

    def __init__(self, session):
        QObject.__init__(self)
        self.session = session
        self.data = {}
        session.registerMeta(self)
        for signal in self.sessionResendSignals:
            self.connect(self, signal, session, signal)

    def __contains__(self, item):
        return item in self.data

    def __getitem__(self, name):
        return self.data[name]

    def __setitem__(self, name, value):
        self.data[name] = value

    def keys(self):
        return self.data.keys()

    def items(self):
        return self.data.items()

    def setdefault(self, key, default):
        return self.data.setdefault(key, default)


class AccountCollection(DataCollection):
    sessionResendSignals = [Signals.createdAccountData, ]

    def __init__(self, session):
        DataCollection.__init__(self, session)
        self.last = {}

    def on_session_UpdateAccountValue(self, message):
        key = (message.key, message.currency, message.accountName)
        try:
            iv = float(message.value)
        except (ValueError, ):
            iv = message.value
        try:
            acctdata = self[key]
        except (KeyError, ):
            acctdata = self[key] = \
                       self.session.strategy.makeAccountSeries(key)
            self.emit(Signals.createdAccountData, key, acctdata, iv)
        acctdata.append(iv)
        self.last[key] = iv


class ContractDataCollection(DataCollection):
    sessionResendSignals = [Signals.contract.added, ]

    def __setitem__(self, tickerId, contract):
        ## maybe enforce types?
        DataCollection.__setitem__(self, tickerId, contract)
        self.emit(Signals.contract.added, tickerId, contract)

    def on_session_TickPrice_TickSize(self, message):
        tickerId = message.tickerId
        if tickerId not in self:
            contract = self[tickerId] = self.session.strategy.makeContract(symbol='')
            self.emit(Signals.contract.added, tickerId, contract)


class TickerCollection(DataCollection):
    sessionResendSignals = [Signals.createdSeries, Signals.createdTicker, ]

    def __init__(self, session):
        DataCollection.__init__(self, session)
        ## have to make the strategy symbols lazy somehow
        for tid in session.strategy.symbols().values():
            self[tid] = session.strategy.makeTicker(tid)

    def on_session_TickPrice_TickSize(self, message):
        tickerId = message.tickerId
        try:
            tickerdata = self[tickerId]
        except (KeyError, ):
            tickerdata = self[tickerId] = \
                         self.session.strategy.makeTicker(tickerId)
            self.emit(Signals.createdTicker, tickerId, tickerdata)
        try:
            value = message.price
        except (AttributeError, ):
            value = message.size
        field = message.field
        try:
            seq = tickerdata.series[field]
        except (KeyError, ):
            seq = tickerdata.series[field] = \
                  self.session.strategy.makeTickerSeries(tickerId, field)
            self.emit(Signals.createdSeries, tickerId, field)
        seq.append(value)



class HistoricalDataCollection(DataCollection):
    sessionResendSignals = [Signals.histdata.start,
                            Signals.histdata.finish]

    def __init__(self, session):
        DataCollection.__init__(self, session)

    def on_session_HistoricalData(self, message):
        if message.date.startswith('finished'):
            reqId = message.reqId
            reqData = self.setdefault(reqId, {})
            histMsgs = self.session.messagesTyped['HistoricalData']
            reqData['messages'] = self.historyMessages(reqId, histMsgs)
            self.emit(Signals.histdata.finish, reqId)

    def begin(self, params):
        reqId = params['tickerId']
        reqData = self.setdefault(reqId, {})
        reqData.update(params)
        self.emit(Signals.histdata.start, reqId, reqData)
        self.session.connection.reqHistoricalData(**reqData)

    @staticmethod
    def historyMessages(reqId, msgs):
        return (m for m in msgs
                if m[1].reqId==reqId
                and not m[1].date.startswith('finished'))



class OrderDataCollection(DataCollection):
    nextId = 0

    def on_session_nextValidId(self, message):
        self.nextId = int(message.orderId)


class ErrorDataCollection(DataCollection):
    def on_session_Error(self, message):
        logging.debug(str(message))
