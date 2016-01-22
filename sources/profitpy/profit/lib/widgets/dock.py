#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

from PyQt4.QtCore import Qt
from PyQt4.QtGui import QDockWidget


class Dock(QDockWidget):
    """ Simplified interface to QDockWidget.

    """
    def __init__(self, title, parent, childType,
                 area=Qt.LeftDockWidgetArea,
                 allowedAreas=Qt.AllDockWidgetAreas,
                 autoAddDock=True,
                 features=QDockWidget.AllDockWidgetFeatures):
        """ Constructor.

        @param title dock title
        @param parent ancestor widget
        @param childType callable to produce child widget
        @param area default dock area
        @param allowedAreas dock widget allowed areas
        @param autoAddDock if True, dock widget is added to parent
        @param features dock widget features
        """
        QDockWidget.__init__(self, title, parent)
        self.setObjectName(title)
        self.setAllowedAreas(allowedAreas)
        self.setFeatures(features)
        self.setWidget(childType(self))
        if autoAddDock:
            parent.addDockWidget(area, self)
