#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

from functools import partial
try:
    from os import P_NOWAIT, getpgrp, killpg, spawnvp
    from signal import SIGQUIT
except (ImportError, ):
    pass
from os import environ
from os.path import abspath, basename
from subprocess import Popen
from sys import argv, executable

from PyQt4.QtCore import QUrl, QVariant, Qt, pyqtSignature
from PyQt4.QtGui import QAction, QApplication, QColor, QMainWindow
from PyQt4.QtGui import QFileDialog, QMessageBox, QProgressDialog, QMenu
from PyQt4.QtGui import QSystemTrayIcon, QToolBar
from PyQt4.QtGui import QIcon, QDesktopServices, QFrame

from profit.lib import defaults
from profit.lib import Signals, Settings, instance
from profit.lib.gui import ValueColorItem, WaitMessageBox, warningBox
from profit.lib.widgets.dock import Dock
from profit.lib.widgets.output import OutputWidget
from profit.lib.widgets.propertyeditor import PropertyEditor
from profit.lib.widgets.shell import PythonShell
from profit.lib.widgets.extendedshell import ExtendedPythonShell
from profit.session import Session

from profit.workbench.widgets.ui_main import Ui_ProfitWorkbenchWindow
from profit.workbench.sessiontree import SessionTree


applicationName = QApplication.applicationName
processEvents = QApplication.processEvents


