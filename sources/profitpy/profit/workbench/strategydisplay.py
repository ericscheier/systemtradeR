#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

from PyQt4.QtCore import (Qt, QModelIndex, QVariant, pyqtSignature,
                          QAbstractTableModel, )

from PyQt4.QtGui import (QFrame, QIcon, QMessageBox, QPushButton,
                         QItemDelegate, QStandardItem,
                         QFileDialog, )

from profit.lib import defaults, logging
from profit.lib import BasicHandler, Signals, DataRoles, instance
from profit.lib.gui import StandardItem
from profit.workbench.widgets.ui_strategydisplay import Ui_StrategyDisplay


class StrategyDisplay(QFrame, Ui_StrategyDisplay, BasicHandler):
    """ StrategyDisplay -> a nice panel to manage strategies.

    """
    confirmActivateKey = 'confirmActivate'

    def __init__(self, parent=None):
        """ Initializer.

        @param parent ancestor of this object
        """
        QFrame.__init__(self, parent)
        self.setupUi(self)
        self.setupWidgets()
        self.requestSession()

    def setupWidgets(self):
        self.inactiveIcon = QIcon(':/images/icons/connect_no.png')
        self.activeIcon = QIcon(':/images/icons/connect_established.png')
        settings = self.settings
        settings.beginGroup(settings.keys.strategy)
        confirm = settings.value(self.confirmActivateKey, True)
        confirmActivate = Qt.Checked if confirm.toBool() else Qt.Unchecked
        self.confirmActivate.setCheckState(confirmActivate)
        settings.endGroup()


    def on_strategyView_selectionChanged(self, selected, deselected):
        loaded = any(i.internalPointer().data[0] or
                     i.internalPointer().data[1]
                     for i in selected.indexes())
        self.editButton.setEnabled(not loaded)
        self.removeButton.setEnabled(not loaded)

    def setSession(self, session):
        self.session = session
        model = session.models.strategy
        model.iconMap = {False:self.inactiveIcon, True:self.activeIcon}
        self.strategyView.setModel(model)
        ## this has to happen after the model is set, not during init.
        connect = self.connect
        connect(self.strategyView.selectionModel(),
                Signals.selectionChanged,
                self.on_strategyView_selectionChanged)
