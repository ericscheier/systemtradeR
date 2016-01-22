#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from PyQt4.QtGui import QDialog
from profit.lib.widgets.ui_importexportdialog import Ui_ImportExportDialog


class ImportExportDialog(QDialog, Ui_ImportExportDialog):
    """ Dialog for selecting message types for import or export.

    """
    def __init__(self, typeText, parent=None):
        QDialog.__init__(self, parent)
        self.setupUi(self)
        self.setWindowTitle(str(self.windowTitle()) % typeText)
        self.promptText.setText(str(self.promptText.text()) % typeText)

    def allTypes(self):
        """ Returns list of all type names (as strings)

        """
        return self.messageTypeDisplay.allTypes()

    def selectedTypes(self):
        """ Returns list of seleected type names (as strings)

        """
        return self.messageTypeDisplay.selectedTypes()

if __name__ == '__main__':
    from PyQt4.QtGui import QApplication
    app = QApplication([])
    dlg = ImportExportDialog('Demonstration')
    if dlg.exec_() == dlg.Accepted:
        print dlg.selectedTypes()

