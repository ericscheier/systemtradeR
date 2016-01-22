#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from PyQt4.QtGui import QFrame

from profit.lib import BasicHandler, Signals
from profit.lib.gui import symbolIcon
from profit.workbench.widgets.ui_portfoliodisplay import Ui_PortfolioDisplay


class PortfolioDisplay(QFrame, Ui_PortfolioDisplay, BasicHandler):
    """ PortfolioDisplay -> display the portfolio messages

    """
    def __init__(self, parent=None):
        """ Initializer.

        @param parent ancestor of this object
        """
        QFrame.__init__(self, parent)
        self.setupUi(self)
        self.requestSession()

    def setSession(self, session):
        """ Configures this instance for a session.

        @param session Session instance
        @return None
        """
        self.session = session
        model = session.models.portfolio
        model.symbolIcon = symbolIcon
        self.connect(model, Signals.modelReset, self.resizeTree)
        self.portfolioView.setModel(model)

    def resizeTree(self):
        """ Resizes all columns in the portfolio tree.

        """
        view = self.portfolioView
        cols = range(view.model().invisibleRootItem.itemCount())
        for col in cols:
            view.resizeColumnToContents(col)

