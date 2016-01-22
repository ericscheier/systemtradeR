#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase, Yichun Wei
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>
#         Yichun Wei <yichun.wei@gmail.com>

from cPickle import UnpicklingError, load
from random import randint
from time import time

from PyQt4.QtCore import QObject, SIGNAL

from ib.opt import ibConnection
from ib.opt.message import messageTypeNames

from profit.lib import Signals, logging
from profit.models.executions import ExecutionsModel
from profit.models.histdata import HistDataRequestModel
from profit.models.orders import OrdersModel
from profit.models.portfolio import PortfolioModel
from profit.models.strategy import StrategyModel
from profit.models.tickers import TickersModel
from profit.session import collection
from profit.session.savethread import SaveThread
from profit.session.requestthread import RequestThread
from profit.strategy.builder import SessionStrategyBuilder


class DataMaps(object):
    def __init__(self, session):
        self.account = collection.AccountCollection(session)
        self.ticker = collection.TickerCollection(session)


class DataModels(object):
    def __init__(self, session):
        self.executions = ExecutionsModel(session)
        self.histdata = HistDataRequestModel(session)
        self.orders = OrdersModel(session)
        self.portfolio = PortfolioModel(session)
        self.strategy = StrategyModel(session)
        self.tickers = TickersModel(session)


