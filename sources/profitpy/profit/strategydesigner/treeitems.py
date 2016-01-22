#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from PyQt4.QtCore import QVariant, Qt, pyqtSignature
from PyQt4.QtGui import (
    QApplication, QBrush, QColor, QIcon, QPixmap, QStandardItem)

from profit.strategy import schema


defaultName = 'Unknown'


class SchemaItem(QStandardItem):
    """ Base class for schema tree items.

    """
    def __init__(self, text=defaultName):
        """ Constructor.

        @param text string value for item
        """
        QStandardItem.__init__(self, text)
        self.setEditable(False)
        self.cutSource = False
        self.copySource = False

    def canPaste(self, typeobj):
        try:
            return self.allowChildType(typeobj.__bases__[1])
        except (AttributeError, IndexError, ):
            return False

    def children(self, descend=False):
        """ Yields each immediate child of this item, optionally all children

        """
        for r in range(self.rowCount()):
            child = self.child(r, 0)
            yield child
            if descend:
                for c in child.children(True):
                    yield c

    def clone(self):
        return self.fromSchema(self.toSchema())

    def resetForeground(self):
        """ Sets the foreground brush for this item to the original.

        This implementation uses the palette from the active window,
        which produces the desired result.  There might be an easier
        way, but using the default foreground brush from the item did
        not work (default foreground brush is black).

        @return None
        """
        self.setForeground(QApplication.activeWindow().palette().text())

    def setCopy(self):
        """ Called to indicate this instance is copied.

        @return None
        """
        self.copySource = True
        self.cutSource = False
        self.setForeground(QBrush(QColor(Qt.blue)))

    def setCut(self):
        """ Called to indicate this instance is cut.

        @return None
        """
        self.cutSource = True
        self.copySource = False
        self.setForeground(QBrush(QColor(Qt.red)))

    def siblings(self):
        """ Yields each sibling of this item.

        """
        parent = self.parent()
        for row in range(parent.rowCount()):
            child = parent.child(row, 0)
            if child is not self:
                yield child

    def root(self):
        """ Returns the top-most parent of this item.

        """
        item = self
        while True:
            if item.parent():
                item = item.parent()
            else:
                break
        return item

    @classmethod
    def fromSchema(cls, data={}):
        """ Creates a tree item given a schema.

        @param data schema dictionary
        @return tree item instance
        """
        instance = cls(data.get('name', defaultName))
        for attr, default in cls.attrs.items():
            if isinstance(default, (tuple, list)):
                default = default[:]
            elif isinstance(default, (dict, set)):
                default = default.copy()
            setattr(instance, attr, data.get(attr, default))
        for child in data.get('children', []):
            instance.appendRow(cls.childType(data).fromSchema(child))
        return instance

    def toSchema(self):
        """ Generated schema dictionary for this item.

        @return schema as a dictionary
        """
        mapping = dict([(attr, getattr(self, attr, default))
                        for attr, default in self.attrs.items()])
        mapping['children'] = [c.toSchema() for c in self.children()]
        mapping['name'] = str(self.text())
        mapping['type'] = str(self.__class__.__name__)
        return mapping


class RunnerItem(SchemaItem, schema.Runner):
    @classmethod
    def childType(cls, data):
        return CallableItem


class CallableItem(SchemaItem, schema.Callable):
    @classmethod
    def childType(cls, data):
        return CallableItem


class TickerItem(SchemaItem, schema.Ticker):
    @classmethod
    def childType(cls, data):
        return FieldItem

    def loadIcon(self, settings):
        """ Load and set an icon appropriate for this item.

        @param settings QSettings instance
        @return None
        """
        name = self.symbol.lower()
        icon = settings.value('%s/icon' % name)
        if icon.isValid():
            icon = QIcon(icon)
        else:
            path = ':images/tickers/%s.png' % name
            if QPixmap(path).isNull():
                icon = QIcon(':images/icons/mime_empty.png')
            else:
                icon = QIcon(path)
        self.setIcon(icon)


class FieldItem(SchemaItem, schema.TickerField):
    """ Child item type for TickerItems.

    FieldItems store a ticker data field that corresponds to the data
    field of incoming market data.
    """
    @classmethod
    def childType(cls, data):
        return IndexItem


class IndexItem(SchemaItem, schema.TickerFieldIndex):
    @classmethod
    def childType(cls, data):
        return IndexItem
