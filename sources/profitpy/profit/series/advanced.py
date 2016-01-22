#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

from numpy import arctan, array, log, mean, std, median
from scipy.stats import linregress, mode

from profit.series.basic import SeriesIndex, MovingAverageIndex


class FisherTransform(MovingAverageIndex):
    """ FisherTransform

    """
    params = [
        ('series', dict(type='line')),
        ('periods', dict(type='int', min=1))
    ]

    def __init__(self, series, periods):
        MovingAverageIndex.__init__(self, series, periods)
        self.inter = []

    def reindex(self):
        periods = self.periods
        period = self.series[-periods:]
        current = period[-1]
        mx = max(period)
        mn = min(period)
        try:
            inter = 0.33 * 2 * ((current - mn) / (mx - mn) - 0.5) + (0.67 * self.inter[-1])
            if inter > 0.99:
                inter = 0.99
            elif inter < -0.99:
                inter = -0.99
            fish = 0.5 * log((1 + inter) / (1 - inter)) + (0.5 * self[-1])
        except (TypeError, IndexError, ZeroDivisionError, ):
            inter = 0
            fish = 0
        self.inter.append(inter)
        self.append(fish)


class MAMA(MovingAverageIndex):
    """ Mother of Adaptave Moving Averages.

    """
    fast_limit = 0.5
    slow_limit = 0.05
    params = [
        ('series', dict(type='line')),
        ('periods', dict(type='int', min=1))
    ]

    def __init__(self, series, periods):
        MovingAverageIndex.__init__(self, series, periods)
        self.hist = {'q1':[], 'i1':[], 'q2':[], 'i2':[], 're':[], 'im':[],
                     'sms':[], 'dts':[], 'prs':[], 'sps':[], 'phs':[], }

    def reindex(self):
        hist = self.hist
        sms, dts, prs, sps, phs = \
            hist['sms'], hist['dts'], hist['prs'], hist['sps'], hist['phs']
        q1, i1, q2, i2, re, im = \
            hist['q1'], hist['i1'], hist['q2'], hist['i2'], hist['re'], hist['im']
        series = self.series
        periods = self.periods
        if len(series) > periods:
            sm = sum((4*series[-1], 3*series[-2], 2*series[-3], series[-4])) / 10
            sms.append(sm)
            dt = (0.0962*sms[-1] + 0.5769*sms[-3] - 0.5769*sms[-5] - 0.0962*sms[-7]) * (0.075*prs[-2] + 0.54)
            dts.append(dt)
            qa = (.0962*dts[-1] + 0.5769*dts[-3] - 0.5769*dts[-5] - 0.0962*dts[-7]) * (0.075*prs[-2] + 0.54)
            q1.append(qa)
            ia = dts[-4]
            i1.append(ia)
            jI = (0.0962*i1[-1] + 0.5769*i1[-3] - 0.5769*i1[-5] - 0.0962*i1[-7]) * (0.075*prs[-2] + 0.54)
            jQ = (0.0962*q1[-1] + 0.5769*q1[-3] - 0.5769*q1[-5] - 0.0962*q1[-7]) * (0.075*prs[-2] + 0.54)
            ib = i1[-1] - jQ
            qb = q1[-1] - jI
            ib = 0.2*ib + 0.8*i2[-1]
            qb = 0.2*qb + 0.8*q2[-1]
            i2.append(ib)
            q2.append(qb)
            ra = i2[-1]*i2[-2] + q2[-1]*q2[-2]
            ima = i2[-1]*q2[-2] - q2[-1]*i2[-2]
            ra = 0.2*ra + 0.8*re[-1]
            ima = 0.2*ra + 0.8*im[-1]
            re.append(ra)
            im.append(ima)
            if im[-1] != 0 and re[-1] != 0:
                pra = 360 / arctan(im[-1]/re[-1])
            else:
                pra = 0
            if pra > 1.5*prs[-1]: pra = 1.5*prs[-1]
            if pra < 0.67*prs[-1]: prs = 0.67*prs[-1]
            if pra < 6: pra = 6
            if pra > 50: pra = 50
            pra = 0.2*pra + 0.8*prs[-1]
            prs.append(pra)
            spa = 0.33*prs[-1] + 0.67*sps[-1]
            sps.append(spa)
            if i1[-1] != 0:
                ph = arctan(q1[-1] / i1[-1])
            else:
                ph = 0
            phs.append(ph)
            dp = phs[-2] - phs[-1]
            if dp < 1: dp = 1
            alpha = self.fast_limit / dp
            if alpha < self.slow_limit: alpha = self.slow_limit
            mama = alpha*series[-1] + (1 - alpha)*self[-1]
            #FAMA = .5*alpha*MAMA + (1 - .5*alpha)*FAMA[1];
            self.append(mama)
        else:
            last = series[-1]
            for vlst in hist.values():
                vlst.append(last)
            self.append(last)


class SMA(MovingAverageIndex):
    """ Simple Moving Average index.

    """
    params = [
        ('series', dict(type='line')),
        ('periods', dict(type='int', min=1))
    ]

    def reindex(self):
        periods = self.periods
        period = self.series[-periods:]
        sma = None
        if len(period) == periods:
            try:
                sma = mean(period)
            except (TypeError, IndexError):
                pass
        self.append(sma)


