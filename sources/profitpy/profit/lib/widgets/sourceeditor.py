#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from PyQt4.QtGui import QFrame

try:
    from profit.lib.widgets.ui_advancededitor import Ui_AdvancedEditor as Editor
except (ImportError, ):
    from profit.lib.widgets.ui_basiceditor import Ui_BasicEditor as Editor

try:
    from PyQt4.Qsci import QsciLexerPython, QsciScintilla
except (ImportError, ):
    QsciLexerPython = None

from profit.lib import Signals


class SourceEditor(QFrame, Editor):
    def __init__(self, parent=None):
        QFrame.__init__(self, parent)
        self.setupUi(self)
        self.setupEditor()

    def setupEditor(self):
        editor = self.textEdit
        if QsciLexerPython:
            editor.setLexer(QsciLexerPython(editor))
            editor.setMarginLineNumbers(0, True)
            editor.setFolding(QsciScintilla.BoxedTreeFoldStyle)
            editor.setMarginWidth(0, '000')
        self.connect(editor, Signals.textChangedEditor, self, Signals.textChangedEditor)

    def text(self):
        return self.textEdit.text()

    def setText(self, text):
        return self.textEdit.setText(text)