class Session(QObject):
    """ This is the big-honkin Session class.

    """
    def __init__(self, strategy=None):
        QObject.__init__(self)
        self.requestThread = requestThread = RequestThread(self)
        requestThread.start()
        self.strategy = strategy if strategy else SessionStrategyBuilder(self)
        self.connection = self.filename = None
        self.messages = []
        self.messagesBare = []
        self.messagesTyped = {}
        self.savedLength = 0
        self.maps = DataMaps(self)
        self.models = DataModels(self)

    def __str__(self):
        """ x.__str__() <==> str(x)

        @return string representation of this object
        """
        format = '<Session 0x%x messages:%s connected:%s>'
        args = id(self), len(self.messages), self.isConnected()
        return  format % args

    def isConnected(self):
        """ Returns True if this object has a TWS connection.

        @return True if this object is connected to TWS
        """
        return bool(self.connection and self.connection.isConnected())

    def isModified(self):
        """ Returns True if this object has unsaved messages.

        @return True if this object has unsaved messages
        """
        return len(self.messages) != self.savedLength

    def register(self, obj, name, other=None):
        """ Connects TWS message signal sent from this object to another.

        @param obj slot, method, or function to receive signals
        @param name signal name as string
        @keyparam other=None if not None, slot to receive signals
        @return None
        """
        if other is None:
            self.connect(self, SIGNAL(name), obj)
        else:
            self.connect(self, SIGNAL(name), obj, other)

    def registerAll(self, obj, other=None):
        """ Connects all TWS message signals sent from this object to another.

        @param obj slot, method, or function to receive signals
        @keyparam other=None if not None, slot to receive signals
        @return None
        """
        for name in messageTypeNames():
            self.register(obj, name, other)

    def registerMeta(self, instance, prefix='on_session_'):
        """ Inspects instance for named message slots and connects those found.

        @param instance object with zero or more session message slots
        @keyparam prefix='on_session_' session message method name prefix
        @return None
        """
        for name in [n for n in dir(instance) if n.startswith(prefix)]:
            keys = name[len(prefix):].split('_')
            for key in keys:
                self.register(getattr(instance, name), key)

    def deregister(self, obj, name, other=None):
        """ Disconnects TWS message signal sent from this object.

        @param obj slot, method, or function to receive signals
        @param name signal name as string
        @keyparam other=None if not None, slot to receive signals
        @return None
        """
        if other is None:
            self.disconnect(self, SIGNAL(name), obj)
        else:
            self.disconnect(self, SIGNAL(name), obj, other)

    def deregisterAll(self, obj, other=None):
        """ Disconnects all TWS message signals sent from this object to another.

        @param obj slot, method, or function to receive signals
        @keyparam other=None if not None, slot to receive signals
        @return None
        """
        for name in messageTypeNames():
            self.deregister(obj, name, other)

    def deregisterMeta(self, instance, prefix='on_session_'):
        """ Inspects instance for named message slots and disconnects those found.

        @param instance object with zero or more session message slots
        @keyparam prefix='on_session_' session message method name prefix
        @return None
        """
        for name in [n for n in dir(instance) if n.startswith(prefix)]:
            keys = name[len(prefix):].split('_')
            for key in keys:
                self.deregister(getattr(instance, name), key)

    ##
    # This special clientId is set in the connection display spinbox.
    # We support it by substituting a random id for it when
    # connecting.
    specialClientId = -1

    ##
    # We interpret this privileged port number to mean instead the
    # default TWS port.
    specialPortNo = 1023

    def connectTWS(self, hostName, portNo, clientId, enableLogging=False):
        """ Connect this instance to TWS.

        @param hostName name or IP address of host
        @param portNo port number for connection
        @param clientId connection client id
        @keyparam enableLogging=False enables or disables connection logging
        @return None
        """
        if clientId == self.specialClientId:
            clientId = randint(100, 999)
        if portNo == self.specialPortNo:
            portNo = 7496
        self.connection = con = ibConnection(hostName, portNo, clientId)
        con.enableLogging(enableLogging)
        con.connect()
        con.registerAll(self.receiveMessage)
        self.emit(Signals.tws.connected)

    def disconnectTWS(self):
        """ Disconnects this instance from TWS.

        @return None
        """
        if self.isConnected():
            self.connection.disconnect()
            self.emit(Signals.tws.disconnected)

    def receiveObject(self, object):
        """ Recieve an unknown object, usually during session load/import.

        """
        pass

    def receiveMessage(self, message, mtime=time):
        """ Receive a message from TWS and propagate it as a Qt signal.

        @param message IbPy message instance
        @keyparam mtime=time message timestamp or function to generate timestamp
        @return None
        """
        try:
            mtime = mtime()
        except (TypeError, ):
            pass
        messages = self.messages
        current = (mtime, message)
        messages.append(current)
        self.messagesBare.append(message)
        typeName = message.typeName
        typedMessages = self.messagesTyped.setdefault(typeName, [])
        typedMessages.append(current + (len(messages), ))
        self.emit(SIGNAL(typeName), message)

    def requestTickers(self):
        """ Request market data and depth for each of the strategy contracts.

        @return None
        """
        connection = self.connection
        if connection and connection.isConnected():
            for tickerId, contract in self.strategy.makeContracts():
                self.emit(Signals.contract.created, tickerId, contract)
                connection.reqMktData(tickerId, contract, '', False)
                connection.reqMktDepth(tickerId, contract, 1)

    def requestAccount(self):
        """ Request account data.

        @return None
        """
        connection = self.connection
        if connection and connection.isConnected():
            connection.reqAccountUpdates(True, '')

    def requestOrders(self):
        """ Request orders.

        @return None
        """
        connection = self.connection
        if connection and connection.isConnected():
            connection.reqAllOpenOrders()
            connection.reqOpenOrders()

    def requestHistoricalData(self, params):
        ## we should msg the object instead
        self.models.histdata.begin(params)

    def saveFinished(self):
        """ Slot that updates this instance after a save thread has completed.

        @return None
        """
        if self.saveThread.status:
            count = self.saveThread.writeCount
            self.savedLength = count
            msg = 'Session file saved.  Wrote %s messages.' % count
        else:
            msg = 'Error saving file.'
        self.emit(Signals.session.status, msg)

    def extraObjects(self):
        return []

    def exportFinished(self):
        """ Updates this instance after an export thread has completed.

        @return None
        """
        if self.exportThread.status:
            count = self.exportThread.writeCount
            msg = 'Session exported.  Wrote %s messages.' % count
        else:
            msg = 'Error exporting messages.'
        self.emit(Signals.session.status, msg)

    def saveTerminated(self):
        """ Slot for handling a canceled save thread.

        @return None
        """
        self.emit(Signals.session.status, 'Session file save terminated.')

    def exportTerminated(self):
        """ Slot for handling a canceled export thread.

        @return None
        """
        self.emit(Signals.session.status, 'Session export terminated.')

    def saveInProgress(self):
        """ Returns True if this instance has a running save thread

        @return True if save thread is running, otherwise False
        """
        try:
            return self.saveThread.isRunning()
        except (AttributeError, ):
            return False

    def save(self):
        """ Save the messages in this object to a file.

        @return None
        """
        if self.saveInProgress():
            return
        self.saveThread = thread = \
            SaveThread(filename=self.filename, types=None, parent=self)
        self.connect(thread, Signals.finished, self.saveFinished)
        self.connect(thread, Signals.terminated, self.saveTerminated)
        thread.start()
        self.emit(Signals.session.status, 'Started session file save.')

    def load(self, filename):
        """ Restores session messages from file.

        This function first yields the total number of messages
        loaded, then yields the index of each message after it has
        pumped the message thru the receiveMessage function.  This
        oddness is used to support the QProgressDialog used in the
        main window during session loading.

        @param filename name of file from which to read messages.
        @return None
        """
        try:
            handle = open(filename, 'rb')
        except (IOError, ):
            pass
        else:
            try:
                messages = load(handle)
                yield len(messages)
                for obj in enumerate(messages):
                    try:
                        index, (mtime, message) = obj
                    except (TypeError, ValueError, ):
                        self.receiveObject(obj)
                    else:
                        self.receiveMessage(message, mtime)
                        yield index
            except (UnpicklingError, ):
                pass
            finally:
                self.filename = filename
                self.savedLength = len(messages)
                handle.close()

    def importMessages(self, filename, types):
        """ Import messages directly into this session instance.

        This function is a generator; it first yields the total number
        of messages it has imported, then yields the message's index.
        Prior to yielding the message index, the message object is
        sent thru the Qt signal plumbing.

        @param filename name of serialized messages file
        @param types sequence or set of types to import
        @return None
        """
        try:
            handle = open(filename, 'rb')
        except (IOError, ):
            pass
        else:
            def messageFilter((mtime, message)):
                return message.typeName in types
            try:
                messages = filter(messageFilter, load(handle))
                def importer():
                    yield len(messages)
                    for index, (mtime, message) in enumerate(messages):
                        self.receiveMessage(message, mtime)
                        yield index
                return importer
            except (UnpicklingError, ):
                pass
            finally:
                handle.close()

    def exportInProgress(self):
        """ Returns True if this instance has a running export thread

        @return True if save thread is running, otherwise False
        """
        try:
            return self.exportThread.isRunning()
        except (AttributeError, ):
            return False

    def exportMessages(self, filename, types):
        """ Export some or all session messages.

        @param filename name of file to write
        @param types sequence of types to export; use false value to export all
        @return None
        """
        if self.exportInProgress():
            return
        self.exportThread = thread = \
            SaveThread(filename=filename, types=types, parent=self)
        self.connect(thread, Signals.finished, self.exportFinished)
        self.connect(thread, Signals.terminated, self.exportTerminated)
        thread.start()
        self.emit(Signals.session.status, 'Started session export.')

    def iterMessageTypes(self, *types):
        for key in types:
            try:
                key = key.__name__
            except (AttributeError, ):
                pass
            for msgTimeIndex in self.messagesTyped.get(key, ()):
                yield msgTimeIndex


    def testContract(self, orderId, price=30.0, symbol='MSFT',
                     orderType='MKT', action='SELL'):
        strategy = self.strategy
        contract = strategy.makeContract(symbol)
        order = strategy.makeOrder(action=action,
                                   orderType=orderType,
                                   totalQuantity='100',
                                   openClose='O',
                                   )
        order.m_lmtPrice = contract.m_auxPrice = price
        self.connection.placeOrder(orderId, contract, order)
        return True
