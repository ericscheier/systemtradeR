#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from PyQt4.QtCore import Qt, QModelIndex, QVariant, QString
from ib.opt.message import HistoricalData as HistDataMessage
from profit.lib import Signals, logging, valueAlign
from profit.models import BasicItem, BasicItemModel

## TODO: add the incoming requests to the parent session's extra
## object list.

## Note: these classes have intentionally simple names.  Clients
## should use the alias HistDataRequestModel instead of RequestModel.

## This is what the hist data request looks like, as returned from
## the request dialog:
#
#    params = {'endDateTime': '20080707 08:00:00',
#              'durationStr': '2 D',
#              'whatToShow': 'TRADES',
#              'contract': <ib.ext.Contract.Contract object at 0x8dd8f0c>,
#              'barSizeSetting': '1 min',
#              'formatDate': 1,
#              'tickerId': 1146,
#              'useRTH': 1}


class RequestModel(BasicItemModel):
    """ RequestModel -> models historical data requests

    This class receives, queues, and submits historical data requests.
    As new requests are received (or when un-requested historical data
    messages are received), instances create child models of type SubModel.
    """
    def __init__(self, session=None, parent=None):
        """ Initializer.

        @param session=None session reference or None
        @param parent=None ancestor of this object or None
        """
        BasicItemModel.__init__(self, RootRequestItem(), parent)
        self.session = session
        if session is not None:
            session.registerMeta(self)
        self.busy = False
        self.startTimer(1500)

    def data(self, index, role):
        """ Framework hook to retreive data stored at index for given role.

        @param index QModelIndex instance
        @param role Qt.DisplayRole flags
        @return QVariant instance
        """
        if not index.isValid():
            return QVariant()
        item = index.internalPointer()
        data = QVariant()
        column = index.column()
        if role == Qt.DecorationRole and column==item.symbolColumnolumn:
            data = QVariant(self.symbolIcon(item.symbol()))
        elif role in (Qt.DisplayRole, Qt.ToolTipRole):
            data = QVariant(item[column])
        return data

    def findItem(self, requestId):
        """ Returns the item for the given hist data message, or None.

        @param requestId historical data request id
        @return item or None
        """
        for item in iter(self.invisibleRootItem.children):
            if item.requestId==requestId:
                return item

    def iterrows(self, *requestIds):
        children = self.invisibleRootItem.children
        for sub in [c for c in children if c.requestId in requestIds]:
            for item in sub.model.invisibleRootItem.children:
                yield item.data

    def on_session_Error(self, message):
        """ Matches error messages to the requests in this model.

        @param message ib.opt.message instance
        """
        item = self.findItem(message.id)
        if item:
            item[item.statusColumn] = 'Error: %s' % message.errorMsg
            index = QModelIndex()
            col = item.statusColumn
            row = item.row()
            index = self.index(row, col, QModelIndex())
            self.emit(Signals.dataChanged, index, index)

    def on_session_HistoricalData(self, message):
        """ Called when the session receives a HistoricalData message.

        @param message ib.opt.message instance
        @return None
        """
        requestId = message.reqId
        item = self.findItem(requestId)
        if item:
            row, col = item.row(), item.statusColumn
            if message.date.startswith('finished-'):
                item[col] = 'Finished'
            else:
                item[col] = 'Receiving'
            index = self.index(row, col, QModelIndex())
            self.emit(Signals.dataChanged, index, index)
        else:
            root = self.invisibleRootItem
            row = root.childCount()
            self.beginInsertRows(QModelIndex(), row, row)
            root.append(RequestItem.fromMessage(message, self.session, root))
            self.endInsertRows()

    def on_session_historicalDataRequest(self, params):
        """ Called when a request for historical data is made.

        @param params historical data request parameters
        @return None
        """
        requestId = params['tickerId']
        root = self.invisibleRootItem
        requests = [r.requestId for r in root.children]
        if requestId in requests:
            logging.warn('Ignoring duplicate hist data request %s', requestId)
            return
        row = root.childCount()
        self.beginInsertRows(QModelIndex(), row, row)
        root.append(RequestItem.fromRequest(params, self.session, root))
        self.endInsertRows()

    def subModel(self, requestId):
        """ Returns the submodel for the given request id or None

        @param requestId historical data request id
        @return submodel associated with request id or None
        """
        item = self.findItem(requestId)
        return item.model if item else None

    def next(self):
        for item in iter(self.invisibleRootItem.children):
            if item.queued:
                return item

    def timerEvent(self, event):
        if not self.session.isConnected():
            return
        next = self.next()
        if next:
            self.session.connection.reqHistoricalData(**next.request)
            next[next.statusColumn] = 'Requested'
            next.queued = False
            index = self.index(next.row(), next.statusColumn, QModelIndex())
            self.emit(Signals.dataChanged, index, index)


