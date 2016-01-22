#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from PyQt4.QtCore import QAbstractTableModel, QSize, QVariant, Qt
from PyQt4.QtGui import QFrame, QStandardItemModel, QStandardItem

from profit.lib import BasicHandler, Signals, valueAlign
from profit.lib.gui import colorIcon, complementColor
from profit.lib.widgets.plot import PlotCurve, ControlTreeValueItem
from profit.workbench.widgets.ui_accountdisplay import Ui_AccountDisplay


class AccountTableModel(QStandardItemModel):
    """ AccountTableModel -> item model of latest account data.

    """
    columnTitles = ['Item', 'Currency', 'Value', 'Account', ]

    def __init__(self, session, parent=None):
        """ Initializer.

        @param session Session instance
        @param parent ancestor object
        """
        QStandardItemModel.__init__(self, parent)
        self.setHorizontalHeaderLabels(self.columnTitles)
        self.items = {}
        self.session = session
        fillSlot = self.on_session_UpdateAccountValue
        for mrec in session.iterMessageTypes('UpdateAccountValue'):
            fillSlot(mrec[1])
        session.registerMeta(self)

    def on_session_UpdateAccountValue(self, message):
        """ Changes model items to match latest account data.

        @param message message instance
        @return None
        """
        key = (message.key, message.currency, message.accountName)
        try:
            items = self.items[key]
        except (KeyError, ):
            pass
        else:
            items[2].setText(message.value)


class AccountDisplay(QFrame, Ui_AccountDisplay, BasicHandler):
    """ AccountDisplay -> displays account data and associated plot controls.

    """
    def __init__(self, parent=None):
        """ Initializer.

        @param parent ancestor object
        """
        QFrame.__init__(self, parent)
        self.setupUi(self)
        self.requestSession()
        self.resizePlotControls()

    def setSession(self, session):
        """ Configures this instance for a session.

        @param session Session instance
        @return None
        """
        self.session = session
        self.dataModel = model = AccountTableModel(session, self)
        plot = self.plot
        plot.plotButton.setVisible(False)
        plot.setSessionPlot(session, session.maps.account, 'account')
        plot.controlsTreeModel = model
        plot.controlsTree.setModel(model)
        plot.controlsTree.header().show()
        for key, series in session.maps.account.items():
            value = session.maps.account.last.get(key, None)
            self.newPlotSeries(key, series, value)
        connect = self.connect
        connect(session, Signals.createdAccountData, self.newPlotSeries)
        connect(model, Signals.standardItemChanged, plot.on_controlsTree_itemChanged)
        connect(model, Signals.rowsInserted, self.updateModelItems)
        plot.loadSelections()
        self.resizePlotControls()

    def newPlotSeries(self, key, series, value):
        """ Called when the session creates a new series for account data.

        @param key triple of account data key, currency, and account name
        @param series newly created data series
        @param value value for account data key; may be float or string
        @return None
        """
        cols = range(len(self.dataModel.columnTitles))
        items = [ControlTreeValueItem('') for i in cols[1:]]
        items[0].setText(key[1])
        items[1].setText(str(value))
        items[2].setText(key[2])
        try:
            value = float(value)
            checkable = True
        except (TypeError, ValueError, ):
            checkable = False
        self.plot.addSeries(key, series, items=items, checkable=checkable)

    def resizePlotControls(self):
        """ Adjusts column sizes and sort order.

        @return None
        """
        for i in range(3): ## why 3 and not 4?
            self.plot.controlsTree.resizeColumnToContents(i)
        self.plot.controlsTree.sortByColumn(0, Qt.AscendingOrder)

    def updateModelItems(self, parent, start, end):
        """ Called when rows are inserted into the item model.

        @param parent QModelIndex instance
        @param start first row number
        @param end last row number
        @return None
        """
        model = self.dataModel
        item = model.itemFromIndex(parent)
        if item:
            others = [model.item(item.row(), i) for i in range(1,4)]
            key = tuple(str(i.text()) for i in (item, others[0], others[2]))
            model.items[key] = [item, ] + others
        self.resizePlotControls()
