#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

from PyQt4.QtCore import Qt, pyqtSignature
from PyQt4.QtGui import QApplication, QColor, QColorDialog, QDialog
from PyQt4.QtGui import QFileDialog, QFont, QFontDialog, QListWidgetItem

from profit.lib import defaults
from profit.lib import Settings
from profit.lib.gui import colorIcon
from profit.lib.widgets.syspathdialog import SysPathDialog
from profit.workbench.widgets.ui_settingsdialog import Ui_SettingsDialog


def getCheckState(o):
    return o.checkState()

def setCheckState(o, v):
    o.setCheckState(Qt.CheckState(v.toInt()[0]))

def getText(o):
    return o.text()

def setText(o, v):
    o.setText(v.toString())

def getValue(o):
    return o.value()

def setIntValue(o, v):
    o.setValue(v.toInt()[0])

def getFont(o):
    return QFont(o.font())

def setFont(o, v):
    v = QFont(v)
    try:
        name = v.toString().split(',')[0]
    except (IndexError, ):
        name = v.rawName()
    size = v.pointSize()
    bold = 'Bold' if v.bold() else ''
    o.setFont(v)
    o.setText('%s %s %s' % (name, size, bold))

def getColor(o):
    return o.color

def colorSetter(target):
    def setColor(o, v):
        o.color = color = QColor(v)
        o.setIcon(colorIcon(color))
    return setColor

def getList(o):
    return [o.item(r).text() for r in range(o.count())]

def setList(o, v):
    items = [QListWidgetItem(a) for a in v.toStringList()]
    for item in items:
        item.setFlags(Qt.ItemIsSelectable|Qt.ItemIsEditable|Qt.ItemIsEnabled)
        o.addItem(item)

schema = {}

schema[Settings.keys.main] = [
    ('confirmActivateStrategy', getCheckState, setCheckState, Qt.Checked),
    ('confirmCloseWhenModified', getCheckState, setCheckState, Qt.Checked),
    ('confirmCloseWhenConnected', getCheckState, setCheckState, Qt.Checked),
    ('useSystemTrayIcon', getCheckState, setCheckState, Qt.Checked),
    ('externalEditor', getText, setText, ''),
    ('useSystemBrowser', getCheckState, setCheckState, Qt.Unchecked),
]

schema[Settings.keys.appearance] = [
    ('shellFont', getFont, setFont, 'Monospace'),
    ('increaseColor', getColor, colorSetter('increaseColor'), QColor(Qt.darkGreen)),
    ('neutralColor', getColor, colorSetter('neutralColor'), QColor(Qt.blue)),
    ('decreaseColor', getColor, colorSetter('decreaseColor'), QColor(Qt.red)),
]

schema[Settings.keys.urls] = [
    ('tickerUrls', getList, setList, defaults.tickerUrls()),
]


def sysPathSelectMethod(target):
    @pyqtSignature('')
    def selector(self):
        dlg = SysPathDialog(self)
        if dlg.exec_() == dlg.Accepted:
            widget = getattr(self, target)
            widget.setText(dlg.selectedEdit.text())
    return selector


def colorValueSelectMethod(target):
    @pyqtSignature('')
    def selector(self):
        widget = getattr(self, target)
        color = QColorDialog.getColor(widget.color, self)
        if color.isValid():
            widget.color = color
            widget.setIcon(colorIcon(color))
    return selector


class SettingsDialog(QDialog, Ui_SettingsDialog):
    def __init__(self, parent=None):
        QDialog.__init__(self, parent)
        self.setupUi(self)

    def readSettings(self, settings):
        for key, lookups in schema.items():
            settings.beginGroup(key)
            for name, getr, setr, default in lookups:
                value = settings.value(name, default)
                obj = getattr(self, name)
                setr(obj, value)
            settings.endGroup()

    def writeSettings(self, settings):
        for key, lookups in schema.items():
            settings.beginGroup(key)
            for name, getr, setr, default in lookups:
                obj = getattr(self, name)
                value = getr(obj)
                settings.setValue(name, value)
            settings.endGroup()

    on_increaseColor_clicked = colorValueSelectMethod('increaseColor')
    on_neutralColor_clicked = colorValueSelectMethod('neutralColor')
    on_decreaseColor_clicked = colorValueSelectMethod('decreaseColor')

    @pyqtSignature('')
    def on_selectShellFont_clicked(self):
        default = QFont(self.shellFont.font())
        font, okay = QFontDialog.getFont(default, self, 'Select Shell Font')
        if okay:
            setFont(self.shellFont, font)

    @pyqtSignature('')
    def on_selectExternalEditor_clicked(self):
        filename = QFileDialog.getOpenFileName(
            self, 'Select External Editor', '', 'Any File (*)')
        if filename:
            self.externalEditor.setText(filename)

    @pyqtSignature('')
    def on_tickerUrls_itemSelectionChanged(self):
        widget = self.tickerUrls
        try:
            row = widget.row(widget.selectedItems()[0])
        except (IndexError, ):
            row = 0
        count = widget.count()
        self.tickerUrlUp.setEnabled(count and row and row <= count)
        self.tickerUrlDown.setEnabled(count and row < count-1)
        self.tickerUrlRemove.setEnabled(count > 0)
        self.tickerUrlAdd.setEnabled(True)

    @pyqtSignature('')
    def on_tickerUrlRemove_clicked(self):
        widget = self.tickerUrls
        widget.takeItem(self.tickerUrls.currentRow())
        self.tickerUrlRemove.setEnabled(widget.count() > 0)

    @pyqtSignature('')
    def on_tickerUrlAdd_clicked(self):
        widget = self.tickerUrls
        item = QListWidgetItem('Item Title:http://example.com/page?id=$symbol')
        item.setFlags(Qt.ItemIsSelectable|Qt.ItemIsEditable|Qt.ItemIsEnabled)
        widget.insertItem(widget.currentRow()+1, item)

    @pyqtSignature('')
    def on_tickerUrlUp_clicked(self):
        self.moveTickerUrl(-1)

    @pyqtSignature('')
    def on_tickerUrlDown_clicked(self):
        self.moveTickerUrl(1)

    def moveTickerUrl(self, offset):
        widget = self.tickerUrls
        item = widget.currentItem()
        other = widget.item(widget.currentRow()+offset)
        itemtext, othertext = item.text(), other.text()
        item.setText(othertext)
        other.setText(itemtext)
        selmodel = widget.selectionModel()
        selmodel.clear()
        selmodel.setCurrentIndex(widget.indexFromItem(other), selmodel.Select)

    def accept(self):
        self.writeSettings(Settings())
        QDialog.accept(self)


if __name__ == '__main__':
    app = QApplication([])
    win = SettingsDialog()
    win.readSettings(Settings())
    win.exec_()