#        connect(self, Signals.strategy.requestActivate,
#                instance(), Signals.strategy.requestActivate)


    def __on_strategyView_doubleClicked(self, index):
        """

        """
        if (not index.isValid()) or (index.column() != 2):
            return
        row = index.internalPointer().data
        if not (row[0] or row[1]):
            self.editButton.click()

    def __on_strategyView_clicked(self, index):
        if not index.isValid():
            active = False
        else:
            row = index.internalPointer().data
            active = row[0] or row[1]
        self.editButton.setEnabled(not active)
        self.removeButton.setEnabled(not active)

    def __on_strategyTable_itemChanged(self, item):
        """

        """
        if item.column() == 0:
            checked = item.checkState()
            if checked and self.confirmActivate.isChecked():
                button = QMessageBox.warning(self, 'Confirm',
                         'Confirm activate strategy.',
                          QMessageBox.Yes|QMessageBox.No)
                if button == QMessageBox.No:
                    ## this causes a single indirect recursion.
                    item.setCheckState(Qt.Unchecked)
                    return
            ## emit the signal for all activate/deactivate changes
            rowdict = self.strategyModel.rowToDict(item.row())
            self.emit(Signals.strategy.requestActivate, rowdict, bool(checked))
            ## house keeping common for all activate/deactivate
            other = self.strategyModel.item(item.row(), 1)
            other.setIcon(self.activeIcon if checked else self.inactiveIcon)
            other.setText('active' if checked else 'inactive')
            labels = self.strategyModel.labels
            for col in [labels.index('Status'), labels.index('File'), ]:
                self.strategyModel.item(item.row(), col).setEnabled(checked)
            self.editButton.setEnabled(not checked)
            self.removeButton.setEnabled(not checked)

    @pyqtSignature('bool')
    def on_enableAll_clicked(self, checked):
        if checked:
            if self.confirmActivate.isChecked():
                button = QMessageBox.warning(self, 'Confirm',
                                             'Confirm activate strategy manager.',
                                             QMessageBox.Yes|QMessageBox.No)
                if button == QMessageBox.No:
                    ## again, this causes a single indirect recursion
                    self.enableAll.setChecked(Qt.Unchecked)
                    return
            ## emit enable-all signal
            pass
        else:
            ## emit disable-all signal
            pass

    @pyqtSignature('bool')
    def on_confirmActivate_clicked(self, v):
        settings = self.settings
        settings.beginGroup(settings.keys.strategy)
        settings.setValue(self.confirmActivateKey, v)
        settings.endGroup()

    @pyqtSignature('')
    def on_editButton_clicked(self):
        """

        """
        from profit.strategydesigner.main import StrategyDesigner
        indexes = self.strategyView.selectedIndexes()
        try:
            index = [i for i in indexes if i.isValid()][0]
        except (IndexError, ):
            pass
        else:
            item = index.internalPointer()
            filename = item[item.filenameIdx]
            win = StrategyDesigner(filename=filename, parent=self)
            win.show()

    @pyqtSignature('')
    def on_loadButton_clicked(self):
        """

        """
        fn = QFileDialog.getOpenFileName(self, 'Select Strategy File', '')
        if fn:
            view = self.strategyView
            view.model().appendRowFromData(filename=fn)
            ##self.saveSettings()

    @pyqtSignature('')
    def on_removeButton_clicked(self):
        """

        """
        view = self.strategyView
        model = view.model()
        indexes = view.selectedIndexes()
        rows = set(i.row() for i in indexes if i.isValid())
        for row in reversed(sorted(list(rows))):
            model.removeRow(row)
        view.clearSelection()
        self.editButton.setEnabled(False)
        self.removeButton.setEnabled(False)
#        self.saveSettings()

    def readSettings(self):
        """ Load saved strategies and send them to the model.

        """
        settings = self.settings
        settings.beginGroup(settings.keys.strategy)
        model = self.strategyModel
        for row in model.decodeRows(settings.valueLoad('strategies', [])):
            model.appendRow(row)
        settings.endGroup()

    def saveSettings(self):
        """

        """
        settings = self.settings
        settings.beginGroup(settings.keys.strategy)
        settings.setValueDump('strategies', self.strategyModel.encodeRows())
        settings.endGroup()


class StrategyDisplayModel:
    """ Model for strategy display table.

    This model doesn't make any attempt to identify a strategy by a
    unique key.  The user can add the same strategy file multiple
    times via a view, yet this class only distinguishes by
    (transitory) row numbers.
    """
    labels = ['Active', 'Status', 'File', ]

    def __init__(self, session, view, parent=None):
        QStandardItemModel.__init__(self, parent)
        self.session = session
        self.activeIcon = (view.activeIcon if view else QIcon())
        self.inactiveIcon = (view.inactiveIcon if view else QIcon())
        self.setHorizontalHeaderLabels(self.labels)

    def appendRowFromData(self, **kwds):
        """ Create and append row based on model data and method parameters.

        """
        items = self.makeRowItems(**kwds)
        self.appendRow(items)

    def rowToDict(self, row):
        """

        """
        return {
            'active':self.item(row, 0).checkState(),
            'filename':str(self.item(row, 2).text()),
        }

    def encodeRows(self):
        """ Encode model items as dictionaries.

        """
        return [self.rowToDict(i) for i in range(self.rowCount())]

    def decodeRows(self, rows):
        """ Yields a list of items for each row.

        """
        for row in rows:
            yield self.makeRowItems(icon=self.inactiveIcon,
                                    filename=row['filename'])

    def makeRowItems(self, **kwds):
        """

        """
        return [
            StandardItem(checkable=True, checkState=Qt.Unchecked,
                         enabled=True, alignment=Qt.AlignCenter),
            StandardItem('inactive', icon=kwds.get('icon', QIcon())),
            StandardItem(kwds.get('filename', '')),
        ]


