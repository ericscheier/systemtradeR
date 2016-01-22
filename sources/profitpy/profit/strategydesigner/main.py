#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

from cPickle import dump, load
from os.path import split

from PyQt4.QtCore import QVariant, Qt, pyqtSignature
from PyQt4.QtGui import QApplication, QComboBox
from PyQt4.QtGui import QDoubleSpinBox, QFileDialog, QIcon, QImageReader
from PyQt4.QtGui import QLabel, QMainWindow, QMessageBox
from PyQt4.QtGui import QSizePolicy, QSpinBox, QStandardItem
from PyQt4.QtGui import QStandardItemModel, QToolBar

from profit import series
from profit.lib import defaults
from profit.lib import Settings, Signals
from profit.lib.widgets.syspathdialog import SysPathDialog
from profit.strategydesigner.treeitems import (
    CallableItem, TickerItem, FieldItem, IndexItem, RunnerItem)
from profit.strategydesigner.widgets.ui_strategydesigner import Ui_StrategyDesigner

from ib.ext.TickType import TickType


def itemSenderPropMatchMethod(name):
    @pyqtSignature('bool')
    def method(self, checked):
        item = self.editItem
        sender = self.sender()
        if item and sender and checked:
            setattr(item, name, str(sender.property(name).toString()))
            self.emit(Signals.modified)
    return method


def itemEditedNameMatchMethod():
    def method(self, text):
        item = self.editItem
        if item:
            item.setText(text)
            self.emit(Signals.modified)
    return method


def fieldTypes():
    """ Creates mapping of ticker data fields to field names.

    @return field to field name mapping
    """
    items = [(k, getattr(TickType, k)) for k in dir(TickType)]
    items = [(k, v) for k, v in items if isinstance(v, int)]
    unknown = TickType.getField(-1)
    items = [(v, TickType.getField(v)) for k, v in items]
    return dict([(k, v) for k, v in items if v != unknown])


def indexTypes():
    """ Creates mapping of index class names to index types.

    @return index class name to index class mapping.
    """
    def isIndexType(obj):
        return hasattr(obj, 'params')
    items = [(k, getattr(series, k)) for k in dir(series)]
    return dict([(k, v) for k, v in items if isIndexType(v)])


class LocalIndexLabel(QLabel):
    def __init__(self, text, parent):
        QLabel.__init__(self, text, parent)
        self.setAlignment(Qt.AlignRight|Qt.AlignTrailing|Qt.AlignVCenter)
        sp = QSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)
        self.setSizePolicy(sp)


