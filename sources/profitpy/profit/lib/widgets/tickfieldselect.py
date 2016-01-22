#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from re import split as rxsplit
from PyQt4.QtCore import Qt, QVariant, pyqtSignature
from PyQt4.QtGui import QFrame, QStandardItem
from ib.ext.TickType import TickType
from profit.lib import DataRoles
from profit.lib.widgets.ui_tickfieldselect import Ui_TickFieldSelect


class ExField(object):
    """ Namespace for our 'extra' fields, i.e., fields not in TickType.

    The extra fields are all negative so as to not conflict with those
    in TickType.
    """
    tid, sym, pos, val = enum = range(-4, 0)
    labels = ['id', 'symbol', 'position', 'value']
    all = zip(enum, labels)


def extraFieldSpecs():
    """ Generates sequence of dictionaries that describe our extra fields.

    """
    for field, label in ExField.all:
        yield dict(value=field, sort=field, name=label, title=label.title())


def fieldIds():
    """ Generates sequence of tick field identifiers.

    Refer to the TickType class for actual attributes and values.
    """
    for field in fieldSpecs():
        yield field['value']


def fieldSpecs():
    """ Yields one description dictionary for every TickType field.

    """
    values = [getattr(TickType, k) for k in dir(TickType)]
    for value in [v for v in values if isinstance(v, int)]:
        name = TickType.getField(value)
        title = tickFieldTitle(name)
        yield dict(sort=value, value=value, name=name, title=title)


def itemTickField(item):
    """ Returns the tick field from the item's data.  May be invalid.

    """
    return item.data(DataRoles.tickerField).toInt()[0]


def setItemTickField(item, field):
    """ Sets the tick field role on the item.

    """
    item.setData(DataRoles.tickerField, QVariant(field))


def tickFieldTitle(name):
    """ Make title from name, aka UnCapCase.

    """
    words = rxsplit('([A-Z0-9][a-z]+)', name)
    ## my rx fu isn't great enough.  special case for when the split
    ## does not work, e.g., bidEFP.
    if len(words) == 1:
        words = rxsplit('([a-z]+)', name)
    ## title case each word in the word list if the word isn't already
    ## all upper case.
    words = [(w if w.upper()==w else w.title()) for w in words if w]
    return str.join(' ', words)


class TickFieldSelect(QFrame, Ui_TickFieldSelect):
    """ TickFieldSelect -> widget for selecting various tick fields.

    """
    def __init__(self, parent=None):
        """ Initializer.

        @param parent ancestor object
        """
        QFrame.__init__(self, parent)
        self.setupUi(self)
        self.setupFieldsList()

    def setupFieldsList(self):
        """ Clears and fills the fields list.

        """
        fieldsList = self.fieldsList
        fieldsList.clear()
        allFields = list(extraFieldSpecs()) + list(fieldSpecs())
        allFields = sorted(allFields, key=lambda d:d['sort'])
        self.allTickFields = allFields
        for rowId, fieldDesc in enumerate(allFields):
            fieldsList.addItem(fieldDesc['title'])
            item = fieldsList.item(rowId)
            setItemTickField(item, fieldDesc['value'])
            item.setCheckState(Qt.Unchecked)

    def setCheckedFields(self, fields):
        """

        """
        for item in self.listItems():
            field = itemTickField(item)
            if field in fields:
                item.setCheckState(Qt.Checked)

    def listItems(self):
        """ Returns the QStandardItems in the fields list.

        """
        listWidget = self.fieldsList
        return [listWidget.item(r) for r in range(listWidget.count())]

    def checkedItems(self):
        """ Returns list of seleected fields names (as strings)

        """
        return [i for i in self.listItems() if i.checkState()==Qt.Checked]


    @pyqtSignature('')
    def on_checkNoneButton_clicked(self):
        """ Unchecks every item in the fields list.

        """
        for item in self.listItems():
            item.setCheckState(Qt.Unchecked)

    @pyqtSignature('')
    def on_checkAllButton_clicked(self):
        """ Checks every item in the fields list.

        """
        for item in self.listItems():
            item.setCheckState(Qt.Checked)



