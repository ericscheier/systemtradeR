#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

from PyQt4.QtCore import Qt, QUrl, QVariant
from PyQt4.QtGui import QAction, QBrush, QColor, QDesktopServices, QIcon, QMessageBox
from PyQt4.QtGui import QPixmap, QTableWidgetItem, QStandardItem

from profit.lib import DataRoles, Signals, valueAlign


def addCloseAction(widget):
    """ Adds a close action and connects it to the widget close slot.

    @param widget any QWidget instance
    @return new QAction instance
    """
    action = QAction('Close', widget)
    action.setShortcut('Ctrl+W')
    widget.addAction(action)
    widget.connect(action, Signals.triggered, widget.close)
    return action


def complementColor(color):
    """ Generates a complementary color for the given string.

    @param color QColor instance
    @return QColor with complementary value
    """
    hx = str(color.name())[1:]
    comp = ['%.2X' % (255 - int(a, 16)) for a in (hx[0:2], hx[2:4], hx[4:6])]
    return QColor('#' + str.join('', comp))


def makeUrlAction(text, url, toolTip='', parent=None):
    action = QAction(text + '...', parent)
    action.setData(QVariant(url))
    action.setToolTip(toolTip)
    return action


def makeUrlItem(v):
    item = QStandardItem(v)
    item.setData(QVariant(v), DataRoles.url)
    item.setData(QVariant(''), DataRoles.urlTitle)
    return item


def colorIcon(color, width=10, height=10):
    """ Creates an icon filled with specified color.

    @param color QColor instance
    @param width width of icon in pixels
    @param height of icon in pixels
    @return QIcon instance
    """
    pixmap = QPixmap(width, height)
    pixmap.fill(color)
    return QIcon(pixmap)


def separator():
    sep = QAction(None)
    sep.setSeparator(True)
    return sep


def symbolIcon(symbol):
    """ Icon for a symbol.

    @param symbol name of symbol
    @return QIcon instance; transparent but valid if symbol icon not found
    """
    icon = QIcon(':images/tickers/%s.png' % (symbol.lower(), ))
    if icon.pixmap(16,16).isNull():
        pixmap = QPixmap(16, 16)
        pixmap.fill(QColor(0, 0, 0, 0))
        icon = QIcon(pixmap)
    return icon


def warningBox(title, text):
    return QMessageBox.warning(None, title, text, QMessageBox.Close)


class StandardItem(QStandardItem):
    """ Convenience QStandardItem subclass with many init keywords.

    """

    def __init__(self, text='', editable=False,
                 checkState=Qt.Unchecked, checkable=False,
                 enabled=False, icon=None, alignment=None):
        QStandardItem.__init__(self, text)
        self.setEditable(editable)
        self.setEnabled(enabled)
        self.setCheckable(checkable)
        if checkable:
            self.setCheckState(checkState)
        if icon:
            self.setIcon(icon)
        if alignment is not None:
            self.setTextAlignment(alignment)


class UrlRequestor(object):
    """ Mixin that provides method for initial handling of requests to open a URL.

    Object instances must have a settings member.
    """
    def requestUrl(self, action):
        url = action.data().toString()
        settings = self.settings
        settings.beginGroup(settings.keys.main)
        useExternal = settings.value('useSystemBrowser', False).toBool()
        settings.endGroup()
        if useExternal:
            QDesktopServices.openUrl(QUrl(url))
        else:
            item = QStandardItem(url)
            item.setData(QVariant(url), DataRoles.url)
            item.setData(QVariant(action.toolTip()), DataRoles.urlTitle)
            item.setIcon(action.icon())
            self.emit(Signals.openUrl, item)


class ValueColorItem(object):
    increase = QBrush(QColor(Qt.darkGreen))
    neutral = QBrush(QColor(Qt.blue))
    decrease = QBrush(QColor(Qt.red))
    compMap = {1:increase, -1:decrease, 0:neutral}

    @classmethod
    def setColors(cls, increase, neutral, decrease):
        compMap = cls.compMap
        cls.increase = compMap[1] = QBrush(increase)
        cls.neutral = compMap[0] = QBrush(neutral)
        cls.decrease = compMap[-1] = QBrush(decrease)


class ValueTableItem(QTableWidgetItem, ValueColorItem):
    """ Table item that changes colors based on value changes.

    """
    def __init__(self):
        """ Constructor.

        """
        QTableWidgetItem.__init__(self, self.UserType)
        self.setFlags(self.flags() & ~Qt.ItemIsEditable)
        self.value = None

    def setValue(self, value):
        """ Sets value of item and updates text color (if possible).

        @param string or number to set
        @return None
        """
        try:
            value = float(value)
        except (ValueError, ):
            self.setText(value)
            return
        current = self.value
        if current is None:
            self.value = value
            self.setText(str(value))
            return
        if value < current:
            self.setForeground(self.decrease)
        elif value > current:
            self.setForeground(self.increase)
        else:
            self.setForeground(self.neutral)
        self.value = value
        self.setText(str(value))

    def setSymbol(self, symbol):
        """ Sets the text and icon for a symbol-based item.

        @param symbol ticker symbol as string
        @return None
        """
        icon = symbolIcon(symbol)
        self.setIcon(icon)
        self.setText(symbol)

    def setValueAlign(self, alignment=valueAlign):
        """ Sets the text alignment of this item.

        @param alignment Qt alignment flags
        @return None
        """
        self.setTextAlignment(alignment)

    def setText(self, text):
        QTableWidgetItem.setText(self, str(text))


class WaitMessageBox(QMessageBox):
    """ Runs a callable until it returns true, or until the user aborts.

    """
    def __init__(self, callback, parent):
        """ Initializer.

        @param callback callable to run in a timer
        @param parent ancestor widget
        """
        QMessageBox.__init__(self, parent)
        self.callback = callback
        self.setIcon(self.Information)
        self.addButton(self.Abort)
        self.setWindowModality(Qt.NonModal)
        self.startTimer(500)

    def timerEvent(self, event):
        """ Runs the callback and closes this dialog when it's true.

        """
        if self.callback():
            self.killTimer(event.timerId())
            self.accept()
