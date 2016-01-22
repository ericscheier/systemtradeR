#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from time import ctime

from PyQt4.QtCore import Qt, QVariant, pyqtSignature
from PyQt4.QtGui import (QBrush, QColor, QColorDialog, QIcon, QFrame,
                         QSortFilterProxyModel, QTableWidgetItem, )

from ib.opt.message import messageTypeNames

from profit.lib import BasicHandler, Slots, defaults
from profit.lib.gui import colorIcon
from profit.models.messages import MessagesTableModel
from profit.workbench.widgets.ui_messagedisplay import Ui_MessageDisplay


class MessagesFilter(QSortFilterProxyModel):
    """ MessagesFilter -> proxy model for filtering a message model by types

    """
    def __init__(self, messages, parent=None):
        """ Initializer.

        @param messages sequence of broker messages
        @param parent ancestor object
        """
        QSortFilterProxyModel.__init__(self, parent)
        self.messages = messages
        self.acceptTypes = None

    def filterAcceptsRow(self, row, parent):
        """ Framework hook to filter rows.

        @param row source model row number
        @param parent QModelIndex instance
        @return True if row should be included in view
        """
        baseClass = QSortFilterProxyModel
        baseAccepts = baseClass.filterAcceptsRow(self, row, parent)
        acceptTypes = self.acceptTypes
        if acceptTypes is None:
            return baseAccepts
        message = self.messages[row]
        return message.typeName in acceptTypes and baseAccepts

    def includeAll(self):
        """ Sets filter to accept all message types.

        """
        self.acceptTypes = None
        self.reset()

    def includeTypes(self, *names):
        """ Sets filter to include specified message types.

        """
        if self.acceptTypes is None:
            self.acceptTypes = []
        for name in names:
            if name not in self.acceptTypes:
                self.acceptTypes.append(name)
        self.reset()

    def excludeAll(self):
        """ Sets filter to reject all message types.

        """
        self.acceptTypes = []
        self.reset()

    def excludeTypes(self, *names):
        """ Sets filter to reject specified message types.

        """
        if self.acceptTypes is None:
            self.acceptTypes = []
        for name in names:
            if name in self.acceptTypes:
                self.acceptTypes.remove(name)
        self.reset()


