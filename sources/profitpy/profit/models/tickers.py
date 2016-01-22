#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from re import split as rxsplit
from PyQt4.QtCore import Qt, QModelIndex, QObject, QVariant, QString
from ib.ext.TickType import TickType
from ib.opt.message import TickPrice
from profit.lib import valueAlign
from profit.models import BasicItem, BasicItemModel


class TickersModel(BasicItemModel):
    """ Model for a collection of tickers.

    """
    def __init__(self, session=None, parent=None):
        """ Initializer.

        @param session=None session instance
        @param parent ancestor of this widget
        """
        BasicItemModel.__init__(self, TickersRootItem(), parent)
        self.symbolIcon = lambda x:''
        self.valueBrushMap = {}
        self.tickerIdItemMap = {}
        self.session = session
        if session is not None:
            session.registerMeta(self)

    def columnLabels(self):
        """ Convienence function for clients.  Unused internally.

        """
        return [s['title']for s in self.invisibleRootItem.columnLookups]

    def data(self, index, role=Qt.DecorationRole):
        """ Framework hook to retrieve information from this model.

        @param index QModelIndex instance
        @param role=Qt.DecorationRole
        @return QVariant of some kind
        """
        if not index.isValid():
            return QVariant()
        item = index.internalPointer()
        column = index.column()
        data = QVariant()
        tickerId = item[0]
        if role ==  Qt.DisplayRole:
            if column == 1:
                data = QVariant(self.symbolName(tickerId))
            else:
                data = QVariant(item.data[column])
        elif role == Qt.DecorationRole and column == 1:
            data = QVariant(self.symbolIcon(self.symbolName(tickerId)))
        elif role == Qt.ForegroundRole:
            if column not in (0, 1):
                brush = self.valueBrushMap.get(item.lastCmp(column), None)
                data = QVariant(brush)
        elif role == Qt.TextAlignmentRole:
            try:
                float(item[column])
                data = QVariant(valueAlign)
            except (ValueError, TypeError, ):
                pass
        return data

    def findTicker(self, tickerId):
        """ Locates the TickerItem for the given id or None.

        """
        return self.tickerIdItemMap.get(tickerId, None)

    def on_session_createdContract(self, tickerId, contract):
        """ Called when the session creates a contract object.

        @param tickerId id associated with data request
        @param contract ib.opt.Contract
        """
        item = self.findTicker(tickerId)
        if not item:
            root = self.invisibleRootItem
            item = TickersItem.fromContract(tickerId, contract, root)
            self.tickerIdItemMap[tickerId] = item
            root.append(item)
            self.reset()

    def on_session_TickPrice_TickSize(self, message):
        """ Called with new ticker size or price.

        @param message ib package message instance
        """
        tickerId = message.tickerId
        item = self.findTicker(tickerId)
        if item:
            item.update(message)
        else:
            root = self.invisibleRootItem
            item = TickersItem.fromMessage(message, root)
            self.tickerIdItemMap[tickerId] = item
            root.append(item)
        ## yuk; should emit a signal
        self.reset()

    def symbolName(self, tickerId):
        """ Returns the symbol name given a ticker id.

        This should reference self.session.models.contracts instead.
        """
        symbols = self.session.strategy.symbols()
        try:
            return dict([(b, a) for a, b in symbols.items()])[tickerId] or ''
        except (KeyError, ):
            return ''


class ExtraFields(object):
    """ Namespace for our 'extra' fields, i.e., fields not in TickType.

    The extra fields are all negative so as to not conflict with those
    in TickType.
    """
    tid, sym, pos, val = enum = range(-4, 0)
    labels = ['id', 'symbol', 'position', 'value']
    all = zip(enum, labels)


def extraFieldSpecs():
    """ Generates sequence of dictionaries that describe our extra fields.

    """
    for field, label in ExtraFields.all:
        yield dict(value=field, title=label.title())


def fieldSpecs(maxValue=10):
    """ Yields one description dictionary for every TickType field.

    """
    values = [getattr(TickType, k) for k in dir(TickType)]
    for value in [v for v in values if isinstance(v, int) and v < maxValue]:
        title = tickFieldTitle(TickType.getField(value))
        yield dict(value=value, title=title)


def tickFieldTitle(name):
    """ Make title from name, aka UnCapCase.

    """
    words = rxsplit('([A-Z0-9][a-z]+)', name)
    ## my rx fu isn't great enough.  special case for when the split
    ## does not work, e.g., bidEFP.
    if len(words) == 1:
        words = rxsplit('([a-z]+)', name)
    ## title case each word in the word list if the word isn't already
    ## all upper case.
    words = [(w if w.upper()==w else w.title()) for w in words if w]
    return str.join(' ', words)


class TickersItem(BasicItem):
    """ Items for the tickers model.

    """
    columnLookups = list(extraFieldSpecs()) + list(fieldSpecs())
    valueLookups = {
        ExtraFields.tid : lambda m:m.tickerId,
        ## TODO: tie value lookups to the portfolio model
        ExtraFields.sym : lambda m:None,
        ExtraFields.pos : lambda m:None,
        ExtraFields.val : lambda m:None,
    }

    def __init__(self, data, parent=None, message=None):
        """ Initializer.

        @param data mutable sequence with some values
        @param parent=None parent item
        @param message=None ib package message instance
        """
        BasicItem.__init__(self, data, parent)
        self.message = message
        self.previousValues = {}

    @classmethod
    def fromContract(cls, tickerId, contract, parent):
        """ New instance from a contract (probably created elsewhere)

        @param cls class object
        @param tickerId id associated with data request
        @param contract ib.opt.Contract
        @param parent parent of this item
        @return new instance of cls
        """
        message = TickPrice(tickerId=tickerId, field=0, price=0)
        values = [tickerId, contract.m_symbol] + \
                 ['' for spec in cls.columnLookups][2:]
        return cls(values, parent, message)

    @classmethod
    def fromMessage(cls, message, parent):
        """ New instance from message values

        @param cls class object
        @param message ib.opt.message object
        @param parent parent of this item
        @return new instance of cls
        """
        values = []
        valueLookups = cls.valueLookups
        field = message.field
        def default(m):
            if m.field==field:
                return (m.price if hasattr(m, 'price') else m.size)
        for spec in cls.columnLookups:
            lookup = valueLookups.get(spec['value'], default)
            values.append(lookup(message))
        return cls(values, parent, message)

    def lastCmp(self, col):
        """ Compare current value at column with its previous.

        """
        return cmp(self[col], self.previousValues.get(col, self[col]))

    def update(self, message):
        """ Update the item with values from a message.

        @param message ib.opt.message object
        @return None
        """
        field = message.field
        value = message.price if hasattr(message, 'price') else message.size
        for column, spec in enumerate(self.columnLookups):
            if spec['value'] == field:
                self.previousValues[column] = self[column]
                self[column] = value
                break


class TickersRootItem(TickersItem):
    """ Tickers model item with automatic values (for horizontal headers).

    """
    def __init__(self):
        TickersItem.__init__(self, self.horizontalLabels())

    def horizontalLabels(self):
        """ Generates list of horizontal header values.

        """
        return map(QVariant, [spec['title'] for spec in self.columnLookups])
