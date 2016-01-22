#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase, Yichun Wei
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

from time import localtime, strftime

from PyQt4.QtGui import QDialog

from ib.ext.Contract import Contract
from profit.lib.widgets.ui_historicaldatadialog import Ui_HistoricalDataDialog


def nextTickerId():
    ## TODO:  make this a session value and increment it
    from random import randint
    return randint(1000, 2000)


class HistoricalDataDialog(QDialog, Ui_HistoricalDataDialog):
    dateTypeMap = {'Strings':1, 'Integers':2, }
    rthMap = {True:1, False:0, }
    keywords = [
        'tickerId',
        'contract',
        'endDateTime',
        'durationStr',
        'barSizeSetting',
        'whatToShow',
        'useRTH',
        'formatDate',
    ]

    def __init__(self, parent):
        QDialog.__init__(self, parent)
        self.setupUi(self)

    def historicalRequestParameters(self):
        """ Returns a map suitable for a TWS historical data request.

        The map keys are the same as arguments to reqHistoricalData,
        and the values are read and converted where required.
        """
        params = dict.fromkeys(self.keywords, '')
        for name in self.keywords:
            params[name] = getattr(self, name)()
        return params

    def tickerId(self):
        ## its not even a tickerId!
        tid = self.tickId.value()
        if tid == -1:
            tid = nextTickerId()
        return tid

    def contract(self):
        symbol = self.symbolName.text()
        security = self.secType.currentText()
        exchange = self.exchangeName.currentText()
        contract = Contract()
        contract.m_symbol = str(symbol)
        contract.m_secType = str(security)
        contract.m_exchange = str(exchange)
        contract.m_currency = 'USD'
        return contract

    def endDateTime(self):
        edt = self.startDate.dateTime().toPyDateTime()
        fmt = "%Y%m%d %H:%M:%S" # + strftime("%Z", localtime())
        return edt.strftime(fmt)

    def durationStr(self):
        dvalue = self.durationValue.value()
        dtype = str(self.durationType.currentText())[0]
        return '%s %s' % (dvalue, dtype, )

    def barSizeSetting(self):
        return str(self.barSize.currentText())

    def whatToShow(self):
        return str(self.showType.currentText()).upper()

    def useRTH(self):
        return self.rthMap[bool(self.rthYes.isChecked())]

    def formatDate(self):
        return self.dateTypeMap[str(self.dateType.currentText())]
