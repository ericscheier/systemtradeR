#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

import sys

from itertools import groupby
from os import listdir
from os.path import basename, isdir, join, split, splitext
from pyclbr import Class, Function, readmodule_ex, _modules as clbrcache

from PyQt4.QtCore import QVariant, Qt
from PyQt4.QtGui import QApplication, QDialog, QIcon
from PyQt4.QtGui import QStandardItem, QStandardItemModel

from profit.lib.widgets import profit_rc
from profit.lib.widgets.ui_syspathdialog import Ui_SysPathDialog


pyexts = set(['.py', '.pyc', '.pyo'])
pyinits = set(['__init__.py', '__init__.pyc', '__init__.pyo'])


def isSourceDir(item):
    notempty = isdir(item) and listdir(item)
    if notempty:
        items = [join(item, p) for p in listdir(item)]
        items = [p for p in items if isdir(p) or splitext(p)[1] in pyexts]
    else:
        items = None
    return bool(items)


def isPackage(item):
    return isdir(item) and (set(listdir(item)) & pyinits)


def isSource(item):
    return splitext(item)[1] in pyexts


def readModule(filename, *paths):
    try:
        contents = readmodule_ex(filename, path=list(paths))
        contents = contents.copy()
    except (ImportError, ):
        contents = {}
    try:
        del(contents['__path__'])
    except (KeyError, ):
        pass
    return contents


class SysPathItem(QStandardItem):
    def __init__(self, path, display, contents=None):
        QStandardItem.__init__(self, display)
        self.setEditable(False)
        self.setData(QVariant(path))
        self.path = path
        self.isClass = isinstance(contents, Class)
        self.isFunction = isinstance(contents, Function)
        self.setIcon(self.selectIcon())

    def selectIcon(self):
        if self.isClass:
            icon = QIcon(':images/icons/package_system.png')
        elif self.isFunction:
            icon = QIcon(':images/icons/misc.png')
        elif splitext(self.path)[1] in pyexts:
            icon = QIcon(':images/icons/source_py.png')
        else:
            style = QApplication.style()
            icon = style.standardIcon(style.SP_DirIcon)
        return icon


class SysPathModel(QStandardItemModel):
    def __init__(self, parent=None):
        QStandardItemModel.__init__(self, parent)
        for row in [SysPathItem(p, p) for p in sys.path if isSourceDir(p)]:
            self.appendRow(row)

    def hasChildren(self, index):
        QApplication.setOverrideCursor(Qt.WaitCursor)
        if index.isValid():
            item = self.itemFromIndex(index)
            path = item.path
            if item.hasChildren():
                children = True
            elif item.isClass or item.isFunction:
                children = False
            elif isdir(path):
                paths = [join(path, p) for p in listdir(path)]
                paths = [p for p in paths if isPackage(p) or isSource(p)]
                paths.sort()
                for key, subiter in groupby(paths, lambda x:splitext(x)[0]):
                    pth = sorted(subiter)[0]
                    item.appendRow(SysPathItem(pth, split(pth)[1]))
                children = bool(paths)
            elif splitext(path)[1] in pyexts:
                contents = readModule(self.dottedName(item), split(path)[0])
                for name, obj in sorted(contents.items()):
                    item.appendRow(SysPathItem(path, name, obj))
                children = bool(contents)
            else:
                children = False
        else:
            children = True
        QApplication.restoreOverrideCursor()
        return children

    def dottedName(self, item):
        path = []
        while item:
            txt = str(item.text())
            name, ext = splitext(txt)
            if ext in pyexts:
                txt = name
            if txt != '__init__':
                path.insert(0, txt)
            item = item.parent()
        return str.join('.', path[1:])


class SysPathDialog(QDialog, Ui_SysPathDialog):
    def __init__(self, parent=None):
        QDialog.__init__(self, parent)
        self.setupUi(self)
        self.treeView.header().hide()
        self.dataModel = SysPathModel(self)
        self.treeView.setModel(self.dataModel)

    def on_treeView_clicked(self, index):
        item = self.dataModel.itemFromIndex(index)
        self.selectedEdit.setText(self.dataModel.dottedName(item))


if __name__ == '__main__':
    app = QApplication(sys.argv)
    win = SysPathDialog()
    win.show()
    sys.exit(app.exec_())
