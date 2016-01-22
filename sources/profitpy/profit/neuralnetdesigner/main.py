#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2008 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

from functools import partial

from profit.lib.breadfan import make_network
from profit.lib import Signals, Slots

from profit.lib.widgets.dock import Dock
from profit.lib.widgets.shell import PythonShell
from profit.lib.widgets.output import OutputWidget

from profit.lib.widgets.breadfan_network import NetworkControlFrame
from profit.lib.widgets.breadfan_train import BreadFanTrainTree
from profit.lib.widgets.breadfan_test import BreadFanTestTree

from PyQt4 import QtGui
from PyQt4.QtCore import QUrl, QVariant, Qt, pyqtSignature, SIGNAL, SLOT
from PyQt4.QtGui import QAction, QApplication, QColor, QMainWindow
from PyQt4.QtGui import QFileDialog, QMessageBox, QProgressDialog, QMenu
from PyQt4.QtGui import QSystemTrayIcon, QToolBar
from PyQt4.QtGui import QIcon, QDesktopServices


from ui_breadfan_main import Ui_BreadFanMain




class BreadFanMain(QMainWindow, Ui_BreadFanMain):
    def __init__(self):
        QMainWindow.__init__(self)
        self.setupUi(self)
        self.setupDockWidgets()
        self.setupMenus()
        self.net = make_network()

    def setupMenus(self):
        addr = self.menuView.addAction
        for o in self.findChildren(Dock):
            addr(o.toggleViewAction())
        self.menuView.addSeparator()
        addr(self.actionStatusBar)
        self.menuView.addMenu(self.menuToolbars)
        for toolbar in self.findChildren(QToolBar):
            self.menuToolbars.addAction(toolbar.toggleViewAction())

    @pyqtSignature('')
    def on_actionNew_triggered(self):
        print 'new file'

    @pyqtSignature('')
    def on_actionOpen_triggered(self):
        print 'open file'

    @pyqtSignature('')
    def on_actionSave_triggered(self):
        print 'save file'

    @pyqtSignature('')
    def on_actionSaveAs_triggered(self):
        print 'save as file'

    @pyqtSignature('')
    def on_actionClose_triggered(self):
        print 'close file'

    @pyqtSignature('')
    def on_actionImport_triggered(self):
        filename = QFileDialog.getOpenFileName(
            self, 'Import Network', '')
        if filename:
            self.net.load(filename)
            self.emit(Signals.neuralNetworkCreated, self.net)

    @pyqtSignature('')
    def on_actionExport_triggered(self):
        print 'export'
        if not self.net:
            print 'no network to export'
            return
        filename = QFileDialog.getOpenFileName(
            self, 'Export Network', '')
        if filename:
            self.net.save(filename)


    def setupDockWidgets(self):
        bottom = Qt.BottomDockWidgetArea
        tabify = self.tabifyDockWidget

        self.networkDock = networkDock = Dock('Network Setup', self, NetworkControlFrame)
        self.trainDock = trainDock = Dock('Train Network', self, BreadFanTrainTree)
        self.testDock = testDock = Dock('Test Network', self, BreadFanTestTree)

        trainDock.widget().setupBasic(self, Signals.neuralNetworkCreated)

        tabify(networkDock, trainDock, )
        tabify(trainDock, testDock)

        self.stdoutDock = outDock = Dock('Standard Output', self, OutputWidget, bottom)
        self.stderrDock = errDock = Dock('Standard Error', self, OutputWidget, bottom)

        makeShell = partial(PythonShell, stdout=outDock.widget(),
                            stderr=errDock.widget())
        self.shellDock = shellDock = Dock('Python Shell', self, makeShell, bottom)
        tabify(shellDock, outDock)
        tabify(outDock, errDock)

        shellDock.raise_()
        networkDock.raise_()


if __name__ == "__main__":
    import sys
    app = QtGui.QApplication(sys.argv)
    win = BreadFanMain()
    win.show()
    sys.exit(app.exec_())
