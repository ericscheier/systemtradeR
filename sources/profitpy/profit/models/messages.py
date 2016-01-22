#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from time import ctime
from PyQt4.QtCore import Qt, QAbstractTableModel, QModelIndex, QVariant
from profit.lib import Signals


class MessagesTableModel(QAbstractTableModel):
    """ Data model for session messages.

    """
    columnTitles = ['Index', 'Time', 'Type', 'Fields']
    sync = True

    def __init__(self, session, brushes, parent=None):
        """ Constructor.

        @param session Session instance
        @param brushes mapping of typenames to foreground brushes
        @param parent ancestor object
        """
        QAbstractTableModel.__init__(self, parent)
        self.session = session
        self.brushes = brushes
        self.messages = session.messages
        self.messageCount = len(self.messages)
        self.dataExtractors = {
            0 : messageRow,
            1 : messageTime,
            2 : messageName,
            3 : messageText
        }
        session.registerAll(self.on_sessionMessage)

    def index(self, row, column, parent=QModelIndex()):
        msg = self.messages[row]
        idx = self.createIndex(row, column, msg)
        return idx

    def parent(self, index=QModelIndex()):
        return None

    def on_sessionMessage(self, message):
        """ Signal handler for incoming messages.

        @param message message instance
        @return None
        """
        count = self.messageCount
        self.messageCount += 1
        if self.sync:
            self.beginInsertRows(QModelIndex(), count, count)
            self.endInsertRows()

    def data(self, index, role):
        """ Framework hook to determine data stored at index for given role.

        @param index QModelIndex instance
        @param role Qt.DisplayRole flags
        @return QVariant instance
        """
        if not index.isValid():
            return QVariant()
        message = index.internalPointer()
        if role == Qt.ForegroundRole:
            return QVariant(self.brushes[message[1].typeName])
        if role != Qt.DisplayRole:
            return QVariant()
        try:
            val = self.dataExtractors[index.column()](index, message, self)
            val = QVariant(val)
        except (KeyError, ):
            val = QVariant()
        return val

    def headerData(self, section, orientation, role):
        """ Framework hook to determine header data.

        @param section integer specifying header (e.g., column number)
        @param orientation Qt.Orientation value
        @param role Qt.DisplayRole flags
        @return QVariant instance
        """
        if orientation == Qt.Horizontal and role == Qt.DisplayRole:
            return QVariant(self.columnTitles[section])
        return QVariant()

    def rowCount(self, parent=None):
        """ Framework hook to determine data model row count.

        @param parent ignored
        @return number of rows (message count)
        """
        return self.messageCount

    def columnCount(self, parent=None):
        """ Framework hook to determine data model column count.

        @param parent ignored
        @return number of columns (see columnTitles)
        """
        return len(self.columnTitles)

    def setSync(self, sync):
        """

        @param sync if True, model is reset after messages received
        @return None
        """
        self.sync = sync
        if sync:
            self.reset()

    def __insertRows(self, row, count, parent=QModelIndex()):
        self.beginInsertRows(parent, row, row+count-1)
        self.endInsertRows()
        return True

    ## crufty crufty
    def message(self, idx):
        return self.messages[idx]


def messageRow(index, mtuple, model):
    """ Extracts the row number from an index and its message.

    @param index QModelIndex instance
    @param mtuple two-tuple of (message time, message object)
    @return row number as integer
    """
    return model.messages.index(mtuple)


def messageTime(index, (mtime, message), model):
    """ Extracts the message time from an index and its message.

    @param index QModelIndex instance
    @param mtime message time as float
    @param message message instance
    @return mtime formatted with ctime call
    """
    return ctime(mtime)


def messageName(index, (mtime, message), model):
    """ Extracts the type name from an index and its message.

    @param index QModelIndex instance
    @param mtime message time as float
    @param message message instance
    @return type name of message as string
    """
    return message.typeName


def messageText(index, (mtime, message), model):
    """ Extracts the items from an index and its message.

    @param index QModelIndex instance
    @param mtime message time as float
    @param message message instance
    @return message string formatted with message key=value pairs
    """
    return str.join(', ', ['%s=%s' % (k, v) for k, v in message.items()])
