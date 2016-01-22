#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

## TODO:  use generic icon, not symbol

from urlparse import urlparse, urlunparse

from PyQt4.QtCore import pyqtSignature, QEvent, QObject, Qt, QUrl
from PyQt4.QtGui import QWidget

from profit.lib import Signals
from profit.lib.widgets.ui_webbrowser import Ui_WebBrowserDisplay


class WebBrowserDisplay(QWidget, Ui_WebBrowserDisplay):
    """

    """
    def __init__(self, parent=None):
        """ Constructor.

        @param parent ancestor of this widget
        """
        QWidget.__init__(self, parent)
        self.setupUi(self)
        self.urlEdit.keyReleaseEvent = self.urlEdit__keyReleaseEvent
        self.timerId = self.startTimer(1000)

    def basicConfig(self, url):
        self.urlEdit.setText(url)
        self.webView.load(QUrl(url))
        self.connect(self.webView, Signals.loadFinished, self.setWebLocation)
        self.connect(self.webView, Signals.loadFinished, self, Signals.loadFinished)

    def loadUrlString(self, text):
        url = urlunparse(urlparse(str(text), 'http')).replace('///', '//') # wtf
        self.webView.load(QUrl(url, QUrl.TolerantMode))

    def setWebLocation(self, okay):
        if okay:
            self.urlEdit.setText(self.webView.url().toString())

    def title(self):
        return self.webView.title()

    def setLoadingState(self, state):
        self.reloadButton.setEnabled(not state)
        self.stopButton.setEnabled(state)

    def urlEdit__keyReleaseEvent(self, event):
        if event.key() in (Qt.Key_Enter, Qt.Key_Return, ):
            self.loadUrlString(self.urlEdit.text())
        else:
            QWidget.keyReleaseEvent(self, event)

    def keyReleaseEvent(self, event):
        if event.key() in (Qt.Key_Escape, ):
            self.webView.stop()
            self.setLoadingState(False)

    @pyqtSignature('')
    def on_goButton_clicked(self):
        if self.urlEdit.text() != self.webView.url().toString():
            self.loadUrlString(self.urlEdit.text())

    @pyqtSignature('')
    def on_reloadButton_clicked(self):
        self.setLoadingState(True)

    @pyqtSignature('')
    def on_stopButton_clicked(self):
        self.setLoadingState(False)

    @pyqtSignature('')
    def on_webView_loadStarted(self):
        self.setLoadingState(True)

    @pyqtSignature('')
    def on_webView_iconChanged(self):
        print '#### icon changed!!!'

    def timerEvent(self, event):
        history = self.webView.history()
        self.backButton.setEnabled(history.canGoBack())
        self.forwardButton.setEnabled(history.canGoForward())
