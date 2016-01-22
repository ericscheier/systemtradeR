#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from PyQt4.QtCore import Qt, pyqtSignature
from PyQt4.QtGui import QFrame, QStandardItemModel

from ib.opt.message import messageTypeNames

from profit.lib.gui import StandardItem
from profit.lib.widgets.ui_propertyeditor import Ui_PropertyEditor


class PropertyEditorModel(QStandardItemModel):
    labels = ['Property', 'Value', ]

    def __init__(self, widget, parent=None):
        QStandardItemModel.__init__(self, parent)
        self.setHorizontalHeaderLabels(self.labels)
        items = [(name, getattr(widget, name)) for name in dir(widget)
                 if not name.startswith('_')]
        for name, value in sorted(items):
            self.appendRow(self.makeRowItems(name, value))

    def makeRowItems(self, key, value):
        return [StandardItem(key, enabled=True),
                StandardItem(str(value), enabled=True), ]


class PropertyEditor(QFrame, Ui_PropertyEditor):
    """ PropertyEditor -> just a viewer right now.

    """
    def __init__(self, parent=None):
        """ Initializer.

        @param parent ancestor object
        """
        QFrame.__init__(self, parent)
        self.setupUi(self)

    def setFromWidget(self, widget):
        widgetType = type(widget)
        widgetName = widget.objectName()
        self.nameLabel.setText('Name: ' + widgetName)
        self.classLabel.setText('Type: ' + widgetType.__name__)
        self.model = PropertyEditorModel(widget, self)

        view = self.propertyTableView
        view.reset()
        view.setModel(self.model)
        view.verticalHeader().hide()
        view.resizeColumnsToContents()

