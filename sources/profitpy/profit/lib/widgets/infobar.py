#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from PyQt4.QtCore import pyqtSignature
from PyQt4.QtGui import QFrame

from profit.lib import Signals
from profit.lib.widgets.ui_infobar import Ui_InfoBar


class InfoBar(QFrame, Ui_InfoBar):
    """ Widget with info label and hide button.

    """
    def __init__(self, parent=None):
        """ Constructor.

        @param parent ancestor of this widget
        """
        QFrame.__init__(self, parent)
        self.setupUi(self)
