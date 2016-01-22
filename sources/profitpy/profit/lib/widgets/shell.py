#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

""" an interactive shell control

Based on PyCute, Copyright Gerard Vermeulen
Based on Eric3, Copyright Detlev Offenbach
Based on OpenAlea, Copyright Samuel Dufour-Kowalski, Christophe Pradal

"""
import sys

from code import InteractiveInterpreter
from itertools import cycle
from os.path import exists, expanduser
from traceback import extract_tb, format_exception_only, format_list

from PyQt4.QtCore import Qt, QString
from PyQt4.QtGui import QApplication, QBrush, QColor, QFont, QKeyEvent, QTextCursor, QTextEdit, QTextCharFormat

from profit.lib import Settings, Signals, BasicHandler


# disable the help function because it reads directly from stdin and
# we don't want to mess with stdin/out/err.
import __builtin__
__builtin__.__dict__['_help'] = __builtin__.__dict__['help']
del(__builtin__.__dict__['help'])


class PythonInterpreter(InteractiveInterpreter):
    """ PythonInterpreter(...) -> InteractiveInterpreter with an output target

    """
    def __init__(self, output, locals=None, parent=None):
        InteractiveInterpreter.__init__(self, locals=locals)
        self.output = output
        self.parent = parent

    def showtraceback(self):
        """ Display the exception that just occurred.

        We remove the first stack item because it is our own code.

        The output is written by self.write(), below.
        """
        try:
            type, value, tb = sys.exc_info()
            sys.last_type = type
            sys.last_value = value
            sys.last_traceback = tb
            tblist = extract_tb(tb)
            del tblist[:1]
            seq = format_list(tblist)
            if seq:
                seq.insert(0, 'Traceback (most recent call last):\n')
            seq[len(seq):] = format_exception_only(type, value)
        finally:
            tblist = tb = None
        parent = self.parent
        for line, color in zip(seq, cycle(('#0000cc', '#0000cc', '#cc0000'))):
            self.write(line)

    def update(self, **kwds):
        self.locals.update(kwds)

