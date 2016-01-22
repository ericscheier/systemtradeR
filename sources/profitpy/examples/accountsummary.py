#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from PyQt4.QtCore import QVariant, Qt, pyqtSignature
from PyQt4.QtGui import QItemDelegate, QStandardItem, QStandardItemModel
from PyQt4.QtGui import QApplication, QFrame, QLCDNumber

from profit.lib import Settings, Signals
from profit.lib.gui import ValueColorItem

from .ui_accountsummary import Ui_AccountSummary
from .accountkeysdialog import AccountKeysDialog


class LCD(QLCDNumber, ValueColorItem):
    """ An LCD widget that adjusts its colors as values are set.

    """
    def __init__(self, parent=None):
        """ Construtor.

        @param parent ancestor object
        """
        QLCDNumber.__init__(self, parent)
        self.value = None
        self.setFrameStyle(self.NoFrame)
        self.setNumDigits(10)
        self.setSmallDecimalPoint(True)
        self.setSegmentStyle(self.Flat)

    def display(self, value, format='%.2f'):
        """ Sets display value for this instance.

        @param value new contents of display
        @return None
        """
        display = QLCDNumber.display
        try:
            value = float(value)
        except (ValueError, ):
            return display(self, str(value))
        current = self.value
        if current is None:
            self.value = value
            return display(self, format % value)
        brush = None
        self.value = value
        if value < current:
            brush = self.decrease
        elif value > current:
            brush = self.increase
        elif not value:
            brush = self.neutral
        if brush:
            palette = self.palette()
            palette.setBrush(palette.Active, palette.Text, brush)
            palette.setBrush(palette.Inactive, palette.Text, brush)
        return display(self, format % value)


class AccountSummaryItemDelegate(QItemDelegate):
    """ Delegate type that creates LCD displays for indicated columns.

    """
    def __init__(self, columns=(), parent=None):
        """ Construtor.

        @param columns sequence of column numbers for LCD widgets
        @param parent ancestor object
        """
        QItemDelegate.__init__(self, parent)
        self.columns = columns

    def createEditor(self, parent, option, index):
        """ Framework hook to construct an editor for the specified item.

        @param parent parent of new editor
        @param option QStyleOptionViewItem instance; ignored
        @param index QModelIndex instance of the item for the editor widget
        @return LCD instance if index column is in instances columns sequence
        """
        if index.column() in self.columns:
            return LCD(parent)

    def setEditorData(self, lcd, index):
        """ Framework hook to update an editor.

        @param lcd LCD instance
        @param index QModelIndex instance of the item with LCD
        @return None
        """
        value, okay = index.model().data(index, Qt.DisplayRole).toDouble()
        if okay:
            lcd.display(value)

    def paint(self, painter, option, index):
        """ Framework hook to paint an editor.

        @param painter QPainter instance
        @param option QStyleOptionViewItem instance
        @param index QModelIndex instance of the item for the editor widget
        @return None
        """
        if index.column() not in self.columns:
            return QItemDelegate.paint(self, painter, option, index)


class AccountSummaryModel(QStandardItemModel):
    """ Data model that tracks account keys and their values.

    """
    def __init__(self, displayItems=None, parent=None):
        """ Construtor.

        @param displayItems mapping of display (key, currency) keys to items
        @param parent ancestor object
        """
        QStandardItemModel.__init__(self, parent)
        self.displayItems = displayItems if displayItems is not None else {}
        self.valueCache = {}
        self.setHorizontalHeaderLabels(['Item', 'Currency', 'Value'])
        if parent:
            self.connect(parent.window(), Signals.session.created,
                         self.setSession)

    def setAccountKeyDisplay(self, key, currency, show, view):
        """ Enable or disable display of specified account key.

        @param key account key as string
        @param currency associated currency
        @param show if True, item is displayed, otherwise item is hidden
        @param view view widget instance; required to open LCD delegates
        @return None
        """
        displayKey = (key, currency)
        keys = self.displayItems
        if (show and displayKey not in keys) or \
               (show and keys[displayKey] is None):
            lcd = QStandardItem(self.valueCache.get(displayKey, 0))
            self.appendRow([QStandardItem(key), QStandardItem(currency), lcd])
            view.openPersistentEditor(self.index(lcd.row(), 2))
            keys[displayKey] = lcd
        elif (not show and displayKey in keys) and \
                 (keys[displayKey] is not None):
            item = keys[displayKey]
            self.removeRow(item.index().row())
            keys[displayKey] = None

    def setSession(self, session):
        """ Slot called when session object is created.

        @param session instance of Sessino
        @return None
        """
        session.registerMeta(self)

    def on_session_UpdateAccountValue(self, message):
        """ Slot called when UpdateAccountValue messages are emitted.

        @param message instance of UpdateAccountValue
        @return None
        """
        displayKey = message.key, message.currency
        self.valueCache[displayKey] = value = message.value
        try:
            item = self.displayItems[displayKey]
        except (KeyError, ):
            item = self.displayItems[displayKey] = None
        if item is not None:
            index = self.indexFromItem(item)
            if self.setData(index, QVariant(value), Qt.DisplayRole):
                self.emit(Signals.dataChanged, index, index)


class AccountSummary(QFrame, Ui_AccountSummary):
    """ Widget that displays user-selectable account keys and their values.

    """
    settingKey = 'summarySelections'
    defaultKeys = [
        ('CashBalance', 'USD'),
        ('RealizedPnL', 'USD'),
        ('UnrealizedPnL', 'USD')
    ]

    def __init__(self, parent=None):
        """ Construtor.

        @param parent ancestor object
        """
        QFrame.__init__(self, parent)
        self.setupUi(self)
        self.sharedKeys = {}
        self.setupModel()
        self.readSettings()
        self.connect(QApplication.instance(), Signals.lastWindowClosed,
                     self.saveSettings)

    def setupModel(self):
        """ Initializes the data model for the summary view.

        @return None
        """
        view = self.summaryView
        view.verticalHeader().hide()
        self.dataModel = model = AccountSummaryModel(self.sharedKeys, self)
        self.delegate = delegate = AccountSummaryItemDelegate(columns=[2])
        view.setModel(model)
        view.setItemDelegate(delegate)

    def readSettings(self):
        """ Reads selected keys from saved settings.

        @return None
        """
        settings = Settings()
        settings.beginGroup(settings.keys.account)
        keys = settings.value(self.settingKey)
        if keys.isValid():
            keys = [[str(b) for b in a.toStringList()] for a in keys.toList()]
        else:
            keys = self.defaultKeys
        setup = self.dataModel.setAccountKeyDisplay
        for key, currency in keys:
            setup(key, currency, True, self.summaryView)

    @pyqtSignature('')
    def on_selectKeys_clicked(self):
        """ Signal handler for the select button.  Displays the keys dialog.

        @return None
        """
        dlg = AccountKeysDialog(self)
        keys = [(k, v is not None) for k, v in self.sharedKeys.items()]
        dlg.setupKeys(keys)
        if dlg.exec_() == dlg.Accepted:
            view = self.summaryView
            setup = self.dataModel.setAccountKeyDisplay
            for (key, currency), active in dlg.keys():
                setup(key, currency, active, view)

    def saveSettings(self):
        """ Signal handler for last window closing.  Saves selected keys.

        @return None
        """
        settings = Settings()
        settings.beginGroup(settings.keys.account)
        keys = [QVariant([key, currency]) for (key, currency), item in
                    self.sharedKeys.items() if item is not None]
        settings.setValue(self.settingKey, keys)
