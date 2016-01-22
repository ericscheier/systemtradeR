#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

from functools import partial
from sys import platform

from PyQt4.QtCore import Qt
from PyQt4.QtGui import QIcon, QStandardItem

from profit.lib import importItem, logging
from profit.lib import BasicHandler, Signals, DataRoles, instance
from profit.lib.gui import makeUrlItem, symbolIcon
from profit.lib.widgets.localtabwidget import LocalTabWidget


class CentralTabs(LocalTabWidget, BasicHandler):
    """ CentralTabs -> tab widget with extra special powers

    """
    def __init__(self, parent=None):
        """ Initializer.

        @param parent ancestor of this widget
        """
        LocalTabWidget.__init__(self, parent)
        self.createHandlers = [
            self.createBrowserTab,
            self.createTickerPlotTab,
            self.createTickerPlotFromView,
            self.createDisplayTab
        ]
        app, connect, createTab = instance(), self.connect, self.createTab
        connect(app, Signals.itemActivated, createTab)
        connect(app, Signals.openUrl, createTab)
        connect(app, Signals.tickerClicked, createTab)
        self.requestSession()

    def createTab(self, value):
        """ Create or display a tab from a value

        @param value string or model item
        @return None
        """
        for handler in self.createHandlers:
            try:
                if handler(value):
                    break
            except (Exception, ), exc:
                msg = 'Exception (debug): %r:%s (h:%s)'
                logging.debug(msg, exc, exc, handler, )

    def createBrowserTab(self, item):
        """ Creates a new web browser tab.

        @param value string or model item
        @return True if display widget created, otherwise None
        """
        from profit.lib.widgets.webbrowser import WebBrowserDisplay
        if isinstance(item, (basestring, )):
            item = makeUrlItem(item)
        if item.data(DataRoles.url).isValid():
            url = item.data(DataRoles.url).toString()
            title = item.data(DataRoles.urlTitle).toString()
            widget = WebBrowserDisplay(self)
            widget.basicConfig(url)
            index = self.addTab(widget, title)
            icon = item.icon()
            if icon.isNull():
                icon = QIcon(":/images/icons/www.png")
            self.setTextIconCurrentTab(index, title, icon)
            loadHandler = partial(self.resetBrowserTab, browser=widget)
            self.connect(widget, Signals.loadFinished, loadHandler)
            return True

    def createTickerPlotFromView(self, data):
        """

        """
        from profit.workbench.tickerplotdisplay import TickerPlotDisplay
        try:
            tid, sym = data[0:2]
        except (TypeError, ValueError, ):
            return
        sym = sym or self.symbolName(tid)
        icon = symbolIcon(sym) if sym else QIcon(':/images/icons/kchart.png')
        sym = sym or '%s' % tid
        widget = TickerPlotDisplay(self)
        session = self.session
        widget.setSessionPlot(session, session.maps.ticker, tid)
        index = self.addTab(widget, sym)
        self.setTextIconCurrentTab(index, sym, icon)
        return True

    def symbolName(self, tickerId):
        """ Returns the symbol name given a ticker id.

        This should reference self.session.models.contracts instead.
        """
        symbols = self.session.strategy.symbols()
        try:
            return dict([(b, a) for a, b in symbols.items()])[tickerId] or ''
        except (KeyError, ):
            return ''

    def createTickerPlotTab(self, item):
        """ Creates or displays a ticker plot tab.

        @param value string or model item
        @return True if display widget created, otherwise None
        """
        from profit.workbench.tickerplotdisplay import TickerPlotDisplay
        tickerId, tickerIdValid = item.data(DataRoles.tickerId).toInt()
        symbol = str(item.data(DataRoles.tickerSymbol).toString())
        if tickerIdValid and self.setCurrentLabel(symbol):
            return True
        if tickerIdValid:
            widget = TickerPlotDisplay(self)
            session = self.session
            widget.setSessionPlot(session, session.maps.ticker, tickerId)
            index = self.addTab(widget, symbol)
            icon = QIcon(item.data(Qt.DecorationRole))
            self.setTextIconCurrentTab(index, symbol, icon)
            return True

    def createDisplayTab(self, item):
        """ Creates or displays a name-based display.

        @param value string or model item
        @return True if display widget created, otherwise None
        """
        text = str(item.data().toString())
        if self.setCurrentLabel(text):
            return True
        name = str(item.data(DataRoles.displayImportName).toString())
        if name:
            cls = importItem(name)
            widget = cls(self)
            index = self.addTab(widget, text)
            icon = QIcon(item.data(Qt.DecorationRole))
            self.setTextIconCurrentTab(index, text, icon)
            return True

    def resetBrowserTab(self, okay, browser=None):
        """ Reconfigures a tab based on a web browser widget state.

        @param okay True if browser page load is finished
        @keyparam browser=None WebBrowserDispay object
        @return None
        """
        if not okay or not browser:
            return
        index = self.indexOf(browser)
        title = tooltip = str(browser.title())
        if len(title) > 13:
            title = title[0:13] + '...'
        self.setTabText(index, title)
        self.setTabToolTip(index, tooltip)