class PythonShell(QTextEdit, BasicHandler):
    """ PythonShell(...) -> python shell widget

    """
    eofPrompt = 'Use Alt-F4 (i.e. Close Window) to exit.'
    historyName = '~/.profitdevice/shellhistory'
    maxHistory = 200
    introText = (
        'Python %s on %s\n' % (sys.version, sys.platform),
        'Type "copyright", "credits" or "license" for more information on Python.\n',
    )
    ps1 = '>>> '
    ps2 = '... '

    def setStdOutErr(self, stdout, stderr):
        sys.stdout.extend([stdout, self])
        sys.stderr.extend([stderr, self])

    def __init__(self, parent):
        QTextEdit.__init__(self, parent)
        self.line = QString()
        self.lines = []
        self.history = []
        self.point = self.more = self.reading = self.pointer = self.pos = 0
        self.setupInterp()
        self.setupUi()
        self.setupShellFont()
        self.readShellHistory()
        self.writeBanner()
        self.connect(QApplication.instance(), Signals.lastWindowClosed,
                     self.writeShellHistory)
        self.connect(self.window(), Signals.settingsChanged,
                     self.setupShellFont)
        self.requestSession()
        self.setupFinal()

    def setSession(self, session):
        self.interp.update(session=session)

    def setupInterp(self):
        self.interp = PythonInterpreter(output=sys.stderr, parent=self)
        self.interp.update(
            shell=self,
            quit=self.eofPrompt,
            exit=self.eofPrompt,
            app=QApplication.instance(),
            main=self.window(),
        )


    def setupFinal(self):
        settings = Settings()
        settings.beginGroup(settings.keys.main)
        filename = settings.value('startupScript').toString()
        if not filename or not self.parent():
            return
        try:
            script = file(filename, 'r')
        except (IOError, ), ex:
            pass
        else:
            try:
                for line in script.readlines():
                    self.interp.runsource(line)
            except (SyntaxError, ValueError , OverflowError), ex:
                print 'Compiling code in startup script failed: %s' % (ex, )
            except (Exception ,), ex:
                print 'Startup script failure (non-compile): %s' % (ex, )

    def setupShellFont(self):
        settings = Settings()
        settings.beginGroup(settings.keys.appearance)
        font = settings.value('shellFont', QFont())
        self.setFont(QFont(font))

    def setupUi(self):
        self.setLineWrapMode(self.NoWrap)
        self.setUndoRedoEnabled(False) ## big performance hit otherwise

    def flush(self):
        pass

    def writeBanner(self):
        self.setText('')
        self.write(str.join('', self.introText + (self.ps1, )))

    def readShellHistory(self):
        self.historyName = name = expanduser(self.historyName)
        if exists(name):
            hist = open(name, 'r')
            lines = [line.strip() for line in hist.readlines()]
            self.history.extend([QString(line) for line in lines if line])
            hist.close()
        else:
            try:
                hist = open(name, 'w')
                hist.close()
            except (IOError, ), exc:
                pass
                #sys.__stdout__.write('%s\n' % (exc, ))

    def writeShellHistory(self):
        try:
            history = [str(hl) for hl in self.history[-self.maxHistory:]]
            history = [hl.strip() for hl in history if hl.strip()]
            history = ['%s\n' % (hl, ) for hl in history if hl]
            histfile = open(self.historyName, 'w')
            histfile.writelines(history)
            histfile.close()
        except (Exception, ), exc:
            pass
            #sys.__stdout__.write('%s\n' % (exc, ))

    def write(self, text):
        cursor = self.textCursor()
        cursor.movePosition(QTextCursor.End)
        cursor.insertText(text)
        self.pos = cursor.position()
        self.setTextCursor(cursor)
        self.ensureCursorVisible()

    def run(self):
        self.pointer = 0
        linestr = str(self.line)
        if linestr:
            self.history.append(QString(linestr))
        self.lines.append(linestr)
        source = str.join('\n', self.lines)
        try:
            self.more = self.interp.runsource(source)
        except (SystemExit, ):
            print Exception('SystemExit attempted but not allowed')
            self.more = None
        if self.more:
            self.write(self.ps2)
        else:
            self.write(self.ps1)
            self.lines = []
        self.clearLine()

    def runLines(self, lines):
        event = QKeyEvent(QKeyEvent.KeyPress, Qt.Key_Return, Qt.NoModifier)
        for line in lines:
            self.lines.append(line+"\n")
            self.keyPressEvent(event)
        self.run()


    def clearLine(self):
        self.point = 0
        self.line.truncate(0)

    def insertPlainText(self, text):
        cursor = self.textCursor()
        cursor.insertText(text)
        self.line.insert(self.point, text)
        self.point += text.length()

    def keyPressEvent(self, e):
        key, text, mods  = e.key(), e.text(), e.modifiers()
        cursor = self.textCursor()
        control = (mods & Qt.ControlModifier)

        if control:
            if key==Qt.Key_L:
                self.clear()
                self.run()
            elif key==Qt.Key_C:
                self.copy()
            elif key==Qt.Key_V:
                self.paste()
            elif key==Qt.Key_D:
                self.write(self.eofPrompt + '\n')
                self.run()
            elif key==Qt.Key_A:
                self.point = 0
                cursor.setPosition(self.pos)
                self.setTextCursor(cursor)
            elif key==Qt.Key_E:
                self.point = self.line.length()
                self.moveCursor(QTextCursor.EndOfLine)
            return
        elif key in (Qt.Key_Return, Qt.Key_Enter):
            self.write('\n')
            self.run()
        elif key==Qt.Key_Tab:
            self.insertPlainText(text)
        elif key==Qt.Key_Backspace and self.point:
            cursor.movePosition(QTextCursor.PreviousCharacter, QTextCursor.KeepAnchor)
            cursor.removeSelectedText()
            self.point -= 1
            self.line.remove(self.point, 1)
        elif key==Qt.Key_Delete:
            cursor.movePosition(QTextCursor.NextCharacter, QTextCursor.KeepAnchor)
            cursor.removeSelectedText()
            self.line.remove(self.point, 1)
        elif key==Qt.Key_Left and self.point:
            self.point -= 1
            self.moveCursor(QTextCursor.Left)
        elif key==Qt.Key_Right and (self.point < self.line.length()):
            self.point += 1
            self.moveCursor(QTextCursor.Right)
        elif key==Qt.Key_Home:
            cursor.setPosition(self.pos)
            self.point = 0
            self.setTextCursor(cursor)
        elif key==Qt.Key_End:
            self.point = self.line.length()
            self.moveCursor(QTextCursor.EndOfLine)
        elif key==Qt.Key_Up and self.history:
            if self.pointer==0:
                self.pointer = len(self.history)
            self.pointer -= 1
            self.recall()
        elif key==Qt.Key_Down and self.history:
            self.pointer += 1
            if self.pointer==len(self.history):
                self.pointer = 0
            self.recall()
        elif text.length():
            self.insertPlainText(text)
        else:
            e.ignore()

    def recall(self):
        cursor = self.textCursor()
        cursor.select(QTextCursor.LineUnderCursor)
        cursor.removeSelectedText()
        if self.more:
            self.write(self.ps2)
        else:
            self.write(self.ps1)
        self.clearLine()
        self.insertPlainText(self.history[self.pointer])

    def __mousePressEvent(self, e):
        if e.button() == Qt.LeftButton:
            self.moveCursor(QTextCursor.End)

    def canInsertFromMimeData(self, source):
        return source.hasText()

    def insertFromMimeData(self, source):
        for line in str(source.text()).split('\n'):
            self.line = QString(line)
            self.write(self.line+'\n')
            self.run()

    def clear(self):
        self.setPlainText('')


class MultiCast(list):
    """ MultiCast() -> multiplexes messages to registered objects

        MultiCast is based on Multicast by Eduard Hiti (no license stated):
        http://aspn.activestate.com/ASPN/Cookbook/Python/Recipe/52289
    """
    def __init__(self, *items):
        list.__init__(self)
        self.extend(items)

    def __call__(self, *args, **kwargs):
        """ x.__call__(...) <==> x(...)

        map object calls to result as a MultiCast
        """
        itemreturns = [obj(*args, **kwargs) for obj in self]
        return self.__class__(*itemreturns)

    def __getattr__(self, name):
        """ x.__getattr__('name') <==> x.name

        returns attribute wrapper for further processing
        """
        attrs = [getattr(obj, name) for obj in self]
        return self.__class__(*attrs)

    def __nonzero__(self):
        """ x.__nonzero__() <==> x != 0

        logically true if all delegate values are logically true
        """
        return bool(reduce(lambda a, b: a and b, self, 1))


if not isinstance(sys.stdout, MultiCast):
    sys.stdout = MultiCast(sys.stdout)

if not isinstance(sys.stderr, MultiCast):
    sys.stderr = MultiCast(sys.stderr)



if __name__ == '__main__':
    app = QApplication(sys.argv)
    window = PythonShell(parent=None)
    window.setStdOutErr(stdout=sys.__stdout__, stderr=sys.__stderr__)
    window.show()
    sys.exit(app.exec_())