class ProfitWorkbenchWindow(QMainWindow, Ui_ProfitWorkbenchWindow):
    documentationUrl = \
        'http://code.google.com/p/profitpy/w/list?q=label:Documentation'
    homeUrl = 'http://code.google.com/p/profitpy/'
    ibUrl = 'http://www.interactivebrokers.com/'
    twsUrl = 'http://individuals.interactivebrokers.com/cgi-bin/jtslink.pl'

    iconName = ':images/icons/blockdevice.png'
    maxRecentSessions = 5

    def __init__(self):
        QMainWindow.__init__(self)
        self.setupUi(self)
        self.setupDockWidgets()
        self.setupMenus()
        self.setupMainIcon()
        self.setupRecentSessions()
        self.setupSysTray()
        self.setupColors()
        self.readSettings()
        self.setWindowTitle('%s (0.2 alpha)' % applicationName())
        app = instance()
        sessreq = lambda :app.emit(Signals.session.reference, self.session)
        connect = self.connect
        connect(app, Signals.session.request, sessreq)
        connect(app, Signals.lastWindowClosed, self.writeSettings)
        connect(self, Signals.openUrl, app, Signals.openUrl)
        connect(self, Signals.session.created, app, Signals.session.created)
        connect(self, Signals.settingsChanged, self.setupColors)
        connect(self, Signals.settingsChanged, self.setupSysTray)
        self.createSession()
        if len(argv) > 1:
            self.on_actionOpenSession_triggered(filename=argv[1])

    def checkClose(self):
        check = True
        settings = Settings()
        settings.beginGroup(settings.keys.main)
        confirm = settings.value('confirmCloseWhenModified', QVariant(1))
        confirm = confirm.toInt()[0]
        if self.session.isModified() and confirm:
            buttons = QMessageBox.Save|QMessageBox.Discard|QMessageBox.Cancel
            text = 'This session has been modified'
            if self.session.isConnected():
                text += ' and is connected and receiving messages.'
            else:
                text += '.'
            text += '\n\nDo you want to save your changes?'
            msg = QMessageBox.question(
                self, applicationName(), text, buttons, QMessageBox.Save)
            if msg == QMessageBox.Discard:
                pass
            elif msg == QMessageBox.Cancel:
                check = False
            elif msg == QMessageBox.Save:
                self.actionSaveSession.trigger()
        return check

    def on_inspectWidget(self, checked=False, widget=None):
        objectType, objectName = type(widget), widget.objectName()
        self.propertyEditor.widget().setFromWidget(widget)

    def contextMenuActions(self, event):
        app = instance()
        widget = app.widgetAt(event.globalPos())
        if widget is None:
            return
        inspectCall = partial(self.on_inspectWidget, widget=widget)
        actionText = 'Inspect %s:%s' % (type(widget).__name__, widget.objectName())
        inspectAction = QAction(actionText, self)
        self.connect(inspectAction, Signals.triggered, inspectCall)
        return [inspectAction, ]

    def contextMenuEvent(self, event):
        menu = QMenu()
        actions = self.contextMenuActions(event)
        QMenu.exec_(actions, event.globalPos())
        event.accept()

    def closeEvent(self, event):
        if self.checkClose():
            try:
                self.trayIcon.deleteLater()
            except (AttributeError, ):
                pass
            event.accept()
        else:
            event.ignore()

    def closeProcessGroup(self):
        self.writeSettings()
        try:
            killpg(getpgrp(), SIGQUIT)
        except (NameError, ):
            self.close()

    def createSession(self):
        self.session = session = Session()
        app = instance()
        app.emit(Signals.session.created, session)
        bar = self.statusBar()
        self.connect(session, Signals.session.status, bar.showMessage)

    @pyqtSignature('')
    def on_actionAboutProfitWorkbench_triggered(self):
        from profit.workbench.aboutdialog import AboutDialog
        dlg = AboutDialog(self)
        dlg.exec_()

    @pyqtSignature('')
    def on_actionAboutQt_triggered(self):
        QMessageBox.aboutQt(self, 'About Qt')

    @pyqtSignature('bool')
    def on_actionClearRecentMenu_triggered(self, checked=False):
        for action in self.recentSessionsActions:
            action.setVisible(False)
        settings = Settings()
        settings.beginGroup(settings.keys.main)
        settings.remove('recentSessions')

    @pyqtSignature('')
    def on_actionCloseSession_triggered(self):
        if self.checkClose():
            self.close()

    @pyqtSignature('')
    def on_actionDocumentation_triggered(self):
        self.emit(Signals.openUrl, self.documentationUrl)

    @pyqtSignature('')
    def on_actionProfitPyHome_triggered(self):
        self.emit(Signals.openUrl, self.homeUrl)

    @pyqtSignature('')
    def on_actionIbHome_triggered(self):
        self.emit(Signals.openUrl, self.ibUrl)

    @pyqtSignature('')
    def on_actionBrowserTwsHome_triggered(self):
        self.emit(Signals.openUrl, self.twsUrl)

    @pyqtSignature('')
    def on_actionExportSession_triggered(self, filename=None):
        from profit.lib.widgets.importexportdialog import ImportExportDialog
        if not filename:
            filename = QFileDialog.getSaveFileName(
                self, 'Export Session To File')
        if filename:
            if self.session.exportInProgress():
                warningBox('Export in Progress',
                           'Session export already in progress.')
            else:
                dlg = ImportExportDialog('Export', self)
                if dlg.exec_() != dlg.Accepted:
                    return
                types = dlg.selectedTypes()
                if not types:
                    return
                self.session.exportMessages(filename, types)
                def lookup():
                    return not self.session.exportInProgress()
                dlg = WaitMessageBox(lookup, self)
                dlg.setText('Export in Progress...')
                dlg.setWindowTitle('Profit Workbench Session Export')
                dlg.show()

    @pyqtSignature('')
    def on_actionImportSession_triggered(self, filename=None):
        from profit.lib.widgets.importexportdialog import ImportExportDialog
        from profit.workbench.sessionreplay import SessionReplay
        if not filename:
            filename = QFileDialog.getOpenFileName(
                self, 'Import Session From File')
        if filename:
            dlg = ImportExportDialog('Import', self)
            if dlg.exec_() != dlg.Accepted:
                return
            types = dlg.selectedTypes()
            if not types:
                return
            if not self.warningOpenTabs():
                return
            dlg = SessionReplay()
            dlg.setWindowTitle('Reading session file.')
            dlg.setWindowModality(Qt.WindowModal)
            dlg.setImportParameters(self.session, filename, types)
            dlg.exec_()

    @pyqtSignature('bool')
    def on_actionNewSession_triggered(self, checked=False):
        try:
            if len(argv) > 1:
                argv.remove(argv[1])
            pid = spawnvp(P_NOWAIT, argv[0], argv)
        except (NameError, ):
            Popen('"%s" "%s"' % (executable, argv[0], ))

    @pyqtSignature('')
    def on_actionOpenSession_triggered(self, filename=None):
        if not filename:
            filename = QFileDialog.getOpenFileName(self, 'Open Session')
        if filename:
            if self.session.messages:
                args = argv[:]
                if len(args) > 1:
                    args[1] = filename
                else:
                    args.append(abspath(str(filename)))
                try:
                    pid = spawnvp(P_NOWAIT, args[0], args)
                except (NameError, ):
                    Popen('"%s" "%s" "%s"' % (executable, args[0], args[1]))
                return
            if not self.warningOpenTabs():
                return
            dlg = QProgressDialog(self)
            dlg.setLabelText('Reading session file.')
            dlg.setCancelButtonText('Abort')
            dlg.setWindowModality(Qt.WindowModal)
            dlg.setWindowTitle('Reading...')
            self.show()
            processEvents()
            dlg.show()
            processEvents()
            try:
                loadit = self.session.load(str(filename))
                count = loadit.next()
                last = count - 1
            except (StopIteration, ):
                msg = 'Warning session not loaded from "%s"' % filename
                dlg.close()
            else:
                dlg.setLabelText('Loading session messages.')
                dlg.setWindowTitle('Loading...')
                dlg.setMaximum(last)
                msgid = -1
                for msgid in loadit:
                    processEvents()
                    dlg.setValue(msgid)
                    if dlg.wasCanceled():
                        dlg.close()
                        break
                if msgid == last:
                    msg = 'Loaded all %s messages from file "%s".'
                    msg %= (count, filename)
                    self.setCurrentSession(filename)
                else:
                    msg = 'Load aborted; loaded %s messages of %s.'
                    msg %= (msgid+1, count)
            self.statusBar().showMessage(msg, 5000)

    @pyqtSignature('')
    def on_actionQuit_triggered(self):
        if self.checkClose():
            self.closeProcessGroup()

    @pyqtSignature('')
    def on_actionSaveSession_triggered(self):
        if self.session.filename is None:
            self.actionSaveSessionAs.trigger()
        else:
            if self.session.saveInProgress():
                warningBox('Save in Progress',
                           'Session save already in progress.')
            else:
                self.session.save()
                def lookup():
                    return not self.session.saveInProgress()
                dlg = WaitMessageBox(lookup, self)
                dlg.setText('Save in Progress...')
                dlg.setWindowTitle('Profit Workbench Session Save')
                dlg.show()

    @pyqtSignature('')
    def on_actionSaveSessionAs_triggered(self):
        filename = QFileDialog.getSaveFileName(self, 'Save Session As')
        if filename:
            self.session.filename = str(filename)
            self.actionSaveSession.trigger()

    @pyqtSignature('')
    def on_actionSettings_triggered(self):
        from profit.workbench.settingsdialog import SettingsDialog
        dlg = SettingsDialog()
        dlg.readSettings(Settings())
        if dlg.exec_() == dlg.Accepted:
            self.emit(Signals.settingsChanged)

    @pyqtSignature('')
    def on_actionStrategyDesigner_triggered(self):
        from profit.strategydesigner.main import StrategyDesigner
        settings = Settings()
        settings.beginGroup(settings.keys.strategy)
        if settings.value('type', '').toString()=='file':
            filename = settings.value('location', '').toString()
            def x(name):
                print '## strategy file named %s updated' % (name, )
        else:
            def x(name):
                print "## strategy file updated but i don't care"
            filename = None
        win = StrategyDesigner(filename=filename, parent=self)
        win.show()

    def on_trayIcon_activated(self, reason):
        if reason == QSystemTrayIcon.Trigger:
            self.setVisible(not self.isVisible())
        elif reason == QSystemTrayIcon.MiddleClick:
            if self.session and self.session.isConnected():
                msg = 'Connected'
            else:
                msg = 'Not Connected'
            self.trayIcon.showMessage('Connection Status:', msg)

    @pyqtSignature('')
    def openRecentSession(self):
        filename = str(self.sender().data().toString())
        self.on_actionOpenSession_triggered(filename)

    def readSettings(self):
        settings = Settings()
        settings.beginGroup(settings.keys.main)
        size = settings.value(settings.keys.size,
                              defaults.windowSize).toSize()
        pos = settings.value(settings.keys.position,
                             defaults.windowPosition).toPoint()
        maxed = settings.value(settings.keys.maximized, False).toBool()
        self.resize(size)
        self.move(pos)
        if maxed:
            self.showMaximized()
        state = settings.value(settings.keys.winstate, QVariant())
        self.restoreState(state.toByteArray())
        settings.endGroup()

    def setupColors(self):
        settings = Settings()
        settings.beginGroup(settings.keys.appearance)
        cls = ValueColorItem
        keys = ['increaseColor', 'neutralColor', 'decreaseColor']
        attrs = [k.replace('Color', '') for k in keys]
        values = [QColor(settings.value(key, getattr(cls, attr)))
                     for key, attr in zip(keys, attrs)]
        cls.setColors(*values)

    def setCurrentSession(self, filename):
        settings = Settings()
        settings.beginGroup(settings.keys.main)
        files = settings.value('recentSessions').toStringList()
        files.removeAll(filename)
        files.prepend(filename)
        files = files[:self.maxRecentSessions]
        settings.setValue('recentSessions', files)
        self.updateRecentSessions()

    def setupDockWidgets(self):
        bottom = Qt.BottomDockWidgetArea
        tabify = self.tabifyDockWidget
        self.sessionDock = Dock('Session', self, SessionTree)
        self.propertyEditor = Dock('Property Editor', self, PropertyEditor)
        tabify(self.propertyEditor, self.sessionDock)
        self.stdoutDock = Dock('Standard Output', self, OutputWidget, bottom)
        self.stderrDock = Dock('Standard Error', self, OutputWidget, bottom)
        def makeShell(p):
            shell = ExtendedPythonShell(p)
            shell.shellWidget.setStdOutErr(stdout=self.stdoutDock.widget(),
                               stderr=self.stderrDock.widget())
            return shell
        self.shellDock = Dock('Python Shell', self, makeShell, bottom)
        tabify(self.shellDock, self.stdoutDock)
        tabify(self.stdoutDock, self.stderrDock)

    def setupMainIcon(self):
        icon = QIcon(self.iconName)
        self.setWindowIcon(icon)

    def setupMenus(self):
        addr = self.menuView.addAction
        for o in self.findChildren(Dock):
            addr(o.toggleViewAction())
        self.menuView.addSeparator()
        addr(self.actionStatusBar)
        self.menuView.addMenu(self.menuToolbars)
        for toolbar in self.findChildren(QToolBar):
            self.menuToolbars.addAction(toolbar.toggleViewAction())

    def setupRecentSessions(self):
        self.recentSessionsActions = actions = \
            [QAction(self) for i in range(self.maxRecentSessions)]
        for action in actions:
            action.setVisible(False)
            self.connect(action, Signals.triggered, self.openRecentSession)
        menu = self.menuRecentSessions
        menu.clear()
        for action in actions:
            menu.addAction(action)
        self.recentSeparator = menu.addSeparator()
        menu.addAction(self.actionClearRecentMenu)
        self.updateRecentSessions()

    def setupSysTray(self):
        settings = Settings()
        settings.beginGroup(settings.keys.main)
        if settings.value('useSystemTrayIcon', QVariant(1)).toInt()[0]:
            icon = self.windowIcon()
            try:
                trayIcon = self.trayIcon
            except (AttributeError, ):
                self.trayIcon = trayIcon = QSystemTrayIcon(self)
                self.trayMenu = trayMenu = QMenu()
                trayIcon.setIcon(icon)
                trayMenu.addAction(icon, applicationName())
                trayMenu.addSeparator()
                for action in self.menuFile.actions():
                    trayMenu.addAction(action)
                    trayIcon.setContextMenu(trayMenu)
                self.connect(trayIcon, Signals.trayIconActivated,
                             self.on_trayIcon_activated)
            trayIcon.show()
        else:
            try:
                trayIcon = self.trayIcon
            except (AttributeError, ):
                pass
            else:
                trayIcon.hide()

    def updateRecentSessions(self):
        settings = Settings()
        settings.beginGroup(settings.keys.main)
        files = settings.value('recentSessions').toStringList()
        files = set([abspath(str(s)) for s in files])
        files = list(files)
        count = min(len(files), self.maxRecentSessions)
        for i in range(count):
            text = files[i]
            action = self.recentSessionsActions[i]
            action.setText(basename(str(text)))
            action.setData(QVariant(text))
            action.setVisible(True)
        for i in range(count, self.maxRecentSessions):
            action = self.recentSessionsActions[i]
            action.setVisible(False)
        self.recentSeparator.setVisible(count > 0)

    def warningOpenTabs(self):
        """ Returns true if it's okay to have open tabs.  Maybe prompts user.

        """
        try:
            if int(environ.get('WORKBENCH_IGNORE_TABS', 0)):
                return True
        except (ValueError, ):
            pass
        if self.centralTabs.count():
            buttons = QMessageBox.Ignore|QMessageBox.Abort|QMessageBox.Close
            button = QMessageBox.warning(self, 'Warning',
                         'Session loading is very slow with open tabs.\n\n'
                         'Close tabs for fastest possible loading.',
                          buttons)
            if button == QMessageBox.Close:
                self.centralTabs.closeTabs()
            return button in (QMessageBox.Ignore, QMessageBox.Close)
        return True

    def centralTabState(self):
        """ Returns a list of open tab names.

        """
        return [s for s in self.centralTabs.pageMap()]

    def writeSettings(self):
        """ Saves some main window settings.

        """
        settings = Settings()
        settings.beginGroup(settings.keys.main)
        settings.setValue(settings.keys.size, self.size())
        settings.setValue(settings.keys.position, self.pos())
        settings.setValue(settings.keys.maximized, self.isMaximized())
        settings.setValue(settings.keys.winstate, self.saveState())
        settings.setValueDump(settings.keys.ctabstate, self.centralTabState())
        settings.endGroup()