class StrategyDesigner(QMainWindow, Ui_StrategyDesigner):
    """ Ticker Designer main window class.

    """
    defaultText = 'Unknown'
    itemTypePages = {
        TickerItem:1, FieldItem:2, IndexItem:3, CallableItem:4, RunnerItem:5}

    def __init__(self, parent=None, filename=None):
        """ Constructor.

        @param parent ancestor of this widget
        """
        QMainWindow.__init__(self, parent)
        self.setupUi(self)
        self.editItem = None
        self.clipItem = None
        self.savedStrategy = None
        self.strategyFile = None
        self.setupWidgets()
        self.readSettings()
        if filename:
            self.on_actionOpenStrategy_triggered(filename)
        else:
            self.resetWindowTitle()
        self.connect(
            self, Signals.strategy.fileUpdated,
            QApplication.instance(), Signals.strategy.fileUpdated)

    # index parameter and documentation group methods

    def setupIndexItemParamWidgets(self, cls, item):
        """ Rebuilds the index parameter group widgets.

        @param cls index class object
        @param item IndexItem instance
        @return None
        """
        parent = self.indexParamGroup
        layout = parent.layout().children()[0]
        parent.setVisible(bool(cls.params))
        for row, (name, props) in enumerate(cls.params):
            label = LocalIndexLabel(name, parent)
            builder = getattr(
                self, '%sEditor' % props.get('type', 'unknown'),
                self.unknownEditor)
            layout.addWidget(label, row, 0)
            layout.addWidget(builder(name, item, props, parent), row, 1)

    def setupIndexItemDocWidgets(self, cls):
        """ Rebuilds the index parameter documentation widgets.

        @param cls index class object or None
        @return None
        """
        doc = '' if not cls else (cls.__doc__ or '').strip()
        self.indexParamDoc.setText(doc)
        self.indexDocGroup.setVisible(bool(doc))

    def resetIndexWidgets(self):
        """ Removes parameter group widgets, hides parameter and doc groups.

        @return None
        """
        self.setupIndexItemDocWidgets(None)
        group = self.indexParamGroup
        layout = group.layout().children()[0]
        child = layout.takeAt(0)
        while child:
             child.widget().deleteLater()
             child = layout.takeAt(0)
        group.setVisible(False)

    # parameter editor widget builder methods

    def spinEditor(self, cls, name, item, props, parent):
        """ Creates a new editor suitable for integer values.

        @param cls widget type, either QSpinBox or QDoubleSpinBox
        @param name item parameter name, as string, to receive value updates
        @param item IndexItem instance
        @param props mapping of index class constructor properties
        @param parent ancestor of new widget
        @return QSpinBox or QDoubleSpinBox widget
        """
        editor = cls(parent)
        editor.setButtonSymbols(editor.PlusMinus)
        editor.setAlignment(Qt.AlignRight)
        try:
            editor.setMinimum(props['min'])
        except (KeyError, ):
            pass
        try:
            editor.setValue(props['default'])
        except (KeyError, ):
            pass
        try:
            editor.setValue(item.parameters[name])
        except (KeyError, ):
            item.parameters[name] = editor.value()
        def onChange(value):
            item.parameters[name] = value
            self.emit(Signals.modified)
        editor.onChange = onChange
        return editor

    def intEditor(self, name, item, props, parent):
        """ Creates a new editor suitable for integer values.

        @param name item parameter name, as string, to receive value updates
        @param item IndexItem instance
        @param props mapping of index class constructor properties
        @param parent ancestor of new widget
        @return QSpinBox widget
        """
        editor = self.spinEditor(QSpinBox, name, item, props, parent)
        editor.connect(editor, Signals.intValueChanged, editor.onChange)
        return editor

    def floatEditor(self, name, item, props, parent):
        """ Creates a new editor suitable for float values.

        @param name item parameter name, as string, to receive value updates
        @param item IndexItem instance
        @param props mapping of index class constructor properties
        @param parent ancestor of new widget
        @return QDoubleSpinBox widget
        """
        editor = self.spinEditor(
            QDoubleSpinBox, name, item, props, parent)
        editor.setSingleStep(0.01)
        editor.connect(editor, Signals.doubleValueChanged, editor.onChange)
        return editor

    def lineEditor(self, name, item, props, parent):
        """ Creates a new editor suitable for selecting a series or index.

        @param name item parameter name, as string, to receive value updates
        @param item IndexItem instance
        @param props mapping of index class constructor properties
        @param parent ancestor of new widget
        @return QComboBox widget
        """
        children = list(item.root().children(True))
        editor = QComboBox(parent)
        editor.addItem('')
        exclude = [item.text(), self.defaultText]
        items = [c.text() for c in children if c.text() not in exclude]
        editor.addItems(items)
        try:
            editor.setCurrentIndex(editor.findText(item.parameters[name]))
        except (KeyError, ):
            item.parameters[name] = ''
        @pyqtSignature('int')
        def onChange(index):
            item.parameters[name] = str(editor.currentText())
            self.emit(Signals.modified)
        editor.onChange = onChange
        editor.connect(editor, Signals.currentIndexChanged, onChange)
        return editor

    def unknownEditor(self, name, item, props, parent):
        """ Creates a new display widget for an unknown parameter type.

        @param name item parameter name, as string, to receive value updates
        @param item IndexItem instance
        @param props mapping of index class constructor properties
        @param parent ancestor of new widget
        @return QLabel widget
        """
        editor = QLabel('unknown type', parent)
        return editor

    # ordinary methods

    def addStrategyItem(self, data):
        """ Adds an item at the root

        """
        try:
            hasExec = data['execType']
            return self.addRunnerItem(data)
        except (KeyError, ):
            pass
        try:
            hasTickerId = data['tickerId']
            return self.addTickerItem(data)
        except (KeyError, ):
            pass
        raise NotImplemented(str(data))

    def addRunnerItem(self, schema):
        item = RunnerItem.fromSchema(schema)
        item.setIcon(self.actionInsertRunner.icon())
        self.model.appendRow(item)
        return item

    def addTickerItem(self, schema):
        item = TickerItem.fromSchema(schema)
        item.loadIcon(self.settings)
        self.model.appendRow(item)
        return item

    def checkClose(self):
        """ Prompts user for next action if schema is modified.

        @return True if schema can be closed
        """
        check = True
        if self.isWindowModified():
            buttons = QMessageBox.Save|QMessageBox.Discard|QMessageBox.Cancel
            msg = QMessageBox.question(
                self, self.initialTitle, 'This schema has been modified.\n'
                'Do you want to save your changes?', buttons,
                QMessageBox.Save)
            if msg == QMessageBox.Discard:
                pass
            elif msg == QMessageBox.Cancel:
                check = False
            elif msg == QMessageBox.Save:
                self.actionSaveStrategy.trigger()
        return check

    def checkModified(self):
        """ Sets the window modified flag if the schema has changed.

        @return None
        """
        self.setWindowModified(self.savedStrategy != self.schema)

    def closeEvent(self, event):
        """ Framework close event handler.  Writes settings and accepts event.

        @param event QCloseEvent instance
        @return None
        """
        if self.checkClose():
            self.writeSettings()
            event.accept()
        else:
            event.ignore()

    def enableActions(self, index):
        """ Enables or disables edit and design actions.

        @param index QModelIndex instance or None
        @return None
        """
        up = down = paste = False
        typeactions = [
            (IndexItem, self.actionInsertIndex),
            (FieldItem, self.actionInsertField),
            (CallableItem, self.actionInsertCallable), ]
        if index and index.isValid():
            model = index.model()
            up = model.sibling(index.row()-1, 0, index).isValid()
            down = model.sibling(index.row()+1, 0, index).isValid()
            item = model.itemFromIndex(index)
            clip = self.clipItem
            paste = item.canPaste(type(clip))
            if clip and clip.cutSource and clip == item:
                paste = False
            for typeobj, action in typeactions:
                action.setEnabled(item.canPaste(typeobj))
        else:
            for typeobj, action in typeactions:
                action.setEnabled(False)
        self.actionMoveUp.setEnabled(up)
        self.actionMoveDown.setEnabled(down)
        self.actionPaste.setEnabled(paste)

    def moveItem(self, item, offset):
        """ Moves item up or down schema tree.

        @param item SchemaItem instance to move.
        @param offset -1 to move up, 1 to move down
        @return None
        """
        model = self.model
        index = model.indexFromItem(item)
        tree = self.treeView
        tree.collapse(index)
        row = index.row()
        otherindex = index.sibling(row+offset, 0)
        tree.collapse(otherindex)
        other = model.itemFromIndex(otherindex)
        parent = item.parent()
        if not parent:
            parent = model.invisibleRootItem()
        parent.takeChild(row+offset, 0)
        parent.takeChild(row, 0)
        parent.setChild(row+offset, item)
        parent.setChild(row, other)
        newindex = model.indexFromItem(item)
        selectmodel = tree.selectionModel()
        selectmodel.clear()
        selectmodel.select(newindex, selectmodel.Select)
        self.enableActions(newindex)
        self.emit(Signals.modified)

    def readSettings(self):
        """ Applies stored setting values to instance.

        @return None
        """
        self.settings = obj = Settings()
        obj.beginGroup(obj.keys.designer)
        self.resize(obj.value(obj.keys.size, defaults.windowSize).toSize())
        self.move(obj.value(
            obj.keys.position, defaults.windowPosition).toPoint())
        if obj.value(obj.keys.maximized, False).toBool():
            self.showMaximized()
        self.restoreState(
            obj.value(obj.keys.winstate, QVariant()).toByteArray())
        self.splitter.restoreState(
            obj.value(obj.keys.splitstate, QVariant()).toByteArray())

    def updateLines(self, item, previous, current):
        """ Modifies line references in response to a new line name.

        @param item changed FieldItem or IndexItem instance
        @param previous old line name
        @param current new line name
        @return count of modified references
        """
        modified = 0
        if item:
            previous, current = str(previous), str(current)
            def pred(obj):
                return obj != item and hasattr(obj, 'parameters')
            for child in [c for c in item.root().children(True) if pred(c)]:
                for key, value in child.parameters.items():
                    if value == previous:
                        child.parameters[key] = current
                        modified += 1
        if modified:
            self.emit(Signals.modified)
        return modified

    def resetStrategy(self):
        """ Clears the schema model and resets the window widgets.

        @return None
        """
        self.model.clear()
        self.strategyFile = None
        self.resetWindowTitle()
        self.setWindowModified(False)
        self.controlStack.setCurrentIndex(0)
        self.enableActions(None)

    def resetWindowTitle(self):
        """ Sets window title to account for schema filename, if any.

        @return None
        """
        name = self.strategyFile
        if name:
            title = '%s - %s[*]' % (self.initialTitle, split(name)[1])
        else:
            title = '%s - unnamed[*]' % (self.initialTitle, )
        self.setWindowTitle(title)

    def schema(self):
        """ Constructs and returns ticker schema.

        @return schema as list of dictionaries.
        """
        root = self.model.invisibleRootItem()
        return [root.child(row).toSchema() for row in range(root.rowCount())]

    def setupRunnerItem(self, item):
        self.runnerName.setText(item.text())
        self.runnerMessageHandler.setChecked(
            Qt.Checked if item.execType=='message' else Qt.Unchecked)
        self.runnerThread.setChecked(
            Qt.Checked if item.execType=='thread' else Qt.Unchecked)
        self.runnerSingleShot.setChecked(
            Qt.Checked if item.execType=='single' else Qt.Unchecked)
        self.runnerPeriodInterval.setValue(item.periodInterval)

    def setupCallableItem(self, item):
        self.callableName.setText(item.text())
        editor = self.callableEditor
        modified = Signals.modified
        self.disconnect(editor, modified, self, modified)
        def revert():
            return item.moduleSource
        def save(src):
            item.moduleSource = editor.sourceText
        editor.basicSetup(
            callType=item.callType,
            locationText=item.callLocation,
            sourceText=item.moduleSource,
            revertSource=revert,
            saveSource=save,
            disableFileType=True)
        self.connect(editor, modified, self, modified)

    def setupTickerItem(self, item):
        """ Configures ticker page widgets from given item.

        @param item TickerItem instance
        @return None
        """
        self.idSpin.setValue(item.tickerId)
        self.symbolEdit.setText(item.symbol)
        combo = self.secTypeCombo
        combo.setCurrentIndex(combo.findText(item.secType))
        self.exchangeEdit.setText(item.exchange)
        self.iconPreview.setPixmap(item.icon().pixmap(32, 32))
        self.expiryEdit.setText(item.expiry)
        self.strikeSpin.setValue(item.strike)
        self.currencyEdit.setText(item.currency)
        combo = self.rightCombo
        combo.setCurrentIndex(combo.findText(item.right))

    def setupFieldItem(self, item):
        """ Configures field page widgets from given item.

        @param item FieldItem instance
        @return None
        """
        combo = self.fieldCombo
        combo.setCurrentIndex(combo.findData(QVariant(item.id)))

    def setupIndexItem(self, item):
        """ Configures index page widgets from given item.

        @param item IndexItem instance
        @return None
        """
        self.indexName.setText(item.text())
        combo = self.indexCombo
        index = combo.findData(QVariant(item.indexType))
        combo.setCurrentIndex(index)
        data = self.indexCombo.itemData(index)
        if data.isValid():
            name = str(data.toString())
            self.resetIndexWidgets()
            try:
                cls = indexTypes()[name]
            except (KeyError, ):
                pass
            else:
                self.setupIndexItemParamWidgets(cls, item)
                self.setupIndexItemDocWidgets(cls)

    def setupWidgets(self):
        """ Configures window widgets for initial display.

        @return None
        """
        self.model = QStandardItemModel(self)
        self.treeView.setModel(self.model)
        self.treeView.header().hide()
        self.initialTitle = self.windowTitle()
        self.connect(self, Signals.modified, self.checkModified)
        for toolbar in self.findChildren(QToolBar):
            self.menuToolbars.addAction(toolbar.toggleViewAction())
        self.indexCombo.addItem('<none>', QVariant())
        for name in sorted(indexTypes()):
            self.indexCombo.addItem(name, QVariant(name))
        self.fieldCombo.addItem('<none>', QVariant())
        for id, name in sorted(fieldTypes().items()):
            self.fieldCombo.addItem(name, QVariant(id))
        self.runnerMessageHandler.setProperty(
            'execType', QVariant('message'))
        self.runnerSingleShot.setProperty(
            'execType', QVariant('single'))
        self.runnerThread.setProperty(
            'execType', QVariant('thread'))

    def showMessage(self, text, duration=3000):
        """ Displays text in the window status bar.

        @param text message to display
        @param duration=3000 time to display message in milliseconds
        @return None
        """
        self.statusBar().showMessage(text, duration)

    def readStrategy(self, schema, filename):
        """ Creates tree items from given schema.

        @param schema ticker schema as dictionary
        @return None
        """
        try:
            for data in schema:
                self.addStrategyItem(data)
        except (Exception, ), ex:
            print '##', ex
            QMessageBox.warning(self, 'Warning', 'Unable to read schema.')
            self.resetStrategy()
        else:
            self.savedStrategy = schema
            self.strategyFile = filename
            self.resetWindowTitle()
            self.treeView.expandAll()
            root = self.model.invisibleRootItem()
            items = [root.child(row) for row in range(root.rowCount())]
            for item in items:
                for c in item.children(True):
                    self.resetIcon(c)

    def resetIcon(self, item):
        icons = {
            FieldItem:self.actionInsertField,
            IndexItem:self.actionInsertIndex,
            CallableItem:self.actionInsertCallable,
        }
        typ = type(item)
        try:
            action = icons[typ]
        except (KeyError, ):
            pass
        else:
            item.setIcon(action.icon())

    def writeSettings(self):
        """ Saves window settings and state.

        @return None
        """
        settings = self.settings
        settings.setValue(settings.keys.size, self.size())
        settings.setValue(settings.keys.position, self.pos())
        settings.setValue(settings.keys.maximized, self.isMaximized())
        settings.setValue(settings.keys.winstate, self.saveState())
        settings.setValue(settings.keys.splitstate, self.splitter.saveState())

    def maybeChangeIndexName(self, item, previous):
        """ Changes index name if appropriate.

        @param item IndexItem instance
        @param previous last index type name
        @return None
        """
        widget = self.indexName
        current = str(widget.text())
        include = [self.defaultText, '']
        if current in include or current.startswith('%s-' % previous):
            flags = Qt.MatchStartsWith | Qt.MatchRecursive
            matches = self.model.findItems(item.indexType, flags)
            suffix = 1
            for match in matches:
                if item.root() == match.root():
                    try:
                        name = str(match.text())
                        offset = int(name.split('-')[1])
                    except (ValueError, IndexError, ), ex:
                        pass
                    else:
                        suffix = max(suffix, offset+1)
            widget.setText('%s-%s' % (item.indexType, suffix))
            self.emit(Signals.modified)

    # widget signal handlers

    def on_currencyEdit_textEdited(self, text):
        """ Signal handler for ticker currency line edit widget text changes.

        @param text new value for line edit
        @return None
        """
        item = self.editItem
        if item:
            item.currency = str(text)
            self.emit(Signals.modified)

    def on_exchangeEdit_textEdited(self, text):
        """ Signal handler for exchange line edit widget text changes.

        @param text new value for line edit
        @return None
        """
        if self.editItem:
            self.editItem.exchange = str(text)
            self.emit(Signals.modified)

    def on_expiryEdit_textEdited(self, text):
        """ Signal handler for ticker expiry line edit widget text changes.

        @param text new value for line edit
        @return None
        """
        item = self.editItem
        if item:
            item.expiry = str(text)
            self.emit(Signals.modified)

    @pyqtSignature('int')
    def on_fieldCombo_currentIndexChanged(self, index):
        """ Signal handler for field type combobox selection changes.

        @param index selected item index
        @return None
        """
        item = self.editItem
        if item:
            data = self.fieldCombo.itemData(index)
            if data.isValid():
                fid = data.toInt()[0]
                if fid in [other.id for other in item.siblings()]:
                    self.showMessage('Duplicate ticker fields not allowed.')
                    self.fieldCombo.setCurrentIndex(0)
                    return
                old = item.text()
                try:
                    new = fieldTypes()[fid]
                    item.setText(new)
                except (KeyError, ):
                    pass
                else:
                    item.id = fid
                    if not self.updateLines(item, old, new):
                        self.emit(Signals.modified)
            else:
                self.emit(Signals.modified)

    @pyqtSignature('')
    def on_iconSelect_clicked(self):
        """ Signal handler for select icon button.

        @return None
        """
        item = self.editItem
        if item:
            formats = str.join(' ', ['*.%s' % str(fmt) for fmt in
                                     QImageReader.supportedImageFormats()])
            filename = QFileDialog.getOpenFileName(
                self, 'Select Symbol Icon', '', 'Images (%s)' % formats)
            if filename:
                icon = QIcon(filename)
                item.setIcon(icon)
                self.iconPreview.setPixmap(icon.pixmap(32,32))
                settings = self.settings
                settings.setValue('%s/icon' % item.symbol, icon)
                self.emit(Signals.modified)

    @pyqtSignature('int')
    def on_idSpin_valueChanged(self, value):
        """ Signal handler for ticker id spin box changes.

        @param value new value of spinbox
        @return None
        """
        item = self.editItem
        if item:
            item.tickerId = value
            self.emit(Signals.modified)

    @pyqtSignature('int')
    def on_indexCombo_currentIndexChanged(self, index):
        """ Signal handler for index type combobox selection changes.

        @param index selected item index
        @return None
        """
        self.resetIndexWidgets()
        item = self.editItem
        if item:
            data = self.indexCombo.itemData(index)
            if data.isValid():
                indexType = str(data.toString())
                try:
                    cls = indexTypes()[indexType]
                except (KeyError, ):
                    pass
                else:
                    old = item.indexType
                    item.indexType = indexType
                    self.setupIndexItemParamWidgets(cls, item)
                    self.setupIndexItemDocWidgets(cls)
                    self.maybeChangeIndexName(item, old)
                    self.emit(Signals.modified)

    def on_indexName_textChanged(self, text):
        """ Signal handler for index name line edit widget changes.

        @param text new value for line edit
        @return None
        """
        try:
            old = self.indexName.oldText
        except (AttributeError, ):
            old = self.indexName.oldText = ''
        renamed = self.updateLines(self.editItem, old, text)
        self.indexName.oldText = str(text)
        if self.editItem:
            self.editItem.setText(text)
            if not renamed:
                self.emit(Signals.modified)

    @pyqtSignature('int')
    def on_rightCombo_currentIndexChanged(self, index):
        """ Signal handler for security right combobox selection changes.

        @param index selected item index
        @return None
        """
        item = self.editItem
        if item:
            item.right = str(self.rightCombo.currentText())
            self.emit(Signals.modified)

    @pyqtSignature('int')
    def on_secTypeCombo_currentIndexChanged(self, index):
        """ Signal handler for security type combobox selection changes.

        @param index selected item index
        @return None
        """
        item = self.editItem
        if item:
            item.secType = str(self.secTypeCombo.currentText())
            self.emit(Signals.modified)

    @pyqtSignature('double')
    def on_strikeSpin_valueChanged(self, value):
        """ Signal handler for ticker strike price spin box changes.

        @param value new value of spinbox
        @return None
        """
        item = self.editItem
        if item:
            item.strike = value
            self.emit(Signals.modified)

    def on_symbolEdit_textEdited(self, text):
        """ Signal handler for symbol name line edit widget changes.

        @param text new value for line edit
        @return None
        """
        item = self.editItem
        if item:
            item.symbol = str(text)
            item.setText(text)
            item.loadIcon(self.settings)
            self.iconPreview.setPixmap(item.icon().pixmap(32, 32))
            self.emit(Signals.modified)

    def on_treeView_clicked(self, index):
        """ Signal handler for schema tree mouse click.

        @param index QModelIndex instance
        @return None
        """
        self.enableActions(index)
        item = self.model.itemFromIndex(index)
        itemtype = type(item)
        try:
            pageindex = self.itemTypePages[itemtype]
        except (KeyError, ):
            pass
        else:
            self.controlStack.setCurrentIndex(pageindex)
            setup = getattr(self, 'setup%s' % itemtype.__name__, None)
            if setup:
                try:
                    self.editItem = None
                    setup(item)
                finally:
                    self.editItem = item

    # action signal handlers

    @pyqtSignature('')
    def on_actionCloseStrategy_triggered(self):
        """ Signal handler for close action.

        @return None
        """
        if self.checkClose():
            self.resetStrategy()

    @pyqtSignature('')
    def on_actionCopy_triggered(self):
        """ Signal handler for copy action.

        @return None
        """
        if not self.actionCopy.isEnabled():
            return
        if self.clipItem:
            self.clipItem.resetForeground()
        self.clipItem = self.editItem
        self.clipItem.setCopy()

    @pyqtSignature('')
    def on_actionCut_triggered(self):
        """ Signal handler for cut action.

        @return None
        """
        if self.editItem:
            if self.clipItem:
                self.clipItem.resetForeground()
            self.clipItem = self.editItem
            self.clipItem.setCut()

    @pyqtSignature('')
    def on_actionDelete_triggered(self):
        """ Signal handler for item delete action; removes item from tree.

        @return None
        """
        item = self.editItem
        if item:
            if item is self.clipItem:
                self.clipItem = None
            self.editItem = None
            index = self.model.indexFromItem(item)
            self.model.removeRow(index.row(), index.parent())
            self.enableActions(None)
            self.treeView.selectionModel().clear()
            self.controlStack.setCurrentIndex(0)
            self.emit(Signals.modified)

    @pyqtSignature('')
    def on_actionInsertRunner_triggered(self):
        self.addRunnerItem({})
        self.emit(Signals.modified)

    @pyqtSignature('')
    def on_actionInsertCallable_triggered(self):
        if self.editItem:
            item = CallableItem.fromSchema()
            item.setIcon(self.actionInsertCallable.icon())
            self.editItem.appendRow(item)
            self.treeView.expand(item.parent().index())
            self.emit(Signals.modified)

    @pyqtSignature('')
    def on_actionInsertTicker_triggered(self):
        """ Signal handler for insert ticker action; adds ticker item to tree.

        @return None
        """
        tickerId = 1
        root = self.model.invisibleRootItem()
        items = [root.child(r, 0) for r in range(root.rowCount())]
        if items:
            tickerId += max([getattr(i, 'tickerId', 0) for i in items])
        self.addTickerItem(dict(tickerId=tickerId, symbol=''))
        self.emit(Signals.modified)

    @pyqtSignature('')
    def on_actionInsertField_triggered(self):
        """ Signal handler for insert field action; adds field item to tree.

        @return None
        """
        if self.editItem:
            item = FieldItem.fromSchema()
            item.setIcon(self.actionInsertField.icon())
            self.editItem.appendRow(item)
            self.treeView.expand(item.parent().index())
            self.emit(Signals.modified)

    @pyqtSignature('')
    def on_actionInsertIndex_triggered(self):
        """ Signal handler for insert index action; adds index item to tree.

        """
        if self.editItem:
            item = IndexItem.fromSchema()
            item.setIcon(self.actionInsertIndex.icon())
            self.editItem.appendRow(item)
            self.treeView.expand(item.parent().index())
            self.emit(Signals.modified)

    @pyqtSignature('')
    def on_actionMoveDown_triggered(self):
        """ Signal handler for item move down action; moves item down tree.

        @return None
        """
        item = self.editItem
        if item:
            self.moveItem(item, 1)

    @pyqtSignature('')
    def on_actionMoveUp_triggered(self):
        """ Signal handler for item move up action; moves item up tree.

        @return None
        """
        item = self.editItem
        if item:
            self.moveItem(item, -1)

    @pyqtSignature('')
    def on_actionNewStrategy_triggered(self):
        """ Signal handler for new schema action.

        @return None
        """
        if self.checkClose():
            self.resetStrategy()

    @pyqtSignature('')
    def on_actionOpenStrategy_triggered(self, filename=None):
        """ Signal handler for open schema action.

        @return None
        """
        if self.checkClose():
            if not filename:
                filename = QFileDialog.getOpenFileName(self, 'Open Strategy')
            if filename:
                filename = str(filename)
                try:
                    handle = open(filename, 'rb')
                except (Exception, ):
                    QMessageBox.warning(
                        self, 'Error', 'IO error reading schema file. ' + filename)
                else:
                    try:
                        schema = load(handle)
                    except (Exception, ):
                        QMessageBox.warning(
                            self, 'Error', 'Unable to read schema file.')
                    else:
                        self.resetStrategy()
                        self.readStrategy(schema, filename)
                    finally:
                        handle.close()

    @pyqtSignature('')
    def on_actionPaste_triggered(self):
        """ Signal handler for paste action.

        @return None
        """
        if not self.actionPaste.isEnabled():
            return
        sourceitem = self.clipItem
        targetitem = self.editItem
        model = self.model
        sourcerow = model.indexFromItem(sourceitem).row()
        sourceparent = sourceitem.parent()
        if sourceitem.cutSource:
            sourceparent.takeChild(sourcerow, 0)
            newchild = sourceitem
        else:
            newchild = sourceitem.clone()
            self.resetIcon(newchild)
            for c in newchild.children():
                self.resetIcon(c)
        targetitem.setChild(targetitem.rowCount(), newchild)
        if sourceitem.cutSource:
            newchild.resetForeground()
            model.removeRow(sourcerow, sourceparent.index())
            self.clipItem = None
        self.treeView.expand(model.indexFromItem(targetitem))
        self.treeView.expand(model.indexFromItem(newchild))
        self.enableActions(model.indexFromItem(targetitem))
        self.emit(Signals.modified)

    @pyqtSignature('')
    def on_actionSaveStrategy_triggered(self):
        """ Signal handler for save schema action.

        @return None
        """
        if not self.strategyFile:
            self.actionSaveStrategyAs.trigger()
        else:
            try:
                handle = open(self.strategyFile, 'wb')
            except (Exception, ):
                QMessageBox.warning(
                    self, 'Error', 'IO error opening file for writing.')
            else:
                try:
                    dump(self.schema(), handle)
                except (Exception, ):
                    QMessageBox.warning(
                        self, 'Error', 'Unable to save schema file.')
                else:
                    self.setWindowModified(False)
                    self.emit(Signals.strategy.fileUpdated, self.strategyFile)
                finally:
                    handle.close()

    @pyqtSignature('')
    def on_actionSaveStrategyAs_triggered(self):
        """ Signal handler for save as action.

        @return None
        """
        filename = QFileDialog.getSaveFileName(self, 'Save Strategy As')
        if filename:
            self.strategyFile = str(filename)
            self.actionSaveStrategy.trigger()
            self.resetWindowTitle()

    # runner editor widget signal handlers

    on_runnerSingleShot_clicked = itemSenderPropMatchMethod('execType')
    on_runnerThread_clicked = itemSenderPropMatchMethod('execType')
    on_runnerMessageHandler_clicked = itemSenderPropMatchMethod('execType')

    on_runnerName_textEdited = itemEditedNameMatchMethod()
    on_callableName_textEdited = itemEditedNameMatchMethod()

    @pyqtSignature('int')
    def on_runnerPeriodInterval_valueChanged(self, value):
        item = self.editItem
        if item:
            item.periodInterval = value
            self.emit(Signals.modified)

    def on_runnerMessageTypes_itemChanged(self, listItem):
        checked = listItem.checkState()==Qt.Checked
        key = str(listItem.text())
        editItem = self.editItem
        if editItem:
            if checked:
                editItem.messageTypes.add(key)
            else:
                editItem.messageTypes.discard(key)
            self.emit(Signals.modified)

    def __on_textEdit_textChanged(self):
        item = self.editItem
        if item:
            item.moduleSource = self.callableEditor.sourceText

    def on_callableLocation_textChanged(self, text):
        item = self.editItem
        if item:
            item.callLocation = self.callableEditor.locationText

    @pyqtSignature('QString')
    def on_callableType_currentIndexChanged(self, text):
        item = self.editItem
        if item:
            calltype = self.callableEditor.callableType.itemData(
                self.callableEditor.callableType.currentIndex()).toString()
            item.callType = str(calltype)

    @pyqtSignature('')
    def on_callableLocationSelect_clicked(self):
        item = self.editItem
        if item:
            current = item.callLocation
            if current != self.callableEditor.locationText:
                item.callLocation = self.callableEditor.locationText

    @pyqtSignature('')
    def on_actionPrintStrategy_triggered(self):
        import pprint
        pprint.pprint(self.schema())


if __name__ == '__main__':
    import sys
    app = QApplication(sys.argv)
    try:
        filename = sys.argv[1]
    except (IndexError, ):
        filename = None
    window = StrategyDesigner(filename=filename)
    window.show()
    sys.exit(app.exec_())
