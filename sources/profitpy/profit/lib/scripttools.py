#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase, Yichun Wei
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>,
#         Yichun Wei <yichun.wei@gmail.com>

import copy
import logging
import optparse
import time

from PyQt4.QtCore import QCoreApplication, QThread

from profit.lib import Signals
from profit.session import Session


class defaults:
    clientid = 1
    duration = 'forever'
    host = 'localhost'
    interval = 60
    nice = 19
    output = '%i%0.2i%0.2i.session' % time.localtime()[0:3]
    port = 7496
    start = 'immediate'
    stop = 'none'
    verbose = False


def check_duration(option, opt, value):
    try:
        return int(value)
    except (ValueError, ):
        if value == defaults.duration:
            return value
        else:
            raise optparse.OptionValueError(
                'option %s: invalid duration: %r' % (opt, value))


def check_hms(option, opt, value):
    if value.count(':') == 1:
        value += ':00'
    try:
        time.strptime(value, '%H:%M:%S')
    except (ValueError, ):
        if value in (defaults.start, defaults.stop):
            return value
        else:
            raise optparse.OptionValueError(
                'option %s: invalid time: %r' % (opt, value))
    else:
        return value


class LocalOption(optparse.Option):
    TYPES = optparse.Option.TYPES + ('duration', 'hms', )
    TYPE_CHECKER = copy.copy(optparse.Option.TYPE_CHECKER)
    TYPE_CHECKER['duration'] = check_duration
    TYPE_CHECKER['hms'] = check_hms


class CollectorThread(QThread):
    def __init__(self, stop, options, parent=None):
        QThread.__init__(self) # , parent)
        self.options = options
        self.stop = stop
        self.successful = False

    def run(self):
        logging.debug('Collector thread started.')
        last = time.time()
        stop = self.stop
        options = self.options
        interval = options.interval * 60

        self.session = session = Session(strategy=False)
        session.filename = options.output
        self.connect(session, Signals.session.status, logging.debug)

        session.connectTWS(
            options.host, options.port, options.clientid)
        if not session.isConnected():
            logging.error('Could not connect to %s:%s.',
                          options.host, options.port)
            logging.error('Aborting.')
            return
        session.requestAccount()
        while True:
            now = time.time()
            if stop is not None:
                if stop < now:
                    break
            self.sleep(1)
            if last + interval < now:
                session.save()
                self.successful = True
                last = now
            QCoreApplication.processEvents()
        QCoreApplication.processEvents()
        logging.debug('Collector thread completed.')

    def __repr__(self):
        s = QThread.__repr__(self)
        return s[0:-1] + (' (running? %s)>' % self.isRunning())

class WaitingThread(QThread):
    def __init__(self, when, parent=None):
        QThread.__init__(self, parent)
        self.when = when

    def run(self):
        logging.debug('Wait thread started.')
        while True:
            now = time.time()
            if self.when < now:
                logging.debug('Wait thread completed.')
                return
            self.sleep(1)
            QCoreApplication.processEvents()


