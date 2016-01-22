#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from PyQt4.QtCore import QVariant, pyqtSignature
from PyQt4.QtGui import QFrame

from profit.lib import Settings, Signals
from profit.lib.widgets.plot import Plot
from profit.workbench.widgets.ui_tickerplotdisplay import Ui_TickerPlotDisplay


class TickerPlotDisplay(QFrame, Ui_TickerPlotDisplay):
    """ Combines one or more plot widgets into a single display.

    """
    def __init__(self, parent=None):
        """ Constructor.

        @param parent ancestor object
        """
        QFrame.__init__(self, parent)
        self.setupUi(self)
        self.sessionArgs = None
        self.plotWidgets = []

    def addPlot(self):
        plot = Plot()
        splitter = self.plotSplitter
        widgets = self.plotWidgets
        after = -1
        try:
            sender = self.sender().parent()
        except (AttributeError, ):
            pass
        else:
            plots = [(splitter.widget(i), i) for i in range(splitter.count())]
            try:
                after = 1 + dict(plots)[sender]
            except (KeyError, ):
                pass
        widgets.append(plot)
        self.reconfigurePlots()
        self.connect(plot.actionNewPlot, Signals.triggered, self.addPlot)
        self.connect(plot.actionClosePlot, Signals.triggered, self.closePlot)
        self.connect(plot.actionSyncWithData, Signals.triggeredBool,
                     plot.syncPlot)
        if self.sessionArgs:
            session, collection, tickerId, args = self.sessionArgs
            plot.setSessionPlot(session, collection, tickerId, *args)
        splitter.insertWidget(after, plot)
        plot.show()

    def closePlot(self):
        try:
            plot = self.sender().parent()
        except (AttributeError, ):
            pass
        else:
            if plot in self.plotWidgets:
                self.plotWidgets.remove(plot)
            plot.close()
        self.reconfigurePlots()

    def reconfigurePlots(self):
        self.setActionsEnabled()
        self.reconnectSplitters()
        self.renamePlots()
        self.saveCount()

    def reconnectSplitters(self):
        connect = self.connect
        disconnect = self.disconnect
        widgets = self.plotWidgets
        signal = Signals.splitterMoved
        for widget in widgets:
            wsplit = widget.plotSplitter
            for other in [w for w in widgets if w is not widget]:
                disconnect(wsplit, signal, other.plotSplitter.moveSplitter)
                disconnect(other.plotSplitter, signal, wsplit.moveSplitter)
        if widgets:
            first, others = widgets[0], widgets[1:]
            fsplit = first.plotSplitter
            for other in others:
                connect(fsplit, signal, other.plotSplitter.moveSplitter)

    def renamePlots(self):
        for index, plot in enumerate(self.plotWidgets):
            plot.setObjectName('indexPlot%s' % index)

    def saveCount(self):
        settings = Settings()
        settings.beginGroup('Plots')
        settings.beginGroup('%s' % self.sessionArgs[1].__class__.__name__)
        settings.setValue('displaycount', len(self.plotWidgets))

    def setActionsEnabled(self):
        single = len(self.plotWidgets) < 2
        maxed = len(self.plotWidgets) > 5
        for plot in self.plotWidgets:
            plot.actionClosePlot.setEnabled(not single)
            plot.actionNewPlot.setEnabled(not maxed)

    def setSessionPlot(self, session, collection, tickerId, *args):
        """ Associate a session with this instance.

        @param session Session instance
        @param tickerId id of ticker as integer
        @param *indexes unused
        @return None
        """
        self.sessionArgs = (session, collection, tickerId, args)
        if not self.plotWidgets:
            settings = Settings()
            settings.beginGroup('Plots')
            settings.beginGroup('%s' % tickerId)
            #count = settings.value('displaycount', QVariant(1)).toInt()[0]
            count = 1
            for i in range(count):
                self.addPlot()
        else:
            for plot in self.plotWidgets:
                plot.setSessionPlot(session, collection, tickerId, *args)
