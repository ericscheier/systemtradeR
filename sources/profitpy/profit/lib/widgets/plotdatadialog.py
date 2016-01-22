#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

from PyQt4.QtCore import QAbstractTableModel, QVariant, Qt, pyqtSignature
from PyQt4.QtGui import QApplication, QBrush, QColorDialog, QDialog
from PyQt4.QtGui import QFileDialog, QFont, QFontDialog, QListWidgetItem

from profit.lib import Settings, Signals, defaults
from profit.lib.gui import colorIcon
from profit.lib.widgets.ui_plotdatadialog import Ui_PlotDataDialog


class CurveDataTableModel(QAbstractTableModel):
    def __init__(self, parent):
        QAbstractTableModel.__init__(self, parent)
        self.key = parent.key
        self.items = []
        self.itemAlign = QVariant(Qt.AlignRight|Qt.AlignVCenter)
        for item in parent.checkedItems():
            self.on_enableCurve(item, True)
        self.connect(parent, Signals.enableCurve, self.on_enableCurve)
        parent.session.registerMeta(self)

    def columnCount(self, parent=None):
        return len(self.items)

    def data(self, index, role):
        row, col = index.row(), index.column()
        if not index.isValid():
            data = QVariant()
        elif role == Qt.TextAlignmentRole:
            data = self.itemAlign
        elif role == Qt.ForegroundRole:
            data = QVariant(QBrush(self.items[col].color))
        elif role == Qt.BackgroundRole:
            data = QVariant(QBrush(self.items[col].curve.brush()))
        elif role != Qt.DisplayRole:
            data = QVariant()
        else:
            try:
                data = self.items[col].data[row]
                data = QVariant(data) if data is not None else QVariant()
            except (IndexError, ):
                data = QVariant()
        return data

    def headerData(self, section, orientation, role):
        if orientation == Qt.Horizontal and role == Qt.DisplayRole:
            return QVariant(self.items[section].text())
        elif orientation == Qt.Vertical and role == Qt.DisplayRole:
            return QVariant(section)
        return QVariant()

    def rowCount(self, parent=None):
        try:
            count = max(len(item.data) for item in self.items)
        except (ValueError, ):
            count = 0
        return count

    def on_enableCurve(self, item, enable):
        if enable and item not in self.items:
            self.items.append(item)
        elif not enable and item in self.items:
            self.items.remove(item)
        self.reset()

    def on_session_TickPrice_TickSize(self, message):
        """ Signal handler for TickPrice and TickSize session messages.

        @param message Message instance
        @return None
        """
        if message.tickerId == self.key:
            self.emit(Signals.layoutChanged)


class PlotDataDialog(QDialog, Ui_PlotDataDialog):
    def __init__(self, parent):
        QDialog.__init__(self, parent)
        self.setupUi(self)
        self.model = CurveDataTableModel(parent)
        self.plotDataView.setModel(self.model)
        self.addAction(self.actionClose)
        self.connect(
            self.plotDataView.selectionModel(),
            Signals.selectionChanged,
            self.on_selectionChanged)

    def on_selectionChanged(self, current, previous):
        selections = self.plotDataView.selectedIndexes()
        model = self.model
        items = [(index, model.items[index.column()]) for index in selections]
        self.emit(Signals.highlightSelections, items)
