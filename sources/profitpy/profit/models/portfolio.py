#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from PyQt4.QtCore import Qt, QModelIndex, QVariant, QString
from profit.lib import valueAlign
from profit.models import BasicItem, BasicItemModel


class PortfolioModel(BasicItemModel):
    """

    """
    def __init__(self, session=None, parent=None):
        BasicItemModel.__init__(self, RootPortfolioItem(), parent)
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
        amChild = index.parent().isValid()
        if role == Qt.DecorationRole and column==0:
            if not amChild:
                data = QVariant(self.symbolIcon(item.symbol()))
        elif role in (Qt.DisplayRole, Qt.ToolTipRole):
            if amChild and (column==0):
                data = QVariant(item.row())
            else:
                data = QVariant(item[column])
        elif role in (Qt.TextAlignmentRole, ):
            try:
                float(item[column])
                data = QVariant(valueAlign)
            except (ValueError, ):
                pass
        return data

    def findPortfolioItem(self, contract):
        """ Returns the item for the given contract, or None.

        """
        items = self.invisibleRootItem.children
        try:
            return [i for i in items if i.message.contract==contract][0]
        except (IndexError, ):
            pass

    def on_session_UpdatePortfolio(self, message):
        """ Adds a status row if the contract is known to the model.

        """
        contract = message.contract
        item = self.findPortfolioItem(contract)
        if not item:
            root = self.invisibleRootItem
            item = PortfolioItem.fromMessage(message, root)
            root.append(item)
        item.append(UpdatePortfolioItem.fromMessage(message, item))
        item.update(message)
        self.reset()


class PortfolioItem(BasicItem):
    """ Base class for items in the portfolio model.

    """
    columnLookups = [
        ('Symbol', lambda x:x.contract.m_symbol),
        ('Position', lambda x:x.position),
        ('Market Price', lambda x:x.marketPrice),
        ('Market Value', lambda x:x.marketValue),
        ('Average Cost', lambda x:x.averageCost),
        ('Unrealized Profit', lambda x:x.unrealizedPNL),
        ('Realized Profit', lambda x:x.realizedPNL),
        ('Account', lambda x:x.accountName),
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


class RootPortfolioItem(PortfolioItem):
    """ Portfolio model item with automatic values (for horizontal headers).

    """
    def __init__(self):
        PortfolioItem.__init__(self, self.horizontalLabels())

    def horizontalLabels(self):
        """ Generates list of horizontal header values.

        """
        return map(QVariant, [label for label, lookup in self.columnLookups])


class UpdatePortfolioItem(PortfolioItem):
    """ Specialized status item; empty for now.

    """