class RequestItem(BasicItem):
    """ RequestItem -> items for the hist data request model.

    """
    columnLabels = [
        'Request Id', 'Status', 'Symbol', 'Sec Type', 'Expiry', 'Right'
    ]
    columnLookups = (
        (requestColumn, requestLabel),
        (statusColumn, statusLabel),
        (symbolColumnolumn, symbolLabel),
        (securityColumn, securityLabel),
        (expireColumn, expireLabel),
        (rightColumn, rightLabel)
    ) = list(enumerate(columnLabels))

    def __init__(self, values, requestId=None, request={}, model=None,
                 parent=None):
        """ Initializer.

        @param values sequence of values for this item
        @param requestId=None historical data request id as int
        @param request={} request parameters as dictionary
        @param model=None data model with messages for this request
        @param parent=None parent of this item
        """
        BasicItem.__init__(self, values, parent)
        self.requestId = requestId
        self.request = request
        self.model = model
        self.queued = False

    @classmethod
    def fromMessage(cls, message, session, parent):
        """ New instance from a historical data message.

        @param cls class object
        @param message ib.opt.message object
        @param session session instance
        @param parent parent of this item
        @return new instance of cls
        """
        requestId = message.reqId
        request = {}
        values = [None for i in cls.columnLookups]
        values[0] = requestId
        values[1] = 'Loading'
        ## without a request the other values can't be filled.
        ## TODO:  try to find a matching request in the session
        submodel = SubModel(requestId, request, session)
        item = cls(values, requestId, request, submodel, parent)
        return item

    @classmethod
    def fromRequest(cls, request, session, parent):
        """ New instance from a historical data request.

        @param cls class object
        @param request dictionary of request parameters
        @param session session instance
        @param parent parent of this item
        @return new instance of cls
        """
        requestId = request['tickerId']
        contract = request['contract']
        values = [None for i in cls.columnLookups]
        values[0] = requestId
        values[1] = 'Queued'
        values[2] = contract.m_symbol
        values[3] = contract.m_secType
        ## the other values aren't set in the contract -- dialog is incomplete
        ## TODO:  complete the dialog
        submodel = SubModel(requestId, request, session)
        item = cls(values, requestId, request, submodel, parent)
        item.queued = True
        return item

    def symbol(self):
        """ Returns the symbol for this item or ''

        """
        contract = self.request.get('contract')
        return contract.m_symbol if contract else ''


class RootRequestItem(RequestItem):
    """ RootRequestItem -> an item class for the root of the request view.

    """
    def __init__(self):
        """ Initializer.

        """
        RequestItem.__init__(self, map(QVariant, self.columnLabels))


class SubModel(BasicItemModel):
    """ SubModel -> model of hist data requests and responses

    """
    def __init__(self, requestId, request, session=None, parent=None):
        """ Initializer.

        @param session=None session reference or None
        @param parent=None ancestor of this object or None
        """
        BasicItemModel.__init__(self, RootSubItem(), parent)
        self.requestId = requestId
        self.request = request
        self.session = session
        if session is not None:
            session.registerMeta(self)

    def data(self, index, role):
        """ Framework hook to retreive data stored at index for given role.

        @param index QModelIndex instance
        @param role Qt.DisplayRole flags
        @return QVariant instance
        """
        if not index.isValid():
            return QVariant()
        item = index.internalPointer()
        data = QVariant()
        column = index.column()
        if role in (Qt.DisplayRole, Qt.ToolTipRole):
            data = QVariant(item[column])
        elif role in (Qt.TextAlignmentRole, ):
            try:
                float(item[column])
                data = QVariant(valueAlign)
            except (TypeError, ValueError, ):
                pass
        return data

    def on_session_HistoricalData(self, message):
        """ Called when the session receives a HistoricalData message.

        @param message ib.opt.message instance
        """
        requestId = message.reqId
        if requestId != self.requestId:
            return
        request = self.request
        root = self.invisibleRootItem
        if message.date.startswith('finished'):
            self.emit(Signals.histdata.finish, requestId)
        row = root.childCount()
        self.beginInsertRows(QModelIndex(), row, row)
        root.append(SubItem.fromMessage(requestId, request, message, root))
        self.endInsertRows()


class SubItem(BasicItem):
    """ Base class for items in the portfolio model.

    """
    columnLookups = [
        ('Request Id', lambda x:x.reqId),
        ('Date', lambda x:x.date),
        ('Open', lambda x:x.open),
        ('High', lambda x:x.high),
        ('Low', lambda x:x.low),
        ('Close', lambda x:x.close),
        ('Volume', lambda x:x.volume),
        ('Count', lambda x:x.count),
        ('Weighted Average Price', lambda x:x.WAP),
        ('Has Gaps', lambda x:x.hasGaps),
    ]

    def __init__(self, values, requestId, request, message, parent=None):
        """ Initializer.

        @param values sequence of data for this item
        @param requestId historical data request id as int
        @param request request parameters as dictionary
        @param message ib.opt.message object
        @param parent=None parent of this item
        """
        BasicItem.__init__(self, values, parent)
        self.requestId = requestId
        self.request = request
        self.message = message

    @classmethod
    def fromMessage(cls, requestId, request, message, parent):
        """ New instance from message values

        @param cls class object
        @param requestId client identifier for request as int
        @param message ib.opt.message object
        @param parent parent of this item
        @return new instance of cls
        """
        values = []
        for label, lookup in cls.columnLookups:
            try:
                value = lookup(message)
            except (AttributeError, ):
                value = None
            values.append(value)
        item = cls(values, requestId, request, message, parent)
        if message.date.startswith('finished-'):
            item[1] = item[1][len('finished-'):]
        return item


class RootSubItem(SubItem):
    """ HistData model item with automatic values (for horizontal headers).

    """
    def __init__(self):
        """ Initializer.

        """
        labels = map(QVariant, [i[0] for i in self.columnLookups])
        SubItem.__init__(self, labels, None, None, None)


## clients should use this alias
#
HistDataRequestModel = RequestModel
