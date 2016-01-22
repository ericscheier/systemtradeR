#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase, Yichun Wei
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>
#         Yichun Wei <yichun.wei@gmail.com>

from cPickle import PicklingError, dump
from PyQt4.QtCore import QThread


class SaveThread(QThread):
    """ SaveThread -> Thread class for saving session messages asynchronously.


    """
    def __init__(self, filename, types, parent):
        """ Initializer.

        @param filename name of file to write
        @param types sequence of types to save; use a false value to save all
        @param parent parent of this object; should be a Session instance
        @return None
        """
        QThread.__init__(self, parent)
        self.filename = filename
        self.types = types

    def run(self):
        """ Saves parent's messages to a file with the pickling protocol.

        @return None
        """
        status = False
        session = self.parent()
        try:
            handle = open(self.filename, 'wb')
        except (IOError, ):
            pass
        else:
            last = len(session.messages)
            extras = session.extraObjects()
            messages = session.messages[0:last] + extras
            types = self.types
            if types:
                def messageFilter((mtime, message)):
                    return message.typeName in types
                messages = filter(messageFilter, messages)
                last = len(messages)
            try:
                dump(messages, handle, protocol=-1)
                self.writeCount = last
                status = True
            except (PicklingError, ):
                pass
            finally:
                handle.close()
        self.status = status
