#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

from sys import platform

from PyQt4.QtCore import Qt, QTimer
from PyQt4.QtGui import QTabWidget

from profit.lib import Signals
from profit.lib.gui import addCloseAction
from profit.lib.widgets.buttons import CloseTabButton, DetachTabButton


class LocalTabWidget(QTabWidget):
    """ LocalTabWidget -> tab widget with special powers

    """
    def __init__(self, parent=None):
        """ Initializer.

        @param parent ancestor of this widget
        """
        QTabWidget.__init__(self, parent)
        self.closeTabButton = CloseTabButton(self)
        self.detachTabButton = DetachTabButton(self)
        self.setCornerWidget(self.closeTabButton, Qt.TopRightCorner)
        self.setCornerWidget(self.detachTabButton, Qt.TopLeftCorner)
        connect = self.connect
        connect(self.closeTabButton, Signals.clicked, self.closeTab)
        connect(self.detachTabButton, Signals.clicked, self.detachTab)

    def closeTab(self):
        """ Closes the current tab.

        """
        index = self.currentIndex()
        widget = self.widget(index)
        if widget:
            self.removeTab(index)
            widget.setAttribute(Qt.WA_DeleteOnClose)
            widget.close()

    def closeTabs(self):
        """ Closes all tabs.

        """
        while self.currentIndex() != -1:
            self.closeTab()

    def detachTab(self):
        """ Deatches the current tab and makes it a top-level window.

        @return None
        """
        index = self.currentIndex()
        text = str(self.tabText(index))
        widget = self.widget(index)
        widget.setWindowIcon(self.tabIcon(index))
        try:
            widget.setWindowTitle(str(widget.windowTitle()) % text)
        except (TypeError, ):
            pass
        addCloseAction(widget)
        if platform.startswith('win'):
            def show():
                widget.setParent(QApplication.desktop())
                widget.setWindowFlags(Qt.Dialog)
                widget.show()
        else:
            def show():
                widget.setParent(self.window())
                widget.setWindowFlags(Qt.Window)
                widget.show()
        QTimer.singleShot(100, show)

    def pageMap(self):
        """ Makes a mapping like {'connection':1, 'account':3, ...}

        @return mapping of tab name to tab index
        """
        return dict([(str(self.tabText(i)), i) for i in range(self.count())])

    def setCurrentLabel(self, label):
        """ Sets current tab by name if possible.

        @param label text of tab to make current
        @return True if successful, otherwise None
        """
        index = self.pageMap().get(label)
        if index is not None:
            self.setCurrentIndex(index)
            return True

    def setTextIconCurrentTab(self, index, text, icon):
        """ Sets tab text and icon, and makes tab current.

        @param index index of tab to modify and display
        @param text text for tab
        @param icon icon for tab
        @return None
        """
        self.setTabText(index, text)
        self.setTabIcon(index, icon)
        self.setCurrentIndex(index)
