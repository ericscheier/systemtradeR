#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

## TODO:  more clean up, filter model, save/restore selected cols

from functools import partial
from itertools import ifilter
from string import Template

from PyQt4.QtCore import QVariant, Qt, pyqtSignature
from PyQt4.QtGui import QAction, QFrame, QIcon, QMenu

from ib.opt.message import TickPrice

from profit.lib import BasicHandler, Signals, defaults, instance
from profit.lib.gui import (
    UrlRequestor, ValueColorItem, separator, makeUrlAction, symbolIcon, )
from profit.workbench.widgets.ui_tickerdisplay import Ui_TickerDisplay


class TickerDisplay(QFrame, Ui_TickerDisplay, BasicHandler, UrlRequestor):
    """ TickerDisplay -> shows ticker data in a nice table.

    """
    def __init__(self, parent=None):
        """ Initializer.

        @param parent ancestor of this object
        @return None
        """
        QFrame.__init__(self, parent)
        self.setupUi(self)
        self.setupWidgets()
        self.requestSession()

    def setupWidgets(self):
        """ Make our widgets like we like.

        """
        settings = self.settings
        settings.beginGroup(self.__class__.__name__)
        defaultFields = defaults.tickerDisplayFields()
        userFields = settings.valueLoad('selectedFields', defaultFields)
        #self.tickFieldSelect.setCheckedFields(userFields)
        #self.infoBar.barHelp.setText('Right click column headers to select some.')
        settings.endGroup()
        self.reflectSignals(Signals.openUrl, Signals.tickerClicked)

    def on_tickersView_doubleClick(self, index):
        item = index.internalPointer()
        self.emit(Signals.tickerClicked, item)

    def setSession(self, session):
        """ Configures this instance for a session.

        @param session Session instance
        @return None
        """
        self.session = session
        connect = self.connect
        model = session.models.tickers
        model.symbolIcon = symbolIcon
        model.valueBrushMap = ValueColorItem.compMap
        view = self.tickersView
        view.setModel(model)
        connect(view, Signals.modelDoubleClicked,
                self.on_tickersView_doubleClick)
        header = view.header()
        header.setContextMenuPolicy(Qt.ActionsContextMenu)
        def makeActions():
            for col, title in enumerate(model.columnLabels()):
                action = QAction(title, header)
                action.setCheckable(True)
                action.setChecked(Qt.Checked)
                handler = partial(self.setTickersColumnEnabled, column=col)
                connect(action, Signals.toggled, handler)
                header.setResizeMode(col, header.Stretch)
                yield action
        header.addActions(list(makeActions()))
        session.registerMeta(self)

    def setTickersColumnEnabled(self, enable, column):
        """

        """
        view = self.tickersView
        call = (view.showColumn if enable else view.hideColumn)
        call(column)

    def basicActions(self, index):
        """ Creates action and separator list suitable for a context menu.

        @param index QModelIndex instance
        @return list of suitable QActions
        """
        data = index.data()
        symbol = data.toString()
        icon = QIcon(index.data(Qt.DecorationRole))
        actions = [
            QAction(icon, symbol, None),
            separator(),
            self.actionChart,
            self.actionOrder,
            separator(),
        ]
        for act in actions:
            act.setData(data)
        return actions

    @pyqtSignature('')
    def closePosition(self):
        """ Emits a signal for a position to be closed.

        """
        print '## close position order dialog'

    def closePositionAction(self, row):
        """ Creates an action for closing a position.

        @param row ticker table row number
        @return close action connected to close method, or None
        """
        return
        act = None
        index = self.tickerTable.model().index(row, 1)
        if index and index.isValid():
            try:
                pos = float(index.data().toString())
            except (ValueError, ):
                pos = 0
            if pos:
                act = QAction('Close %s shares...' % abs(pos), None)
                self.connect(act, Signals.triggered, self.closePosition)
        return act

    @pyqtSignature('')
    def on_actionChart_triggered(self):
        """ Emits a signal for a ticker chart.

        """
        table = self.tickerTable
        try:
            item = table.selectedItems()[0]
        except (IndexError, ):
            pass
        else:
            index = table.model().index(item.row(), 0)
            if index and index.isValid():
                self.emit(Signals.tickerClicked, table.itemFromIndex(index))

    @pyqtSignature('')
    def on_actionOrder_triggered(self):
        """ Emits a signal for an order dialog.

        """
        print '## order for ', self.actionOrder.data().toString()

    def fixme__on_tickerTable_customContextMenuRequested(self, pos):
        """ Display a context menu over the ticker table.

        """
        table = self.tickerTable
        item = table.itemAt(pos)
        if item:
            row = item.row()
            index = table.model().index(row, 0)
            if index and index.isValid():
                actions = self.basicActions(index)
                close = self.closePositionAction(row)
                if close:
                    actions.insert(-1, close)
                actions.extend(self.urlActions(index.data().toString()))
                QMenu.exec_(actions, table.viewport().mapToGlobal(pos))

    def fixme__on_tickerTable_doubleClicked(self, index):
        """ Emits an item from the ticker table as a signal argument.

        """
        if not index.isValid():
            return
        row, col = index.row(), index.column()
        item = self.tickerTable.item(row, 0)
        sym = str(index.data().toString())
        symbols = self.session.strategy.symbols()
        try:
            tid = symbols[sym]
        except (KeyError, ):
            pass
        else:
            item.setData(DataRoles.tickerId, QVariant(tid), )
            item.setData(DataRoles.tickerSymbol, QVariant(sym))
            if (0 <= col <= 2):
                self.emit(Signals.tickerClicked, item)
            elif  (2 < col < 9):
                self.emit(Signals.tickerClicked, item, col)

    def saveFieldSelections(self):
        """ Saves the selected fields.

        """
        settings = self.settings
        settings.beginGroup(self.__class__.__name__)
        userItems = self.tickFieldSelect.checkedItems()
        #saveFields = [itemTickField(i) for i in userItems]
        saveFields = []
        settings.setValueDump('selectedFields', saveFields)
        settings.endGroup()

    def urlActions(self, symbol):
        """ Returns a list of actions for the given symbol.

        """
        actions = []
        settings = self.settings
        settings.beginGroup(self.settings.keys.urls)
        urls = settings.value(settings.keys.tickerurls, defaults.tickerUrls())
        settings.endGroup()
        urls = [str(s) for s in defaults.tickerUrls()]
        for url in urls:
            try:
                name, url = str(url).split(':', 1)
                url = Template(url).substitute(symbol=symbol)
            except (KeyError, ValueError, ):
                continue
            act = makeUrlAction(name, url, toolTip='%s %s' % (symbol, name))
            request = partial(self.requestUrl, action=act)
            self.connect(act, Signals.triggered, request)
            actions.append(act)
        return actions
