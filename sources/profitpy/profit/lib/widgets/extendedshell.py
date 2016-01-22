#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

from PyQt4.QtCore import Qt, pyqtSignature
from PyQt4.QtGui import QFrame, QToolBar

from profit.lib import BasicHandler, defaults
from profit.lib.widgets.ui_extendedshell import Ui_ExtendedShell


class ExtendedPythonShell(QFrame, Ui_ExtendedShell, BasicHandler):
    """ A shell widget extended with an editor widget.

    """
    def __init__(self, parent=None):
        QFrame.__init__(self, parent)
        self.setupUi(self)
        self.setupWidgets()

    def setupWidgets(self):
        """ Make our widgets like we like.

        """
        settings = self.settings
        settings.beginGroup(self.__class__.__name__)
        defaultState = defaults.leftSplitterState()
        splitState = settings.value(settings.keys.splitstate, defaultState)
        self.splitter.restoreState(splitState.toByteArray())
        settings.endGroup()

    def on_splitter_splitterMoved(self, pos, index):
        """ Signal handler for splitter move; saves state to user settings.

        @param pos ignored
        @param index ignored
        @return None
        """
        settings = self.settings
        settings.beginGroup(self.__class__.__name__)
        settings.setValue(settings.keys.splitstate, self.splitter.saveState())
        settings.endGroup()

    @pyqtSignature('')
    def on_executeButton_clicked(self):
        """ Execute the source code in the shell.

        """
        lines = str(self.editorWidget.text()).split('\n')
        self.shellWidget.runLines(lines)
