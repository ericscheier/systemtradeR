#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

##
#
# The schema can have two types at the root:  runners and tickers.
#
# Runners describe a program or object and when to run it.  They can
# contain callables and tickers.
#
# Tickers describe the ticker data available to the strategy.
#
##


class Root(object):
    def allowChildType(self, t):
        return t in [Runner, Ticker, ]


##
# Clients should use StrategySchema

StrategySchema = Root


class Runner(object):
    """ Runners describe when to execute the Callables they contain.

    The Strategy class turns Runner descriptions into various types of
    callable code; it does the work of importing objects, starting
    threads, and executing out-of-process code.
    """
    attrs = dict(execType='single', periodInterval=1000, messageTypes=set())

    def allowChildType(self, t):
        return t in [Callable, ]


class Ticker(object):
    """ Tickers store the numeric id and symbol of a ticker.  They
    also include contract information.  Tickers can only contain
    fields.

    See also: Strategy class description.
    """
    attrs = dict(tickerId=None, symbol=None, exchange='',
                 secType='', expiry='', right='', strike=0.0, currency='')

    def allowChildType(self, t):
        return t in [TickerField, ]


class TickerField(object):
    """ TickerField items associate a ticker data field (ask price, bid
    size) with a list of indexes.

    """
    attrs = dict(id=-1)

    def allowChildType(self, t):
        return t in [TickerFieldIndex, ]


class TickerFieldIndex(object):
    """ TickerFieldIndexs associate an index class (found in profit.series)
    with parameters.

    """
    attrs = dict(indexType='', parameters={})

    def allowChildType(self, t):
        return t in [TickerFieldIndex, ]


class Callable(object):
    """ Callable items describe where a program or object exists.


    """
    attrs = dict(callType='', callLocation='', moduleSource='')

    def allowChildType(self, t):
        return t in [Callable, ]
