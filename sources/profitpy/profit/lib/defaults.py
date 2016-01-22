#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

from PyQt4.QtCore import QByteArray, QPoint, QSize, Qt
from PyQt4.QtGui import QColor, QPen

windowSize = QSize(1024, 768)
windowPosition = QPoint(0, 0)


def tickerUrls():
    return [
        'Profile:http://www.marketwatch.com/tools/quotes/profile.asp?symb=$symbol',
        'News:http://www.marketwatch.com/tools/quotes/news.asp?symb=$symbol',
        'Financials:http://www.marketwatch.com/tools/quotes/financials.asp?symb=$symbol',
        'Historical Quotes:http://www.marketwatch.com/tools/quotes/historical.asp?symb=$symbol'
        'Message Board:http://www.marketwatch.com/discussions/msgIndex.asp?symb=$symbol',
        'SEC Filings:http://www.marketwatch.com/tools/quotes/secfilings.asp?symb=$symbol',
        'Options:http://www.marketwatch.com/tools/quotes/options1.asp?symb=$symbol',
    ]


class connection:
    host = 'localhost'
    port = 7496
    client = 0


def canvasColor():
    """ Reasonable default for canvas color.

    @return QColor instance
    """
    return QColor(240, 240, 240)


def itemPen(name):
    return QPen()


def majorGridPen():
    """ Reasonable default for major grid pen.

    @return QPen instance
    """
    pen = QPen(QColor(170, 170, 170))
    pen.setStyle(Qt.DashLine)
    return pen


def minorGridPen():
    """ Reasonable default for minor grid pen.

    @return QPen instance
    """
    pen = QPen(QColor(210, 210, 210))
    pen.setStyle(Qt.DotLine)
    return pen


def rightSplitterState():
    """ Resonable default for splitter state with primary widget on the right.

    @return QByteArray suitable for use with QSplitter.restoreState
    """
    return QByteArray.fromBase64('AAAA/wAAAAAAAAACAAAAiQAAAm8BAAAABgEAAAAB')


def leftSplitterState():
    """ Resonable default for splitter state with primary widget on the left.

    @return QByteArray suitable for use with QSplitter.restoreState
    """
    return QByteArray.fromBase64('AAAA/wAAAAAAAAACAAADQwAAAaUBAAAABgEAAAAB')


def tickerDisplayFields():
    return range(-3, 5)