class EMA(MovingAverageIndex):
    """ Exponential Moving Average index.

    """
    params = [
        ('series', dict(type='line')),
        ('periods', dict(type='int', min=1)),
        ('k', dict(type='float', min=0.001, default=2.0))
    ]

    def __init__(self, series, periods, k=2.0):
        MovingAverageIndex.__init__(self, series, periods)
        self.k = k

    def reindex(self):
        try:
            last = self[-1]
        except (IndexError, ):
            self.append(None)
            return
        periods = self.periods
        ema = None
        if last is None:
            try:
                period = self.series[-periods:]
                if len(period) == periods:
                    ema = mean(period)
            except (TypeError, ):
                pass
        else:
            pt = self.series[-1]
            k = self.k / (periods + 1)
            ema = last + (k * (pt - last))
        self.append(ema)


class WMA(MovingAverageIndex):
    """ Weighted Moving Average index.

    """
    params = [
        ('series', dict(type='line')),
        ('periods', dict(type='int', min=1)),
    ]

    def __init__(self, series, periods):
        MovingAverageIndex.__init__(self, series, periods)
        offsets = range(1, periods+1)
        periods_sum = float(sum(offsets))
        self.weights = array([x/periods_sum for x in offsets])

    def reindex(self):
        periods = self.periods
        period = self.series[-periods:]
        wma = None
        if len(period) == periods:
            try:
                wma = sum(period * self.weights)
            except (TypeError, ):
                pass
        self.append(wma)


class Volatility(MovingAverageIndex):
    """ Volatility index.

    Volatility = standard deviation of closing price [for n periods] /
    average closing price [for n periods]
    """
    params = [
        ('series', dict(type='line')),
        ('periods', dict(type='int', min=1)),
    ]

    def reindex(self):
        periods = self.periods
        period = self.series[-periods:]
        vol = None
        if len(period) == periods:
            try:
                vol = std(period) / mean(period)
                vol *= 100
            except TypeError:
                pass
        self.append(vol)


class VerticalHorizontalFilter(MovingAverageIndex):
    """ VerticalHorizontalFilter

    """
    params = [
        ('series', dict(type='line')),
        ('periods', dict(type='int', min=1))
    ]

    def reindex(self):
        periods = self.periods
        period = self.series[-periods:]
        vhf = None
        if len(period) == periods:
            try:
                diffs = array(period[1:]) - period[0:-1]
                vhf = (max(period) - min(period)) / sum(abs(diffs))
            except (IndexError, TypeError, ZeroDivisionError):
                pass
        self.append(vhf)


class BollingerBand(SeriesIndex):
    """ BollingerBand

    """
    params = [
        ('series', dict(type='line')),
        ('period', dict(type='int', min=1)),
        ('dev_factor', dict(type='float')),
    ]

    def __init__(self, series, period, dev_factor):
        SeriesIndex.__init__(self, series)
        self.period = period # allows for periods != periods of series
        self.dev_factor = dev_factor

    def reindex(self):
        period = self.series[-self.period:]
        last = self.series[-1]
        try:
            dev = std(period)
            dev *= self.dev_factor
            dev += last
        except (TypeError, ZeroDivisionError, ):
            dev = None
        self.append(dev)


class LinearRegressionSlope(SeriesIndex):
    """ LinearRegressionSlope

    LinearRegressionSlope(series, periods) -> slope of the linear
    regression
    """
    params = [
        ('series', dict(type='line')),
        ('period', dict(type='int', min=1)),
        ('scale', dict(type='float', default=1.0)),
    ]

    def __init__(self, series, periods, scale=1):
        SeriesIndex.__init__(self, series)
        self.periods = periods
        self.scale = scale
        self.xarray = array(range(0, periods))

    def reindex(self):
        xa = self.xarray
        ya = array(self.series[-self.periods:])
        try:
            slope, intercept, r, two_tail_prob, est_stderr = linregress(xa, ya)
        except (TypeError, ValueError, ZeroDivisionError):
            slope = 0.0
        self.append(slope * self.scale)


class OrderStatisticFilter(MovingAverageIndex):
    """ Ordered Statistic Filter base class.

    OS filters base their operation on the ranking of the samples
    within the filter window.  The data are ranked by their summary
    statistics, such as their mean or variance, rather than by their
    temporal position.
    """
    not__params = [
        ('series', dict(type='line')),
        ('periods', dict(type='int', min=1))
    ]


class MedianValue(OrderStatisticFilter):
    """ Indexes a series by the median.

    """
    params = [
        ('series', dict(type='line')),
        ('periods', dict(type='int', min=1))
    ]

    def reindex(self):
        values = self.series[-self.periods:]
        m = median(values).toscalar()
        self.append(m)


class ModeValue(OrderStatisticFilter):
    """ Indexes a series by the mode.

    """
    params = [
        ('series', dict(type='line')),
        ('periods', dict(type='int', min=1))
    ]

    def reindex(self):
        values = self.series[-self.periods:]
        m = mode(values)[0].toscalar()
        self.append(m)
