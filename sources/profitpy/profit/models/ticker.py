#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from PyQt4.QtCore import Qt, QModelIndex, QVariant, QString
from profit.lib import valueAlign
from profit.models import BasicItem, BasicItemModel

## This model isn't used yet.  It should morph into a replacement
## for the plot controls model in profit.lib.widgets.plot.

class TickerModel(BasicItemModel):
    """ Model for a single ticker.

    """
    def __init__(self, session=None, parent=None):
        BasicItemModel.__init__(self, TickerRootItem(), parent)
        self.session = session
        self.data = {}
        if session is not None:
            session.registerMeta(self)

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
        return data

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


class TickerItem(BasicItem):
    pass


class TickerRootItem(TickerItem):
    pass
