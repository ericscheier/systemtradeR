#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from time import strftime, strptime

from PyQt4.QtCore import Qt, QModelIndex, QVariant, QString
from profit.lib import valueAlign
from profit.models import BasicItem, BasicItemModel


class ExecutionsModel(BasicItemModel):
    """

    """
    def __init__(self, session=None, parent=None):
        BasicItemModel.__init__(self, RootExecutionsItem(), parent)
        self.session = session
        if session is not None:
            session.registerMeta(self)

    def data(self, index, role):
        """

        """
        if not index.isValid():
            return QVariant()
        item = index.internalPointer()
        data = QVariant()
        column = index.column()
        if role == Qt.DecorationRole and column==2:
            sym = item.symbol()
            ico = self.symbolIcon(sym)
            data = QVariant(ico)
        elif role in (Qt.DisplayRole, Qt.ToolTipRole):
            data = QVariant(item[column])
        elif role in (Qt.TextAlignmentRole, ):
            try:
                float(item[column])
                data = QVariant(valueAlign)
            except (ValueError, ):
                pass
        return data

    def findItem(self, orderId):
        """ Returns the item for the given contract, or None.

        """
        items = self.invisibleRootItem.children
        try:
            return [i for i in items if i.message.execution.m_orderId==orderId][0]
        except (IndexError, ):
            pass

    def on_session_ExecDetails(self, message):
        """ Adds a status row if the contract is known to the model.

        """
        item = self.findItem(message.execution.m_orderId)
        if not item:
            root = self.invisibleRootItem
            item = ExecutionsItem.fromMessage(message, root)
            root.append(item)
        item.append(ExecutionsItem.fromMessage(message, item))
        item.update(message)
        self.reset()


dayFormatOut = '%a %d %b %Y'
dayFormatIn = '%Y%m%d'


def messageDate(message):
    """ Extracts and formats the date from an execution details message.

    @param message message instance
    @return formatted date as string
    """
    datetime = message.execution.m_time
    datepart = datetime.split()[0]
    return strftime(dayFormatOut, strptime(datepart, dayFormatIn))


def messageTime(message):
    """ Extracts the time from an execution details message.

    @param message message instance
    @return time as string
    """
    datetime = message.execution.m_time
    timepart = datetime.split()[1]
    return timepart


class ExecutionsItem(BasicItem):
    """ Base class for items in the executions model.

    """
    columnLookups = [
        ('Action', lambda m:m.execution.m_side),
        ('Quantity', lambda m:m.execution.m_shares),
        ('Underlying', lambda m:m.contract.m_symbol),
        ('Price', lambda m:m.execution.m_price),
        ('Currency', lambda m:m.contract.m_currency),
        ('Exchange', lambda m:m.execution.m_exchange),
        ('Date', messageDate),
        ('Time', messageTime),
        ('Id', lambda m:m.execution.m_permId),
        ('Order Reference', lambda m:m.execution.m_orderId),
    ]

    def __init__(self, data, parent=None, message=None):
        BasicItem.__init__(self, data, parent)
        self.message = message

    @classmethod
    def fromMessage(cls, message, parent):
        """ New instance from message values

        @param cls class object
        @param message ib.opt.message object
        @param parent parent of this item
        @return new instance of cls
        """
        values = []
        for label, lookup in cls.columnLookups:
            try:
                value = lookup(message)
            except (AttributeError, ):
                value = ''
            values.append(value)
        return cls(values, parent, message)

    def symbol(self):
        """ Returns the symbol for this item or ''

        """
        try:
            return self.message.contract.m_symbol
        except (AttributeError, ):
            return ''

    def update(self, message):
        """ Update the item with values from a message.

        @param message ib.opt.message object
        @return None
        """
        for column, (label, lookup) in enumerate(self.columnLookups):
            try:
                self[column] = lookup(message)
            except (AttributeError, ):
                pass


class RootExecutionsItem(ExecutionsItem):
    """ Executions model item with automatic values (for horizontal headers).

    """
    def __init__(self):
        ExecutionsItem.__init__(self, self.horizontalLabels())

    def horizontalLabels(self):
        """ Generates list of horizontal header values.

        """
        return map(QVariant, [label for label, lookup in self.columnLookups])
