#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

from PyQt4.QtCore import Qt, QModelIndex, QObject, QVariant, QAbstractItemModel


class BasicItem(object):
    """

    """
    def __init__(self, data, parent=None):
        self.data = data
        self.parent = parent
        self.children = []

    def __getitem__(self, column):
        return self.data[column]

    def __setitem__(self, column, value):
        self.data[column] = value

    def append(self, item):
        self.children.append(item)

    def child(self, row):
        return self.children[row]

    def childCount(self):
        return len(self.children)

    def itemCount(self):
        return len(self.data)

    def row(self):
        if self.parent:
            return self.parent.children.index(self)
        return 0

    def sort(self, cmp=None, key=None, reverse=False):
        self.children.sort(cmp=cmp, key=key, reverse=reverse)


class BasicItemModel(QAbstractItemModel):
    """

    """
    def __init__(self, root, parent=None):
        QAbstractItemModel.__init__(self, parent)
        self.invisibleRootItem = root
        self.symbolIcon = lambda x:None

    def indexItem(self, index):
        valid = index.isValid()
        return (index.internalPointer() if valid else self.invisibleRootItem)

    def columnCount(self, index):
        return self.indexItem(index).itemCount()

    def flags(self, index):
        if index.isValid():
            return Qt.ItemIsEnabled | Qt.ItemIsSelectable
        return Qt.ItemIsEnabled

    def headerData(self, section, orientation, role):
        if orientation == Qt.Horizontal and role == Qt.DisplayRole:
            header = self.invisibleRootItem[section]
            return self.invisibleRootItem[section]
        return QVariant()

    def index(self, row, column, parent):
        item = self.indexItem(parent)
        child = item.child(row)
        if child:
            return self.createIndex(row, column, child)
        return QModelIndex()

    def parent(self, index):
        if not index.isValid():
            return QModelIndex()
        parent = index.internalPointer().parent
        if parent is self.invisibleRootItem:
            return QModelIndex()
        return self.createIndex(parent.row(), 0, parent)

    def rowCount(self, index):
        if index.column() > 0:
            return 0
        return self.indexItem(index).childCount()



class MiniDict(QObject):
    def __init__(self):
        QObject.__init__(self)
        self.data = {}

    def __contains__(self, item):
        return item in self.data

    def __getitem__(self, name):
        return self.data[name]

    def __setitem__(self, name, value):
        self.data[name] = value

    def keys(self):
        return self.data.keys()

    def items(self):
        return self.data.items()

    def setdefault(self, key, default):
        return self.data.setdefault(key, default)
