#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

import csv

from PyQt4.QtCore import Qt, pyqtSignature
from PyQt4.QtGui import QFileDialog, QFrame, QIcon

from profit.lib import BasicHandler, Signals, defaults
from profit.lib.gui import symbolIcon
from profit.lib.widgets.historicaldatadialog import HistoricalDataDialog
from profit.lib.widgets.ui_localtableviewframe import Ui_LocalTableViewFrame
from profit.workbench.widgets.ui_historicaldatadisplay import \
     Ui_HistoricalDataDisplay


class HistoricalDataDisplay(QFrame, Ui_HistoricalDataDisplay, BasicHandler):
    """ HistoricalDataDisplay -> displays historical data requests, of course.

    """
    def __init__(self, parent=None):
        """ Initializer.

        @param parent ancestor of this object
        """
        QFrame.__init__(self, parent)
        self.setupUi(self)
        self.splitter.restoreState(defaults.rightSplitterState())
        self.requestTabs.closeTabButton.actionCloseTab.setShortcuts([])
        self.requestTabs.detachTabButton.actionDetachTab.setShortcuts([])
        self.requestSession()

    def setSession(self, session):
        """ Configures this instance for a session.

        @param session Session instance
        @return None
        """
        self.session = session
        model = session.models.histdata
        model.symbolIcon = symbolIcon
        view = self.requestsView
        view.verticalHeader().hide()
        view.setModel(model)
        self.connect(view.selectionModel(),
                     Signals.selectionChanged,
                     self.on_requestsView_selectionChanged)
        session.registerMeta(self)

    def on_session_HistoricalData(self, message):
        self.requestsView.resizeColumnsToContents()
        self.session.deregisterMeta(self)

    def createTab(self, requestId):
        """ Creates a new tab for the hist data request.

        @param requestId hist data request identifier, int
        @return None
        """
        tabs = self.requestTabs
        name = '%s' % requestId
        if tabs.setCurrentLabel(name):
            return
        title = 'Historical Data Request %s' % requestId
        widget = DataView(requestId, title, tabs)
        index = tabs.addTab(widget, name)
        icon = QIcon(':images/icons/log.png')
        tabs.setTextIconCurrentTab(index, name, icon)

    @pyqtSignature('')
    def on_exportButton_clicked(self):
        """

        """
        filename = QFileDialog.getSaveFileName(self, 'Export Historical Data')
        if not filename:
            return
        writer = csv.writer(open(filename, 'wb'))
        def iterIndexes():
            for index in self.requestsView.selectionModel().selectedIndexes():
                model = index.model()
                print '###', model
                for row in model.iterrows():
                    yield row
        writer.writerows(iterIndexes())

    @pyqtSignature('')
    def on_newRequestButton_clicked(self):
        """ Shows new hist data request dialog and signal its results, if any.

        @return None
        """
        dlg = HistoricalDataDialog(self)
        if dlg.exec_() != dlg.Accepted:
            return
        params = dlg.historicalRequestParameters()
        self.session.emit(Signals.histdata.request, params)

    def on_requestsView_doubleClicked(self, index):
        """ Creates a new display tab when a request is double-clicked.

        @return None
        """
        if not index.isValid():
            return
        reqId = index.internalPointer()[0]
        self.createTab(reqId)

    def on_requestsView_selectionChanged(self, selected, deselected):
        """ Enables or disables the export button as requests are selected.

        @return None
        """
        selected = bool(self.requestsView.selectionModel().selectedIndexes())
        self.exportButton.setEnabled(selected)


class DataView(QFrame, Ui_LocalTableViewFrame, BasicHandler):
    """ DataView -> viewer for a historical data message request

    """
    def __init__(self, requestId, title, parent=None):
        """ Initializer.

        @param requestId hist data request identifier, int
        @param title window title for this widget, string
        @param parent ancestor of this widget
        """
        QFrame.__init__(self, parent)
        self.setupUi(self)
        self.requestId = requestId
        self.setWindowTitle(title)
        self.requestSession()

    def setSession(self, session):
        """ Configures this instance for a session.

        @param session Session instance
        @return None
        """
        view = self.tableView
        view.verticalHeader().hide()
        model = session.models.histdata.subModel(self.requestId)
        if model:
            view.setModel(model)
