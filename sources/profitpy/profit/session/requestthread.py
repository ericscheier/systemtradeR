#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase, Yichun Wei
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>
#         Yichun Wei <yichun.wei@gmail.com>


from PyQt4.QtCore import QMutex, QThread
from profit.lib import logging

class RequestThread(QThread):
    """ RequestThread -> queues requests until connection is active.


    """
    def __init__(self, parent):
        """ Initializer.

        @param parent parent of this object; should be a Session instance
        @return None
        """
        QThread.__init__(self, parent)
        self.queue = []
        self.mutex = QMutex()

    def run(self):
        """ Send queued requests.

        @return None
        """
        session = self.parent()
        ## could connect to session Signals.tws.connected
        while True:
            self.msleep(500)
            if self.queue and session.isConnected():
                request, args, kwds = self.nextRequest()
                try:
                    request(*args, **kwds)
                except (Exception, ), exc:
                    logging.exception('Could not call request: %s', request)

    def addRequest(self, request, *args, **kwds):
        self.mutex.lock()
        self.queue.append((request, args, kwds))
        self.mutex.unlock()

    def nextRequest(self):
        self.mutex.lock()
        request = self.queue.pop(0)
        self.mutex.unlock()
        return request
