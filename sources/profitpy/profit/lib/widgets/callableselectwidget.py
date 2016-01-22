#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

## TODO:  match warning to location label
## TODO:  fix enable/disable on change
## TODO:  streamline
## TODO:  provide valid marker on source edit emit

import logging
import sys

from os.path import abspath, exists
from string import Template
from tempfile import NamedTemporaryFile

from PyQt4.QtCore import QProcess, QVariant, pyqtSignature
from PyQt4.QtGui import QFileDialog, QFrame, QInputDialog, QMessageBox

from profit.lib import Settings, Signals
from profit.lib.widgets.syspathdialog import SysPathDialog
from profit.lib.widgets.ui_callableselect import Ui_CallableSelectWidget


class CallableSelectWidget(QFrame, Ui_CallableSelectWidget):
    """ CallableSelectWidget -> compound widget type for specifying a callable item

    """
    ## Six types are supported in the class.  These can be selectively
    ## disabled by the client.  NB: this list must match the items
    ## defined in the ui file.
    unsetType, externalType, objectType, factoryType, sourceType, fileType = range(6)

    ## The types are mapped to names so we can search for them by
    ## value.
    callTypeMap = {
        unsetType:'',
        externalType:'external',
        objectType:'object',
        factoryType:'factory',
        sourceType:'source',
        fileType:'file',
    }

    ## Each callable type suggests a suitable location label.  Notice
    ## we're mapping from the name, not the index.
    typeLocationLabels = {
        '':'',
        'external':'Command:',
        'object':'Value:',
        'factory':'Value:',
        'source':'Expression:',
        'file':'File:',
    }

    ## This is a list of names for convenience.
    pythonTypes = [
        callTypeMap[objectType],
        callTypeMap[factoryType],
        callTypeMap[sourceType],
    ]

    ## Another list of names for convenience.
    fsTypes = [
        callTypeMap[externalType],
        callTypeMap[fileType],
    ]

    revertSource = saveSource = None
    requireExpression = True

    def __init__(self, parent=None):
        """ Initializer.

        """
        QFrame.__init__(self, parent)
        self.setupUi(self)
        self.setupCallableTypes()

    def setupCallableTypes(self):
        """ Routine for configuration of the callableTypes combo.

        """
        for key, value in self.callTypeMap.items():
            self.callableType.setItemData(key, QVariant(value))
        self.connect(self.callableType, Signals.currentIndexChanged, 
                     self, Signals.currentIndexChanged)

    def setAttributes(self, **kwds):
        """

        """
        items = [
            ('callType', self.unsetType),
            ('locationText', ''),
            ('sourceText', ''),
            ('revertSource', None),
            ('saveSource', None), 
            ('requireExpression', True),
        ]
        for name, default in items:
            setattr(self, name, kwds.get(name, default))

    def basicSetup(self,  **kwds):
        """ Client configuration method.  Call this to configure an
            instance after initalization.

        """
        for key, value in self.callTypeMap.items():
            if kwds.get('disable%sType' % value.title(), False):
                self.callableType.removeItem(
                    self.callableType.findData(QVariant(value)))
                self.stackedWidget.removeWidget(
                    self.stackedWidget.widget(key))
        self.setAttributes(**kwds)
        self.saveButton.setEnabled(False)
        self.revertButton.setEnabled(False)

    def renameCallableTypeItem(self, old, new):
        """ Rename an callable type item without losing its value.

        """
        index = self.callableType.findText(old)
        if index > -1:
            self.callableType.setItemText(index, new)

    ## property for getting and setting the call type by index.  note
    ## that there isn't any conversion happening or necessary.

    def getCallTypeIndex(self):
        return self.callableType.currentIndex()

    def setCallTypeIndex(self, index):
        self.callableType.setCurretIndex(index)

    callTypeIndex = property(getCallTypeIndex, setCallTypeIndex)

    ## property for getting the call type name as a string.  note that
    ## there isn't a setter here, and note that the getter returns a
    ## python string, not a QString.

    def getCallType(self):
        wid = self.callableType
        return str(wid.itemData(wid.currentIndex()).toString())

    def setCallType(self, value):
        wid = self.callableType
        wid.setCurrentIndex(wid.findData(QVariant(value)))

    callType = property(getCallType, setCallType)

    ## property for getting and setting the location text.  again note
    ## the getter returns a python string.

    def getLocationText(self):
        return str(self.callableLocation.text())

    def setLocationText(self, text):
        self.callableLocation.setText(text)

    locationText = property(getLocationText, setLocationText)

    ## property for getting and setting the source code text.  note
    ## that the getter fixes up the string per python "compile"
    ## function requirements.

    def getSourceEditorText(self):
        source = self.callableSourceEditor.text()
        source = str(source).replace('\r\n', '\n')
        if not source.endswith('\n'):
            source += '\n'
        return source

    def setSourceEditorText(self, text):
        self.callableSourceEditor.setText(text)

    sourceText = property(getSourceEditorText, setSourceEditorText)

    def warn(self, text, widget=None):
        format = '<b>Warning:</b> %s.' if text else '%s'
        if widget is None:
            widget = self.locationWarning
        widget.setText(format % text)

    def on_textEdit_textChanged(self):
        try:
            self.callableCode()
        except (SyntaxError, ):
            msg = 'invalid syntax'
        else:
            msg = ''
        self.warn(msg, self.sourceWarning)
        self.saveButton.setEnabled(True)
        self.revertButton.setEnabled(True)

    def emitChanged(self):
        idx, typ, loc, txt = (
            self.callTypeIndex,
            self.callType,
            self.locationText,
            self.sourceText,
        )
        if idx != self.callTypeMap[self.sourceType]:
            txt = ''
        val = 'unknown'
        self.emit(Signals.modified, idx, typ, loc, txt, val)

    @pyqtSignature('int')
    def on_callableType_currentIndexChanged(self, index):
        ## enable or disable the location-related widgets; there isn't
        ## a group because of the grid layout.
        for widget in self.locationWidgets():
            widget.setDisabled(index == self.unsetType)

        ## set the location label to something relevant to the
        ## selected type.
        v = str(self.callableType.itemData(index).toString())
        self.locationLabel.setText(self.typeLocationLabels[v])

        if index == self.externalType:
            self.checkPathExists()
        else:
            isSource = (self.callType == self.callTypeMap[self.sourceType])
            self.callableLocationSelect.setDisabled(isSource)
            if isSource:
                self.callableLocation.setDisabled(not self.requireExpression)
        self.emitChanged()

    def checkPathExists(self):
        if not exists(abspath(self.locationText)):
            msg = 'location does not exist'
        else:
            msg = ''
        self.warn(msg)

    def callableCode(self):
        try:
            src = self.sourceText
        except (AttributeError, ):
            src = ''
        return compile(src, '<string>', 'exec')

    def on_callableLocation_textChanged(self, text):
        self.warn('')
        if self.callType == self.callTypeMap[self.sourceType]:
            try:
                code = self.callableCode()
            except (SyntaxError, ):
                msg = 'invalid syntax'
            else:
                text = str(text)
                msg = ''
                if  (text and (text not in code.co_names)) and self.requireExpression:
                    msg = 'expression not found in source'
            self.warn(msg)
        elif self.callType in self.fsTypes:
            self.checkPathExists()
        self.emitChanged()

    @pyqtSignature('')
    def on_callableLocationSelect_clicked(self):
        name = None
        calltype = self.callType
        if calltype in self.fsTypes:
            filename = QFileDialog.getOpenFileName(
                self, 'Select %s' % self.callTypeText, '',
                'Executable file (*.*)')
            if filename:
                name = filename
        elif calltype in self.pythonTypes:
            dlg = SysPathDialog(self)
            if dlg.exec_() == dlg.Accepted:
                name = dlg.selectedEdit.text()
        elif not calltype:
            QMessageBox.warning(
                self, 'Invalid Type', 'Select a callable type first.')
        else:
            pass # unknownType item (0) selected
        if name is not None:
            self.locationText = name
            self.emitChanged()

    @pyqtSignature('')
    def on_revertButton_clicked(self):
        if self.revertSource:
            self.sourceText = self.revertSource()
        self.saveButton.setEnabled(False)
        self.revertButton.setEnabled(False)

    @pyqtSignature('')
    def on_saveButton_clicked(self):
        if self.saveSource:
            self.saveSource(self.sourceText)
        self.saveButton.setEnabled(False)
        self.revertButton.setEnabled(False)

    def locationWidgets(self):
        return [self.locationLabel, self.locationWarning, 
                self.callableLocationSelect, self.callableLocation, ]


if __name__ == '__main__':
    from PyQt4.QtGui import QApplication
    app = QApplication(sys.argv)
    window = CallableSelectWidget(parent=None)
    window.show()
    sys.exit(app.exec_())
