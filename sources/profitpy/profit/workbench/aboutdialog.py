#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

from os.path import join, split
from PyQt4.QtGui import QDialog

import profit
from profit.workbench.widgets.ui_aboutdialog import Ui_AboutDialog

aboutText = """Profit Workbench, part of ProfitPy

(c) 2003-2008, Troy Melhase
"""


authorsText = """<html><head><meta name="qrichtext" content="1" /></head>
<body>

Please report bugs at <a href="http://code.google.com/p/profitpy/issues/list">http://code.google.com/p/profitpy/issues/list</a>.
<br />
<br />
Troy Melhase
<div style="margin:0;margin-left:1em;">
    <a href="mailto:troy@gci.net">troy@gci.net</a>
</div>
</body>
</html>
"""


class AboutDialog(QDialog, Ui_AboutDialog):
    def __init__(self, parent=None):
        QDialog.__init__(self, parent)
        self.setupUi(self)
        self.licenseText.setText(
            open(join(split(profit.__file__)[0], '..', 'LICENSE')).read())
        self.aboutText.setText(aboutText)
        self.authorsText.setText(authorsText)
