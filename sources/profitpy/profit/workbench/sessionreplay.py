#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

##
# This module defines the SessionReplay dialog class.
#
# SessionReplay dialogs offer the user widgets to control the replay
# of a session.  It includes a delivery interval spinner and
# associated slider, and also a button to restart the session replay.
##


from PyQt4.QtCore import QTimer
from PyQt4.QtGui import QDialog, QMessageBox

from profit.lib import logging
from profit.lib import Signals
from profit.workbench.widgets.ui_sessionreplay import Ui_SessionReplayWidget


class SessionReplay(QDialog, Ui_SessionReplayWidget):
    """ Dialog for controlling the replay of a session.

    After the dialog instance is constructed, clients should call
    the 'setSession' to associate the dialog with a session.

    Clients should use 'exec_()' to display the dialog, not 'show'.
    """
    def __init__(self, interval=50, parent=None):
        """ Initializer.

        @param interval=50 milliseconds between message delivery
        @param parent=None ancestor of this dialog
        """
        QDialog.__init__(self, parent)
        self.setupUi(self)
        self.interval = interval
        self.session = None
        self.filename = None
        self.types = None
        self.loader = None
        self.importer = None
        self.timer = QTimer()

    def exec_(self):
        """ Dialog main loop.

        @return QDialog.DialogCode result
        """
        connect = self.connect
        setInterval = self.timer.setInterval
        connect(self.timerSlider, Signals.intValueChanged, setInterval)
        connect(self.timerSpin, Signals.intValueChanged, setInterval)
        connect(self.timer, Signals.timeout, self.on_timer_timeout)
        self.timer.start(self.interval)
        return QDialog.exec_(self)

    def on_restartButton_clicked(self):
        """ Signal handler for restart button clicked signals.

        """
        if self.importer:
            self.timer.setInterval(self.timerSpin.value())
            self.loader = self.importer()

    def on_timer_timeout(self):
        """ Signal handler for the delivery timer timeout signal.

        If the instance has a session but no loader, it will attempt
        to import the session object and initiate the replay.

        If a loader is present (possibly added by importSession), the
        the next message is requested from the loader.

        @return None
        """
        if self.session and not self.loader:
            try:
                self.importSession(self.session, self.filename, self.types)
            except (Exception, ), ex:
                QMessageBox.critical(
                    self, 'Import Exception',
                    'Exception "%s" during import.  '
                    'Import not completed.' % ex)
                self.close()
        if self.loader:
            try:
                msgid = self.loader.next()
            except (StopIteration, ):
                self.timer.setInterval(max(self.timer.interval(), 50))
            else:
                self.importProgress.setValue(msgid)
                if msgid == self.last:
                    logging.debug(
                        'Imported %s messages from file "%s".',
                        self.count, self.filename)

    def importSession(self, session, filename, types):
        """ Initiates session import.

        @param session Session instance
        @param filename name of file with serialized messages
        @param types sequence of message types to import
        @return None
        """
        importer = session.importMessages(str(filename), types)
        loader = importer()
        try:
            self.count = loader.next()
            self.last = self.count - 1
            if not self.count:
                raise StopIteration()
        except (StopIteration, ):
            self.loader = self.count = self.last = None
            logging.debug('Warning messages not imported from "%s"', filename)
        else:
            self.importProgress.setMaximum(self.last)
            self.importer = importer
            self.loader = loader

    def setImportParameters(self, session, filename, types):
        """ Sets the parameters for the import (replay) of session messages.

        @param session Session instance
        @param filename name of file with serialized messages
        @param types sequence of message types to import
        @return None
        """
        self.session = session
        self.filename = filename
        self.types = types

