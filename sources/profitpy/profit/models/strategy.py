#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from PyQt4.QtCore import Qt, QModelIndex, QVariant, QSize, QString
from profit.lib import Signals, valueAlign, BasicHandler
from profit.models import BasicItem, BasicItemModel


class StrategyModel(BasicItemModel, BasicHandler):
    """ Model for strategies.

    """
    def __init__(self, session=None, parent=None):
        """ Initializer.

        @param session=None session reference or None
        @param parent=None ancestor of this object or None
        """
        BasicItemModel.__init__(self, RootStrategyItem(), parent)
        self.iconMap = {}
        self.session = session
        if session is not None:
            session.registerMeta(self)
        self.reflectSignals(Signals.strategy.requestActivate)
        self.readSettings()

    def data(self, index, role=Qt.DisplayRole):
        """ Framework hook to retreive data stored at index for given role.

        @param index QModelIndex instance
        @param role Qt.DisplayRole flags
        @return QVariant instance
        """
        data = QVariant()
        if not index.isValid():
            return data
        col = index.column()
        item = index.internalPointer()
        if role == Qt.DisplayRole:
            if col in (item.tickersIdx, item.runnersIdx):
                data = 'active' if item[col] else 'inactive'
            elif col == item.filenameIdx:
                data = item[item.filenameIdx]
        elif role == Qt.DecorationRole:
            if col in (item.tickersIdx, item.runnersIdx):
                data = self.iconMap.get(item[col], QVariant())
        elif role == Qt.EditRole:
            data = item[col]
        elif role == Qt.CheckStateRole:
            if col in (item.tickersIdx, item.runnersIdx):
                data = (item[col] and Qt.Checked) or Qt.Unchecked
        elif role == Qt.SizeHintRole:
            data = QSize(0, 30)
        data = QVariant(data)
        return data

    def decodeRows(self, rows):
        """ Yields a list of items for each row.

        """
        for row in rows:
            yield [False, False, row.get('filename', '')]

    def flags(self, index):
        if not index.isValid():
            return Qt.ItemIsEnabled
        col = index.column()
        item = index.internalPointer()
        flags = Qt.ItemIsEnabled | Qt.ItemIsSelectable
        if col == item.tickersIdx:
            flags |= Qt.ItemIsUserCheckable | Qt.ItemIsEditable
        elif col == item.runnersIdx:
            flags |= Qt.ItemIsUserCheckable | Qt.ItemIsEditable
        elif col == item.filenameIdx:
            if 0: # item[item.tickersIdx] or item[item.runnersIdx]:
                flags = Qt.NoItemFlags
            else:
                flags |= Qt.ItemIsSelectable | Qt.ItemIsEditable
        return flags

    def readSettings(self):
        """ Loads saved strategies directly into the model.

        """
        root = self.invisibleRootItem
        settings = self.settings
        settings.beginGroup(settings.keys.strategy)
        for row in self.decodeRows(settings.valueLoad('strategies', [])):
            root.append(StrategyItem(row, root))
        settings.endGroup()
        self.reset()

    def saveSettings(self):
        """

        """
        settings = self.settings
        settings.beginGroup(settings.keys.strategy)
        settings.setValueDump('strategies', self.strategyModel.encodeRows())
        settings.endGroup()


    def setData(self, index, value, role=Qt.EditRole):
        """ Framework hook to set value at the given index for the role.

        """
        if not index.isValid():
            return False
        item = index.internalPointer()
        col = index.column()
        if col in (item.tickersIdx, item.runnersIdx):
            value = item[col] = value.toBool()
            rowdict = {'active':value, 'filename':item[item.filenameIdx]}
            self.emit(Signals.strategy.requestActivate,
                      rowdict, value)
        elif col in (item.filenameIdx, ):
            item[col] = str(value.toString())
        else:
            return False
        self.emit(Signals.dataChanged, index, index)
        return True

    def removeRow(self, row, parent=QModelIndex()):
        root = self.invisibleRootItem
        self.beginRemoveRows(parent, row, row)
        result = root.children.pop(row)
        self.endRemoveRows()
        return bool(result)

    def appendRowFromData(self, filename='', **kwds):
        root = self.invisibleRootItem
        row = root.childCount()
        self.beginInsertRows(QModelIndex(), row, row)
        root.append(StrategyItem([False, False, filename], root))
        self.endInsertRows()


class StrategyItem(BasicItem):
    """ Base class for items in the strategy model.

    """
    columnIndexes = tickersIdx, runnersIdx, filenameIdx = range(3)
    columnLookups = [
        ('Tickers', None),
        ('Runners', None),
        ('Filename', None),
    ]


class RootStrategyItem(StrategyItem):
    """ Strategy model item with automatic values (for horizontal headers).

    """
    def __init__(self):
        StrategyItem.__init__(self, self.horizontalLabels())

    def horizontalLabels(self):
        """ Generates list of horizontal header values.

        """
        return map(QVariant, [label for label, lookup in self.columnLookups])
