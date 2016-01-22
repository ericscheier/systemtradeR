#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

from profit.examples.accountsummary import AccountSummary
from profit.lib.widgets.dock import Dock


main.accountDock = Dock('Account Summary', main, AccountSummary)
main.tabifyDockWidget(main.sessionDock, main.accountDock)
main.menuView.addAction(main.accountDock.toggleViewAction())


