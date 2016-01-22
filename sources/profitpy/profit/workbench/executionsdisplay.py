#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from PyQt4.QtGui import QFrame

from profit.lib import BasicHandler
from profit.lib.gui import symbolIcon
from profit.workbench.widgets.ui_executionsdisplay import Ui_ExecutionsDisplay


class ExecutionsDisplay(QFrame, Ui_ExecutionsDisplay, BasicHandler):
    """ Combines a filter bar and an exec details table.

    """
    def __init__(self, parent=None):
        """ Constructor.

        @param parent ancestor object
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
        model = session.models.executions
        model.symbolIcon = symbolIcon
        self.executionsView.setModel(model)
