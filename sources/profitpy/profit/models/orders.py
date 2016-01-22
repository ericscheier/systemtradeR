#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from PyQt4.QtCore import Qt, QModelIndex, QVariant, QString
from profit.lib import valueAlign
from profit.models import BasicItem, BasicItemModel


class OrdersModel(BasicItemModel):
    """

    """
    def __init__(self, session=None, parent=None):
        BasicItemModel.__init__(self, RootOrderItem(), parent)
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
        if role == Qt.DecorationRole and column == 1:
            data = QVariant(self.symbolIcon(item.symbol()))
        elif role in (Qt.DisplayRole, Qt.ToolTipRole):
            data = QVariant(item[column])
        elif role in (Qt.TextAlignmentRole, ):
            try:
                float(item[column])
                data = QVariant(valueAlign)
            except (ValueError, TypeError, ):
                pass
        return data

    def findOrderItem(self, orderId):
        """ Returns the item for the given order id, or None.

        """
        orderItems = self.invisibleRootItem.children
        try:
            return [item for item in orderItems if item[0]==orderId][0]
        except (IndexError, ):
            pass

    def on_session_OrderStatus(self, message):
        """ Adds a status row if the order is known to the model.

        """
        orderId = message.orderId
        item = self.findOrderItem(orderId)
        if item:
            item.append(StatusOrderItem.fromMessage(message, item))
            item.update(message)
            self.reset()

    def on_session_OpenOrder(self, message):
        """ Adds a new order row if the order isn't known to the model.

        """
        orderId = message.orderId
        if not self.findOrderItem(orderId):
            root = self.invisibleRootItem
            root.append(OrderItem.fromMessage(message, root))
            self.reset()


class OrderItem(BasicItem):
    """ Base class for items in the order model.

    """
    columnLookups = [
        ('Order Id', lambda msg:msg.contract and msg.orderId),
        ('Symbol', lambda msg:msg.contract.m_symbol),
        ('Status', lambda msg:msg.status),
        ('Filled', lambda msg: msg.filled),
        ('Action', lambda msg:msg.order.m_action),
        ('Type', lambda msg:msg.order.m_orderType),
        ('Limit Price', lambda msg:msg.order.m_lmtPrice),
        ('Open/Close', lambda msg:('Open' if msg.order.m_openClose=='O' else 'Close')),
        ('Security Type', lambda msg:msg.contract.m_secType),
        ('Expiry', lambda msg:msg.contract.m_expiry),
        ('Strike', lambda msg:msg.contract.m_strike),
        ('Right', lambda msg:(msg.contract.m_right if msg.contract.m_right !='?' else '')),
        ('Remaining', lambda msg:msg.remaining),
        ('Total Quantity', lambda msg:msg.order.m_totalQuantity),
        ('Aux Price', lambda msg:msg.order.m_auxPrice),
        ('Average Fill Price', lambda msg:msg.avgFillPrice),
        ('Last Fill Price', lambda msg:msg.lastFillPrice),
        ('Perm Id', lambda msg:msg.permId),
        ('Parent Id', lambda msg:msg.parentId),
        ('Client Id', lambda msg:msg.clientId),
        ('Why Held', lambda msg:msg.whyHeld),
        ('Order State', lambda msg:msg.orderState),
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


class RootOrderItem(OrderItem):
    """ Order model item with automatic values (for horizontal headers).

    """
    def __init__(self):
        OrderItem.__init__(self, self.horizontalLabels())

    def horizontalLabels(self):
        """ Generates list of horizontal header values.

        """
        return map(QVariant, [label for label, lookup in self.columnLookups])


class StatusOrderItem(OrderItem):
    """ Specialized status item; empty for now.

    """