class MessageDisplay(QFrame, Ui_MessageDisplay, BasicHandler):
    """ MessageDisplay -> table view of session messages with nifty controls

    """
    filterModel = None

    def __init__(self, parent=None):
        """ Initializer.

        @param parent ancestor of this widget
        """
        QFrame.__init__(self, parent)
        self.setupUi(self)
        self.setupWidgets()
        self.setupColors()
        self.requestSession()

    def setupWidgets(self):
        """ Configures our widgets like we like.

        """
        settings = self.settings
        settings.beginGroup(settings.keys.messages)
        self.splitter.restoreState(defaults.rightSplitterState())
        messageDetail = self.messageDetail
        messageDetail.verticalHeader().hide()
        horizHeader = messageDetail.horizontalHeader()
        horizHeader.setResizeMode(horizHeader.Stretch)
        messageTable = self.messageTable
        messageTable.verticalHeader().hide()
        horizHeader = messageTable.horizontalHeader()
        horizHeader.setResizeMode(horizHeader.ResizeToContents)
        for widget in (self.messageTypeDisplay.typesListText,
                       self.messageTypeDisplay.allCheck):
            widget.setText('Display ' + widget.text())

    def setupColors(self):
        """ Configures the colors and icons of the message type items.

        """
        getValue = self.settings.value
        defaultColor = QColor(0,0,0)
        brushItems = [(name, getValue('%s/color' % name, defaultColor))
                      for name in messageTypeNames()]
        self.brushMap = brushMap = dict(brushItems)
        items = self.messageTypeDisplay.listItems()
        for item in items:
            color = QColor(brushMap[str(item.text())])
            item.setData(Qt.DecorationRole, QVariant(color))
            item.setIcon(colorIcon(color))

    def setSession(self, session):
        """ Configures this instance for a session.

        @param session Session instance
        """
        self.session = session
        self.messagesModel = MessagesTableModel(session, self.brushMap, self)
        self.filterModel = MessagesFilter(session.messagesBare, self)
        sortCol = self.messagesModel.columnTitles.index('Fields')
        self.filterModel.setFilterKeyColumn(sortCol)
        self.filterModel.setSourceModel(self.messagesModel)
        self.messageTable.setModel(self.filterModel)

    @pyqtSignature('int')
    def on_allCheck_stateChanged(self, state):
        """ Updates the filter model with all types or those checked.

        @param state 0 if unchecked, 1 if checked
        @return None
        """
        model = self.filterModel
        if state:
            model.includeAll()
        else:
            model.excludeAll()
            model.includeTypes(*self.messageTypeDisplay.selectedTypes())

    @pyqtSignature('')
    def on_checkAllButton_clicked(self):
        """ Updates the filter model to include all message types.

        """
        self.filterModel.includeAll()

    @pyqtSignature('')
    def on_checkNoneButton_clicked(self):
        """ Updates the filter model to exclude all message types.

        """
        self.filterModel.excludeAll()

    def on_filterEdit_editingFinished(self):
        """ Sets filter when the user presses enter in the filter line edit.

        """
        self.filterModel.setFilterWildcard(self.filterBar.filterEdit.text())

    def on_messageTable_clicked(self, index):
        """ Displays the message keys and values.

        @param index QModelIndex instance; filterModel index, not messageModel.
        @return None
        """
        firstIndex = index.sibling(index.row(), 0)
        messageIndex, validIndex = firstIndex.data().toInt()
        messageTime, message = self.messagesModel.message(messageIndex)
        messageDetail = self.messageDetail
        messageDetail.clearContents()
        typeName = message.typeName
        itemBrush = QBrush(self.brushMap[typeName])
        items = [
            ('index', messageIndex),
            ('type', typeName),
            ('received', ctime(messageTime))
        ] + list(sorted(message.items()))
        messageDetail.setRowCount(len(items))
        for row, pair in enumerate(items):
            for col, text in enumerate(pair):
                item = QTableWidgetItem(str(text))
                item.setForeground(itemBrush)
                messageDetail.setItem(row, col, item)

    def on_syncSource_stateChanged(self, state):
        """ Turns model updates on or off and enables filter bar to match.

        """
        state = bool(state)
        self.messagesModel.setSync(state)
        if state:
            self.filterBar.filterEdit.setText('')
            self.on_filterEdit_editingFinished()
        self.filterBar.setDisabled(state)

    def on_typesList_itemChanged(self, item):
        """ Updates the filter model by including or excluding a type.

        """
        model = self.filterModel
        if model is None:
            return
        call = model.includeTypes if item.checkState() else model.excludeTypes
        call(str(item.text()))

    def on_typesList_itemDoubleClicked(self, item):
        """ Displays a dialog for selecting the color of a message type.

        If the user selects a new color, we update the type list icon
        and color, the message table foreground, and possibly the
        message detail foreground.
        """
        currentColor = QColor(item.data(Qt.DecorationRole))
        newColor = QColorDialog.getColor(currentColor, self)
        if newColor.isValid():
            item.setData(Qt.DecorationRole, QVariant(newColor))
            item.setIcon(colorIcon(newColor))
            self.brushMap[str(item.text())] = itemBrush = QBrush(newColor)
            self.messagesModel.reset()
            self.settings.setValue('%s/color' % item.text(), newColor)
            messageDetail = self.messageDetail
            typeItem = messageDetail.item(1, 1) # yuk
            if typeItem.text() == item.text():
                for row in range(messageDetail.rowCount()):
                    for col in range(messageDetail.columnCount()):
                        item = messageDetail.item(row, col)
                        item.setForeground(itemBrush)
