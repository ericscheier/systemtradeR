#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from PyQt4.QtCore import Qt, pyqtSignature
from PyQt4.QtGui import QFrame, QStandardItem

from ib.opt.message import messageTypeNames
from profit.lib.widgets.ui_messagetypeselect import Ui_MessageTypeSelect


class MessageTypeSelect(QFrame, Ui_MessageTypeSelect):
    """ MessageTypeSelect -> widget for selecting various IB message types.

    """
    def __init__(self, parent=None):
        """ Initializer.

        @param parent ancestor object
        """
        QFrame.__init__(self, parent)
        self.setupUi(self)
        self.setupTypesList()

    def setupTypesList(self):
        """ Clears and fills the types list.

        """
        typesList = self.typesList
        typesList.clear()
        self.allTypeNames = typeNames = messageTypeNames()
        for typeRow, typeName in enumerate(sorted(typeNames)):
            typesList.addItem(typeName)
            item = typesList.item(typeRow)
            item.setCheckState(Qt.Checked)

    def listItems(self):
        """ Returns the QStandardItems in the types list.

        """
        listWidget = self.typesList
        return [listWidget.item(r) for r in range(listWidget.count())]

    def allTypes(self):
        """ Returns list of all type names (as strings)

        """
        return [str(i.text()) for i in self.listItems()]

    def selectedTypes(self):
        """ Returns list of seleected type names (as strings)

        """
        if self.allCheck.checkState()==Qt.Checked:
            return self.allTypeNames
        return [str(i.text()) for i in self.listItems()
                if i.checkState()==Qt.Checked]

    @pyqtSignature('')
    def on_checkNoneButton_clicked(self):
        """ Unchecks every item in the types list.

        """
        for item in self.listItems():
            item.setCheckState(Qt.Unchecked)

    @pyqtSignature('')
    def on_checkAllButton_clicked(self):
        """ Checks every item in the types list.

        """
        for item in self.listItems():
            item.setCheckState(Qt.Checked)
