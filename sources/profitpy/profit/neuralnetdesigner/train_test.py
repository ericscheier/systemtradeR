#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

import sys

from PyQt4.QtCore import QVariant
from PyQt4.QtGui import (QApplication, QFrame, QIcon,
                         QStandardItem, QStandardItemModel)

from profit.lib import BasicHandler
from profit.lib import Signals, tickerIdRole
from profit.lib.widgets.ui_breadfan_train import Ui_BreadFanTrainTree


class SessionTreeItem(QStandardItem):
    """ Session tree item.

    """
    iconNameMap = {
        'account':'identity',
        'connection':'server',
        'messages':'view_text',
        'orders':'klipper_dock',
        'portfolio':'bookcase',
        'strategy':'services',
        'tickers':'view_detailed',
    }

    def __init__(self, text):
        """ Constructor.

        @param text value for item display
        """
        QStandardItem.__init__(self, text)
        self.setEditable(False)
        self.setIcon(self.lookupIcon(text))
        hint = self.sizeHint()
        hint.setHeight(20)
        self.setSizeHint(hint)

    def lookupIcon(self, key):
        """ Locates icon for given key.

        @param key item text
        @return QIcon instance
        """
        try:
            name = self.iconNameMap[key]
            icon = QIcon(':images/icons/%s.png' % name)
        except (KeyError, ):
            style = QApplication.style()
            icon = style.standardIcon(style.SP_DirIcon)
        return icon


class SessionTreeTickerItem(SessionTreeItem):
    """ Specalized session tree item for ticker symbols.

    """
    def lookupIcon(self, key):
        """ Locates icon for given key.

        @param key ticker symbol
        @return QIcon instance
        """
        return QIcon(':images/tickers/%s.png' % key.lower())

    def setTickerId(self, tickerId):
        """ Sets item data for ticker id.

        @param tickerId id for ticker as integer
        @return None
        """
        self.setData(QVariant(tickerId), tickerIdRole)


class SessionTreeModel(QStandardItemModel):
    def __init__(self, session, parent=None):
        """ Constructor.

        @param session Session instance
        @param parent ancestor object
        """
        QStandardItemModel.__init__(self)
        self.session = session
        root = self.invisibleRootItem()
        for key, values in session.items():
            item = SessionTreeItem(key)
            root.appendRow(item)
            for value in values:
                if key == 'tickers':
                    subitem = SessionTreeTickerItem(value)
                    subitem.setTickerId(values[value])
                else:
                    subitem = SessionTreeItem(value)
                item.appendRow(subitem)


class BreadFanTrainTree(QFrame, Ui_BreadFanTrainTree):
    """ Tree view of a Session object.

    """
    def __init__(self, parent=None):
        """ Constructor.

        @param parent ancestor of this widget
        """
        QFrame.__init__(self, parent)
        self.setupUi(self)
        connect = self.connect

    def setupBasic(self, sender, newSignal):
        self.connect(sender, newSignal, self.on_newBreadNet)

    def on_newBreadNet(self, net):
        print '### signaled network', net
        ## fill and trainAlgorithm combo
        algorNames = [name for name in net.train_meta]
        algorCombo = self.trainAlgorithm
        algorCombo.clear()
        algorCombo.addItems(algorNames)
        if net.trained in algorNames:
            algorCombo.setCurrentIndex(algorNames.index(net.trained))

        ## fill params
        ## don't touch fill training data sources
        ## set training progress bar value

