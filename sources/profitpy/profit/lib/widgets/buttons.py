#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

from PyQt4.QtGui import QPushButton

from profit.lib.widgets.ui_closetabbutton import Ui_CloseTabButton
from profit.lib.widgets.ui_detachtabbutton import Ui_DetachTabButton


class CloseTabButton(QPushButton, Ui_CloseTabButton):
    """

    """
    def __init__(self, parent):
        QPushButton.__init__(self, parent)
        self.setupUi(self)
        self.addAction(self.actionCloseTab)


class DetachTabButton(QPushButton, Ui_DetachTabButton):
    """

    """
    def __init__(self, parent):
        QPushButton.__init__(self, parent)
        self.setupUi(self)
        self.addAction(self.actionDetachTab)
