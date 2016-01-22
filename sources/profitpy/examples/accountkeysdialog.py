#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from PyQt4.QtCore import Qt
from PyQt4.QtGui import QDialog, QStandardItem, QStandardItemModel

from .ui_accountkeysdialog import Ui_AccountKeysDialog


class AccountKeysModel(QStandardItemModel):
    def __init__(self, parent=None):
        QStandardItemModel.__init__(self, parent)
        self.setHorizontalHeaderLabels(['Display', 'Item', 'Currency'])

    def keys(self):
        item = self.item
        rows = self.rowCount(self.indexFromItem(self.invisibleRootItem()))
        for r in range(rows):
            yield (str(item(r, 1).text()), str(item(r, 2).text())), \
                      item(r, 0).checkState()==Qt.Checked



class AccountKeysItem(QStandardItem):
    def __init__(self, text='', checked=0, checkable=False):
        QStandardItem.__init__(self, text)
        self.setEditable(False)
        self.setCheckable(checkable)
        if checkable:
            self.setCheckState(Qt.CheckState(2 if checked else 0))


class AccountKeysDialog(QDialog, Ui_AccountKeysDialog):
    def __init__(self, parent=None):
        QDialog.__init__(self, parent)
        self.setupUi(self)
        self.dataModel = AccountKeysModel()
        self.tableView.setModel(self.dataModel)
        self.tableView.verticalHeader().hide()

    def setupKeys(self, mapping):
        model = self.dataModel
        for (key, currency), checked in sorted(mapping):
            model.appendRow([
                AccountKeysItem(checked=checked, checkable=True),
                AccountKeysItem(key),
                AccountKeysItem(currency)
                ])
        view = self.tableView
        view.resizeRowsToContents()
        view.resizeColumnsToContents()

    def keys(self):
        return self.dataModel.keys()
