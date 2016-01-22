#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase <troy@gci.net>
# Distributed under the terms of the GNU General Public License v2

##
#
# This module defines the Plot class for display of plots and
# associated controls.
#
##

from PyQt4.QtCore import QRectF, QString, QTimer, QVariant
from PyQt4.QtCore import Qt, pyqtSignature
from PyQt4.QtGui import QBrush, QColor, QColorDialog, QFont, QFontDialog
from PyQt4.QtGui import QStandardItem, QStandardItemModel, QMenu, QPen, QFrame
from PyQt4.Qwt5 import QwtLegend, QwtPicker, QwtPlot, QwtPlotCurve
from PyQt4.Qwt5 import QwtPlotGrid, QwtPlotPicker, QwtPlotZoomer, QwtPainter
from PyQt4.Qwt5 import QwtPlotMarker, QwtPlotPanner, QwtSymbol, QwtText

from ib.ext.TickType import TickType

from profit.lib import Settings, Signals, defaults
from profit.lib.gui import ValueColorItem, colorIcon, complementColor
from profit.lib.widgets.plotdatadialog import PlotDataDialog
from profit.lib.widgets.plotitemdialog import PlotItemDialog
from profit.lib.widgets.ui_plot import Ui_Plot


allAxes = \
    xBottom, xTop, yRight, yLeft = \
        QwtPlot.xBottom, QwtPlot.xTop, QwtPlot.yRight, QwtPlot.yLeft


def changePen(getr, setr, parent):
    """ Allow the user to change a pen with a PlotItemDialog.

    @param getr callable that returns current pen
    @param setr callable to set selected pen if dialog is accepted
    @param parent ancestor of dialog
    @return new pen if dialog is accepted, otherwise None
    """
    oldpen = getr()
    dlg = PlotItemDialog(oldpen, parent)
    if dlg.exec_() == dlg.Accepted:
        newpen = QPen(dlg.selectedPen)
        setr(newpen)
        return newpen


def changeColor(getr, setr, parent):
    """ Allow the user to change a color with a QColorDialog.

    @param getr callable that returns current color
    @param setr callable to set selected color if dialog is accepted
    @param parent ancestor of dialog
    @return new color if dialog is accepted, otherwise None
    """
    oldcolor = QColor(getr())
    newcolor = QColorDialog.getColor(oldcolor, parent)
    if newcolor.isValid():
        setr(newcolor)
        return newcolor


class PlotCurve(QwtPlotCurve):
    """ Specialized plot curve.

    """
    dataMarker = None
    settingsLoaded = False

    def updateLegend(self, legend, enable=False):
        """ Framework hook to update plot legend with this curve.

        @param legend QwtLegend instance
        @param enable=False must be true to include this curve in legend
        @return None
        """
        if self.isVisible() and enable:
            QwtPlotCurve.updateLegend(self, legend)


class PlotGrid(QwtPlotGrid):
    """ Specalized plot grid.

    QwtPlotGrid instances will not draw their minor grids if the major
    grid is also not enabled.  This class reimplements 'draw' and
    'drawLines' to overcome this limitation.  Code for both was taken
    from the Qwt sources.
    """
    def __init__(self):
        """ Constructor.

        """
        QwtPlotGrid.__init__(self)
        self.enableX(False)
        self.enableY(False)
        self.enableXMin(False)
        self.enableYMin(False)

    def draw(self, painter, mx, my, rect):
        """ Draws minor and major grids.

        @param painter QPainter instance
        @param mx QwtScaleMap instance
        @param my QwtScaleMap instance
        @param rect QRect instance
        @return None
        """
        painter.setPen(self.minPen())
        sdx = self.xScaleDiv()
        sdy = self.yScaleDiv()
        if self.xMinEnabled():
            self.drawLines(
                painter, rect, Qt.Vertical, mx, sdx.ticks(sdx.MinorTick))
            self.drawLines(
                painter, rect, Qt.Vertical, mx, sdx.ticks(sdx.MediumTick))
        if self.yMinEnabled():
            self.drawLines(
                painter, rect, Qt.Horizontal, my, sdy.ticks(sdy.MinorTick))
            self.drawLines(
                painter, rect, Qt.Horizontal, my, sdy.ticks(sdy.MediumTick))
        painter.setPen(self.majPen())
        if self.xEnabled():
            self.drawLines(
                painter, rect, Qt.Vertical, mx, sdx.ticks(sdx.MajorTick))
        if self.yEnabled():
            self.drawLines(
                painter, rect, Qt.Horizontal, my, sdy.ticks(sdy.MajorTick))

    def drawLines(self, painter, rect, orientation, scalemap, values):
        """ Draws specified lines.

        @param painter QPainter instance
        @param rect QRect instance
        @param orientation Qt.Horizontal or Qt.Vertical
        @param scalemap QwtScaleMap instance
        @param values list of x or y values for line drawing
        @return None
        """
        x1 = rect.left()
        x2 = rect.right()
        y1 = rect.top()
        y2 = rect.bottom()
        for v in values:
            value = scalemap.transform(v)
            if orientation == Qt.Horizontal:
                if ((value >= y1) and (value <= y2)):
                    QwtPainter.drawLine(painter, x1, value, x2, value)
            else:
                if ((value >= x1) and (value <= x2)):
                    QwtPainter.drawLine(painter, value, y1, value, y2)


class PlotDataMarker(QwtPlotMarker):
    """ Specialized plot data marker.

    """
    def __init__(self):
        QwtPlotMarker.__init__(self)

    def cloneFromValue(self, curve, x, y):
        """ Creates and returns new plot marker similar to this one.

        @param curve QwtPlotCurve instance
        @param x marker x value
        @param y marker y value
        @return new PlotDataMarker instance
        """
        clone = type(self)()
        clone.setLineStyle(self.lineStyle())
        clone.setLinePen(self.linePen())
        clone.setSymbol(self.symbol())
        clone.setAxis(curve.xAxis(), curve.yAxis())
        clone.setValue(x, y)
        return clone

    def restyleFrom(self, other):
        """ Matches the style of this instance given an example.

        @param other QwtPlotMarker instance
        @return None
        """
        self.setLineStyle(other.lineStyle())
        self.setLinePen(other.linePen())
        self.setSymbol(other.symbol())


class PlotPanner(QwtPlotPanner):
    """ Stub for future implementation.

    """
    def __init__(self, canvas):
        QwtPlotPanner.__init__(self, canvas)
        self.setMouseButton(Qt.MidButton)


class PlotPicker(QwtPlotPicker):
    """ Stub for future implementation.

    """
    def __init__(self, canvas):
        QwtPlotPicker.__init__(
            self, xBottom, yRight, self.NoSelection, self.CrossRubberBand,
            self.AlwaysOn, canvas)

    def trackerText(self, pos):
        pos = self.invTransform(pos)
        band = self.rubberBand()
        if band == self.HLineRubberBand:
            label = '%.3f' % pos.y()
        elif band == self.VLineRubberBand:
            label = '%.3f' % pos.x()
        else:
            label = '%i, %.3f' % (pos.x(), pos.y(), )
        return QwtText(label)


class PlotZoomer(QwtPlotZoomer):
    """ Stub for future implementation.

    """
    def __init__(self, canvas):
        QwtPlotZoomer.__init__(
            self, xBottom, yRight, self.DragSelection, self.AlwaysOff, canvas)


class Legend(QwtLegend):
    """ Stub for future implementation.

    """


class ControlTreeValueItem(QStandardItem, ValueColorItem):
    def __init__(self, text):
        QStandardItem.__init__(self, text)
        self.setEditable(False)
        self.setTextAlignment(Qt.AlignVCenter|Qt.AlignRight)

    def setText(self, text):
        try:
            v = float(self.text())
            c = float(text)
        except (ValueError, ):
            pass
        else:
            if c != v: # explicitly ignore unchanged values
                self.setForeground(self.compMap[cmp(c, v)])
        QStandardItem.setText(self, text)


class ControlTreeItem(QStandardItem):
    """ Self-configuring control tree item.

    """
    def __init__(self, text, data, key, checkable=True):
        """ Constructor.

        @param text value for this item
        @param data reference to data series for this item
        """
        QStandardItem.__init__(self, text)
        if checkable:
            self.setCheckable(True)
            self.setCheckState(Qt.Unchecked)
        self.setEditable(False)
        self.curve = PlotCurve(text)
        self.curve.setYAxis(yRight)
        self.curve.setVisible(False)
        self.data = data
        self.key = key

    def isChecked(self):
        """ True if this item is checked.

        """
        return self.checkState() == Qt.Checked

    def name(self):
        """ Name of item including parent names if any.

        """
        names = []
        while self:
            names.append(getattr(self, 'key', str(self.text())))
            self = self.parent()
        return str.join('/', reversed(names))

    def setColor(self, color):
        """ Sets the icon and color for this item.

        @param color QColor instance
        @return None
        """
        self.color = color
        self.setIcon(colorIcon(color))


class Plot(QFrame, Ui_Plot):
    """ Plot container.

    """
    def __init__(self, parent=None):
        """ Initializer.

        @param parent ancestor of this widget
        """
        QFrame.__init__(self, parent)
        self.setupUi(self)
        self.settings = Settings()
        self.settings.beginGroup(self.settings.keys.plots)
        self.setupOptionsMenu()
        self.setupPlotsMenu()
        self.setupPlot()

    def setupOptionsMenu(self):
        """ Configure the options button menu.

        @return None
        """
        self.dataDialog = None
        optionsButton = self.optionsButton
        pop = QMenu(optionsButton)
        optionsButton.setMenu(pop)
        pop.addAction(self.actionDrawMajorX)
        pop.addAction(self.actionDrawMajorY)
        pop.addAction(self.actionChangeMajorGridStyle)
        pop.addSeparator()
        pop.addAction(self.actionDrawMinorX)
        pop.addAction(self.actionDrawMinorY)
        pop.addAction(self.actionChangeMinorGridStyle)
        pop.addSeparator()
        pop.addAction(self.actionShowDataDialog)
        pop.addAction(self.actionDrawLegend)
        pop.addAction(self.actionChangeCanvasColor)

    def setupPlotsMenu(self):
        """ Configure the plots button menu.

        @return None
        """
        plotButton = self.plotButton
        pop = QMenu(plotButton)
        plotButton.setMenu(pop)
        pop.addAction(self.actionNewPlot)
        pop.addAction(self.actionClosePlot)
        pop.addSeparator()
        pop.addAction(self.actionSyncWithData)

    def setupPlot(self):
        """ Configure the plot widget.

        @return None
        """
        pen = QPen(Qt.black)
        plot = self.plot
        plot.setFrameStyle(plot.NoFrame|plot.Plain)
        plot.insertLegend(Legend(), plot.LeftLegend)
        canvas = plot.canvas()
        canvas.setFrameStyle(plot.NoFrame|plot.Plain)
        layout = plot.plotLayout()
        layout.setCanvasMargin(0)
        layout.setAlignCanvasToScales(True)
        self.grid = PlotGrid()
        self.grid.attach(plot)
        self.panner = PlotPanner(canvas)
        self.zoomer = PlotZoomer(canvas)
        self.zoomer.setRubberBandPen(pen)
        self.picker = PlotPicker(canvas)
        self.picker.setTrackerPen(pen)
        self.connect(self.zoomer, Signals.zoomed, self.on_zoomer_zoomed)
        self.enableAutoScale()

    def setSessionPlot(self, session, collection, key, *indexes):
        """ Associate a session with this instance.

        @param session Session instance
        @param key id of ticker as integer
        @param *indexes unused
        @return None
        """
        self.controlsTreeItems = []
        self.highlightMarkers = []
        self.session = session
        self.collection = collection
        self.key = key
        settings = self.settings
        name = self.plotName()
        statekey = '%s/%s' % (name, settings.keys.splitstate)
        state = settings.value(statekey, defaults.rightSplitterState())
        self.plotSplitter.restoreState(state.toByteArray())
        self.setupTree()
        self.loadGrids()
        self.loadSelections()
        self.loadCanvasColor()
        self.loadLegend()
        self.updateAxis()
        scaler = self.plot.axisScaleEngine(xBottom)
        scaler.setMargins(0.0, 0.05)
        axisactions = [self.actionChangeAxesFont, self.actionChangeAxesColor]
        for widget in self.axisWidgets():
            widget.addActions(axisactions)
            widget.setContextMenuPolicy(Qt.ActionsContextMenu)
        color = settings.value('%s/axiscolor' % name)
        if color.isValid():
            self.setAxisColor(QColor(color))
        font = settings.value('%s/axisfont' % name)
        if font.isValid():
            self.setAxisFont(QFont(font))
        self.plot.replot()
        if settings.value('%s/datadialog' % name).toBool():
            ## tab might not be available
            QTimer.singleShot(500, self.actionShowDataDialog.trigger)
        session.registerMeta(self)

    def setupTree(self):
        """ Configure the model and initial items for this instance.

        @return None
        """
        tree = self.controlsTree
        self.controlsTreeModel = model = QStandardItemModel(self)
        tree.setModel(model)
        model.setHorizontalHeaderLabels(['Line', 'Value'])
        tree.sortByColumn(0, Qt.AscendingOrder)
        try:
            ticker = self.collection[self.key]
        except (KeyError, TypeError, ):
            pass
        else:
            for field, series in ticker.series.items():
                self.addSeries(TickType.getField(field), series)
        self.connect(model, Signals.standardItemChanged,
                     self.on_controlsTree_itemChanged)
        for col in range(model.columnCount()):
            tree.resizeColumnToContents(col)
        tree.addActions(
            [self.actionChangeCurveStyle,
             self.actionChangeDataMarker,
             self.actionChangeCurveAxisX,
             self.actionChangeCurveAxisY,])
        tree.expandAll()

    def addSeries(self, name, series, parent=None, items=[], checkable=True):
        """ Creates new controls and curve for an individual series.

        @param name series key
        @return None
        """
        try:
            name + ()
        except (TypeError, ):
            key = name
        else:
            key = '/'.join(name)
            name = name[0]
        if parent is None:
            parent = self.controlsTreeModel.invisibleRootItem()
        item = ControlTreeItem(name, series, key, checkable=checkable)
        self.controlsTreeItems.append(item)
        if not items:
            items = [ControlTreeValueItem(''), ]
        parent.appendRow([item, ] + items)
        if checkable:
            item.setColor(self.loadItemPen(item).color())
        for index in getattr(series, 'indexes', []):
            self.addSeries(index.key, index, parent=item)
        self.loadSelection(item)
        return item


    def anyCheckedItems(self):
        """ True if any control is checked.

        """
        return bool(self.checkedItems())

    def axisWidgets(self):
        """ Yields each plot axis widget.

        """
        for axis in allAxes:
            yield self.plot.axisWidget(axis)

    def checkedItems(self):
        """ Sequence of checked controls.

        """
        return [item for item in self.controlsTreeItems if item.isChecked()]

    def checkedNames(self):
        """ Sequence of checked control names.

        """
        return [self.itemName(item) for item in self.checkedItems()]

    def on_zoomer_zoomed(self, rect):
        """ Sets autoscaling mode when plot is zoomed to its base.

        @param rect ignored
        @return None
        """
        if not self.zoomer.zoomRectIndex():
            self.enableAutoScale()

    def enableAutoScale(self):
        """ Sets autoscaling mode on all four axes.

        @return None
        """
        for axis in allAxes:
            self.plot.setAxisAutoScale(axis)

    def enableCurve(self, item, enable=True):
        """ Sets the visibility and style of a plot curve.

        @param item tree widget item
        @param enabled sets curve visible if True, otherwise invisible
        @return None
        """
        curve = item.curve
        curve.hide()
        plot = self.plot
        legend = plot.legend()
        drawLegend = self.actionDrawLegend
        if enable:
            if not curve.settingsLoaded:
                self.loadCurve(self.itemName(item), curve)
            curve.setData(item.data.x, item.data.y)
            curve.attach(plot)
            if self.actionDrawLegend.isChecked():
                curve.updateLegend(legend, True)
            curve.show()
        else:
            legend.remove(curve)
            curve.detach()
        self.emit(Signals.enableCurve, item, enable)
        checked = self.anyCheckedItems()
        self.actionDrawLegend.setEnabled(checked)
        if not checked:
            legend.clear()
            legend.hide()
        plot.updateAxes()
        plot.replot()

    def getAxisColor(self):
        """ Returns the foreground color of the axis widgets.

        @return QColor instance
        """
        widget = self.referenceAxisWidget()
        palette = widget.palette()
        return palette.color(palette.WindowText)

    def itemName(self, item):
        """ Name for given item, including name of this plot.

        @param item ControlTreeItem instance
        @return name full item name including plot name
        """
        return '%s/%s' % (self.plotName(), item.name())

    def loadCanvasColor(self):
        """ Reads and sets the canvas color from saved settings.

        @return None
        """
        color = self.settings.value(
            '%s/canvascolor' % self.plotName(), defaults.canvasColor())
        self.plot.setCanvasBackground(QColor(color))

    def loadCurve(self, name, curve):
        """ Reads and configures a plot curve.

        @param name of curve
        @param curve QwtPlotCurve instance
        @return None
        """
        getv = self.settings.value
        curve.setBrush(QBrush(getv('%s/brush' % name, QBrush())))
        curve.setPen(QPen(getv('%s/pen' % name, QPen())))
        curve.setStyle(curve.CurveStyle(
            getv('%s/style' % name, QVariant(curve.Lines)).toInt()[0]))
        curve.setBaseline(
            getv('%s/baseline' % name, QVariant(0.0)).toDouble()[0])
        curve.setCurveAttribute(
            curve.Inverted, getv('%s/inverted' % name).toBool())
        curve.setCurveAttribute(
            curve.Fitted, getv('%s/fitted' % name).toBool())
        curve.setPaintAttribute(
            curve.PaintFiltered, getv('%s/filtered' % name).toBool())
        curve.setPaintAttribute(
            curve.ClipPolygons, getv('%s/clippoly' % name).toBool())
        curve.setXAxis(
            QwtPlot.Axis(getv('%s/xaxis' % name, xBottom).toInt()[0]))
        curve.setYAxis(
            QwtPlot.Axis(getv('%s/yaxis' % name, yRight).toInt()[0]))

        def applySymbol(symname, symobj):
            symobj.setBrush(QBrush(getv('%s/brush' % symname, QBrush())))
            symobj.setPen(QPen(getv('%s/pen' % symname, QPen())))
            style = getv('%s/style' % symname, QVariant(symobj.NoSymbol))
            symobj.setStyle(symobj.Style(style.toInt()[0]))
            symobj.setSize(getv('%s/size' % symname).toSize())

        applySymbol('%s/symbol' % name, curve.symbol())
        curve.dataMarker = marker = PlotDataMarker()
        marksym = QwtSymbol()
        applySymbol('%s/dataselect/symbol' % name, marksym)
        marker.setSymbol(marksym)
        markstyle = getv('%s/dataselect/style' % name, PlotDataMarker.VLine)
        marker.setLineStyle(marker.LineStyle(markstyle.toInt()[0]))
        marker.setLinePen(QPen(getv('%s/dataselect/pen' % name, Qt.red)))
        curve.settingsLoaded = True

    def loadGrids(self):
        """ Reads and sets the major and minor grid pens and visibility.

        @return None
        """
        name = self.plotName()
        grid = self.grid
        getv = self.settings.value
        pen = getv('%s/major/pen' % name, defaults.majorGridPen())
        grid.setMajPen(QPen(pen))
        pen = getv('%s/minor/pen' % name, defaults.minorGridPen())
        grid.setMinPen(QPen(pen))
        items = [('%s/major/x/enabled', self.actionDrawMajorX),
                 ('%s/major/y/enabled', self.actionDrawMajorY),
                 ('%s/minor/x/enabled', self.actionDrawMinorX),
                 ('%s/minor/y/enabled', self.actionDrawMinorY)]
        for key, action in items:
            v = getv(key % name)
            if not v.isValid() or v.toBool():
                action.trigger()

    def loadItemPen(self, item):
        """ Creates a pen from saved settings.

        @param item ControlTreeItem instance
        @return QPen instance
        """
        pen = self.settings.value('%s/pen' % self.itemName(item))
        if pen.isValid():
            pen = QPen(pen)
        else:
            pen = defaults.itemPen(item.name())
        return pen

    def loadLegend(self):
        """ Restores the plot legend visibility from saved settings.

        """
        key = '%s/legend/enabled' % self.plotName()
        if self.settings.value(key).toBool():
            self.actionDrawLegend.trigger()

    def loadSelection(self, item):
        """ Restores an item check state and pen from saved settings.

        """
        key = '%s/checkeditems' % self.plotName()
        if self.itemName(item) in self.settings.valueLoad(key, ''):
            item.setCheckState(Qt.Checked)
            item.setColor(self.loadItemPen(item).color())

    def loadSelections(self):
        """ Restores each control tree item check state and pen.

        """
        for item in self.controlsTreeItems:
            self.loadSelection(item)

    def saveSelections(self):
        """ Saves the selected control item names.

        """
        key = '%s/checkeditems' % self.plotName()
        names = self.checkedNames()
        if names:
            # don't save an empty list because the user might be
            # closing an empty plot that really does have selections
            # saved in the settings.
            self.settings.setValueDump(key, names)

    def plotName(self):
        """ The name of this plot.

        """
        try:
            return '%s/%s' % (self.key, self.objectName())
        except (AttributeError, ):
            return 'noname/%s' % (self.objectName(), )

    def referenceAxisWidget(self):
        """ Returns a referece axis widget.

        """
        return self.plot.axisWidget(xBottom)

    def saveCanvasColor(self):
        """ Saves the canvas background color to user settings.

        @return None
        """
        prefix = self.plotName()
        self.settings.setValue(
            '%s/canvascolor' % prefix, self.plot.canvasBackground())

    def saveCurve(self, name, curve):
        """ Saves visual settings of a curve.

        @param name curve name, used as settings key
        @param curve QwtPlotCurve instance
        @return None
        """
        setv = self.settings.setValue
        setv('%s/brush' % name, curve.brush())
        setv('%s/pen' % name, curve.pen())
        setv('%s/style' % name, curve.style())
        setv('%s/baseline' % name, curve.baseline())
        setv('%s/inverted' % name,
                 curve.testCurveAttribute(curve.Inverted))
        setv('%s/fitted' % name,
                 curve.testCurveAttribute(curve.Fitted))
        setv('%s/filtered' % name,
                 curve.testPaintAttribute(curve.PaintFiltered))
        setv('%s/clippoly' % name,
                 curve.testPaintAttribute(curve.ClipPolygons))
        setv('%s/xaxis' % name, curve.xAxis())
        setv('%s/yaxis' % name, curve.yAxis())
        name = '%s/symbol' % name
        symbol = curve.symbol()
        setv('%s/brush' % name, symbol.brush())
        setv('%s/pen' % name, symbol.pen())
        setv('%s/style' % name, symbol.style())
        setv('%s/size' % name, symbol.size())

    def saveMarker(self, name, marker):
        """ Saves visual settings of a marker.

        @param name curve name, used as settings key
        @param curve QwtPlotMarker instance
        @return None
        """
        setv = self.settings.setValue
        setv('%s/dataselect/style' % name, marker.lineStyle())
        setv('%s/dataselect/pen' % name, marker.linePen())
        symname = '%s/dataselect/symbol' % name
        symbol = marker.symbol()
        setv('%s/brush' % symname, symbol.brush())
        setv('%s/pen' % symname, symbol.pen())
        setv('%s/style' % symname, symbol.style())
        setv('%s/size' % symname, symbol.size())

    def saveLegend(self):
        """ Saves the visibility of the plot legend to user settings.

        @return None
        """
        key = '%s/legend/enabled' % self.plotName()
        self.settings.setValue(key, self.actionDrawLegend.isChecked())

    def saveMajorX(self):
        """ Saves the state and pen of the major grid x axis.

        @return None
        """
        name = self.plotName()
        setv = self.settings.setValue
        setv('%s/major/x/enabled' % name,
             self.actionDrawMajorX.isChecked())
        setv('%s/major/pen' % name, self.grid.majPen())

    def saveMajorY(self):
        """ Saves the state and pen of the major grid y axis.

        @return None
        """
        name = self.plotName()
        setv = self.settings.setValue
        setv('%s/major/y/enabled' % name,
             self.actionDrawMajorY.isChecked())
        setv('%s/major/pen' % name, self.grid.majPen())

    def saveMinorX(self):
        """ Saves the state and pen of the minor grid x axis.

        @return None
        """
        name = self.plotName()
        setv = self.settings.setValue
        setv('%s/minor/x/enabled' % name,
             self.actionDrawMinorX.isChecked())
        setv('%s/minor/pen' % name, self.grid.minPen())

    def saveMinorY(self):
        """ Saves the state and pen of the minor grid y axis.

        @return None
        """
        name = self.plotName()
        setv = self.settings.setValue
        setv('%s/minor/y/enabled' % name,
             self.actionDrawMinorY.isChecked())
        setv('%s/minor/pen' % name, self.grid.minPen())

    def setAxisColor(self, color):
        """ Sets the axis widgets foreground and text color.

        @param color QColor instance
        @return None
        """
        for widget in self.axisWidgets():
            palette = widget.palette()
            palette.setColor(palette.WindowText, color)
            palette.setColor(palette.Text, color)
            widget.setPalette(palette)

    def setAxisFont(self, font):
        """ Sets the axis widgets font.

        @param font QFont instance
        @return None
        """
        for widget in self.axisWidgets():
            widget.setFont(font)

    def updateAxis(self):
        """ Enables each y axis if there are curves attached to it.

        @return None
        """
        enable = self.plot.enableAxis
        items = self.checkedItems()
        for pair, pred in [
            ([yRight, yLeft], lambda i, a:i.curve.yAxis()==a),
            ([xTop, xBottom],  lambda i, a:i.curve.xAxis()==a)]:
            for axis in pair:
                enable(axis, any(item for item in items if pred(item, axis)))

    ## session signal handlers

    def on_session_createdSeries(self, key, field):
        """ Signal handler called when new Series objects are created.

        @param key id of ticker with new series
        @param field series field
        """
        if key != self.key:
            return
        series = self.collection[self.key].series[field]
        self.addSeries(TickType.getField(field), series)
        self.controlsTree.sortByColumn(0, Qt.AscendingOrder)

    def setItemValue(self, item):
        idx = self.controlsTreeModel.indexFromItem(item)
        parent = item.parent()
        if parent:
            getc = parent.child
        else:
            getc = self.controlsTreeModel.item
        next = getc(item.row(), item.column()+1)
        try:
            next.setText('%.2f' % item.data[-1])
        except (AttributeError, IndexError, TypeError, ):
            pass
        else:
            for c in [item.child(r, 0) for r in range(item.rowCount())]:
                self.setItemValue(c)

    def on_session_TickPrice_TickSize(self, message):
        """ Signal handler for TickPrice and TickSize session messages.

        @param message Message instance
        @return None
        """
        if message.tickerId != self.key:
            return
        for item in self.controlsTreeItems:
            self.setItemValue(item)
        items = [i for i in self.controlsTreeItems if i.curve.isVisible()]
        for item in items:
            item.curve.setData(item.data.x, item.data.y)
        if items:
            self.plot.replot()
        self.on_zoomer_zoomed(None)

    def on_session_UpdateAccountValue(self, message):
        if self.key != 'account':
            return
        items = [i for i in self.controlsTreeItems if i.curve.isVisible()]
        for item in items:
            item.curve.setData(item.data.x, item.data.y)
        if items:
            self.plot.replot()
        self.on_zoomer_zoomed(None)


    ## action signal handlers

    @pyqtSignature('')
    def on_actionChangeCurveStyle_triggered(self):
        """ Signal handler called to edit a curve.

        @return None
        """
        pos = self.sender().data().toPoint()
        index = self.controlsTree.indexAt(pos)
        if index.isValid():
            item = self.controlsTreeModel.itemFromIndex(index)
            indexZero = self.controlsTreeModel.sibling(index.row(), 0, index)
            first = self.controlsTreeModel.itemFromIndex(indexZero)
            try:
                curve = first.curve
                color = first.color
            except (AttributeError, ):
                return
            else:
                item = first
            if not curve.settingsLoaded:
                self.loadCurve(self.itemName(item), curve)
            cplot = curve.plot()
            if cplot is None:
                curve.attach(self.plot)
            dlg = PlotItemDialog(curve, self)
            if dlg.exec_() == dlg.Accepted:
                dlg.applyToCurve(curve)
                item.setColor(curve.pen().color())
                self.saveCurve(self.itemName(item), curve)
                self.enableCurve(item, enable=item.checkState()==Qt.Checked)
            if cplot is None:
                curve.detach()

    @pyqtSignature('')
    def on_actionChangeCurveAxisX_triggered(self):
        """ Signal handler called to toggle the x axis of a curve.

        """
        pos = self.sender().data().toPoint()
        index = self.controlsTree.indexAt(pos)
        if index.isValid():
            item = self.controlsTreeModel.itemFromIndex(index)
            curve = item.curve
            if curve.xAxis() == xTop:
                curve.setXAxis(xBottom)
            else:
                curve.setXAxis(xTop)
            self.updateAxis()
            self.saveCurve(self.itemName(item), curve)
            self.plot.replot()

    @pyqtSignature('')
    def on_actionChangeCurveAxisY_triggered(self):
        """ Signal handler called to toggle the y axis of a curve.

        @return None
        """
        pos = self.sender().data().toPoint()
        index = self.controlsTree.indexAt(pos)
        if index.isValid():
            item = self.controlsTreeModel.itemFromIndex(index)
            curve = item.curve
            if curve.yAxis() == yLeft:
                curve.setYAxis(yRight)
            else:
                curve.setYAxis(yLeft)
            self.updateAxis()
            self.saveCurve(self.itemName(item), curve)
            self.plot.replot()

    @pyqtSignature('')
    def on_actionChangeDataMarker_triggered(self):
        """ Signal handler called to edit data marker.

        @return None
        """
        pos = self.sender().data().toPoint()
        index = self.controlsTree.indexAt(pos)
        if index.isValid():
            item = self.controlsTreeModel.itemFromIndex(index)
            curve = item.curve
            if not curve.settingsLoaded:
                self.loadCurve(self.itemName(item), curve)
            cplot = curve.plot()
            if cplot is None:
                curve.attach(self.plot)
            dlg = PlotItemDialog(curve, marker=curve.dataMarker, parent=self)
            if dlg.exec_() == dlg.Accepted:
                dlg.applyToMarker(curve.dataMarker)
                self.saveMarker(self.itemName(item), curve.dataMarker)
                for marker in self.highlightMarkers:
                    marker.restyleFrom(curve.dataMarker)
                self.plot.replot()
            if cplot is None:
                curve.detach()

    @pyqtSignature('bool')
    def on_actionDrawLegend_triggered(self, enable):
        """ Signal handler called to toggle the plot legend visibility.

        @param enable if True, legend is enabled
        @return False
        """
        legend = self.plot.legend()
        legend.setVisible(enable)
        if enable:
            items = self.checkedItems()
            if items:
                for item in items:
                    item.curve.updateLegend(legend, True)
            else:
                self.actionDrawLegend.setChecked(False)
        else:
            legend.clear()
        self.saveLegend()

    @pyqtSignature('bool')
    def on_actionDrawMajorX_triggered(self, enable):
        """ Signal handler called to toggle visiblity of major grid x axis.

        @param enable if True, grid axis is enabled
        @return None
        """
        self.grid.enableX(enable)
        self.plot.replot()
        self.saveMajorX()

    @pyqtSignature('bool')
    def on_actionDrawMajorY_triggered(self, enable):
        """ Signal handler called to toggle visiblity of major grid y axis.

        @param enable if True, grid axis is enabled
        @return None
        """
        self.grid.enableY(enable)
        self.plot.replot()
        self.saveMajorY()

    @pyqtSignature('bool')
    def on_actionDrawMinorX_triggered(self, enable):
        """ Signal handler called to toggle visiblity of minor grid x axis.

        @param enable if True, grid axis is enabled
        @return None
        """
        self.grid.enableXMin(enable)
        self.plot.replot()
        self.saveMinorX()

    @pyqtSignature('bool')
    def on_actionDrawMinorY_triggered(self, enable):
        """ Signal handler called to toggle visiblity of minor grid y axis.

        @param enable if True, grid axis is enabled
        @return None
        """
        self.grid.enableYMin(enable)
        self.plot.replot()
        self.saveMinorY()

    @pyqtSignature('')
    def on_actionChangeMajorGridStyle_triggered(self):
        """ Signal handler called to edit the major grid pen.

        @return None
        """
        pen = changePen(self.grid.majPen, self.grid.setMajPen, self)
        if pen:
            self.plot.replot()
            self.saveMajorX()
            self.saveMajorY()

    @pyqtSignature('')
    def on_actionChangeMinorGridStyle_triggered(self):
        """ Signal handler called to edit the minor grid pen.

        @return None
        """
        pen = changePen(self.grid.minPen, self.grid.setMinPen, self)
        if pen:
            self.plot.replot()
            self.saveMinorX()
            self.saveMinorY()

    @pyqtSignature('')
    def on_actionChangeCanvasColor_triggered(self):
        """ Signal handler called to edit the plot canvas background.

        @return None
        """
        plot = self.plot
        color = changeColor(
            plot.canvasBackground, plot.setCanvasBackground, self)
        if color:
            pen = QPen(complementColor(color))
            self.zoomer.setRubberBandPen(pen)
            self.picker.setTrackerPen(pen)
            plot.replot()
            self.saveCanvasColor()

    @pyqtSignature('')
    def on_actionChangeAxesFont_triggered(self):
        """ Signal handler called to edit the axes font.

        @return None
        """
        widget = self.referenceAxisWidget()
        default = widget.font()
        font, okay = QFontDialog.getFont(default, self, 'Select Axis Font')
        if okay:
            self.setAxisFont(font)
            self.settings.setValue(
                '%s/axisfont' % self.plotName(), font)

    @pyqtSignature('')
    def on_actionChangeAxesColor_triggered(self):
        """ Signal handler called to edit the axes color.

        @return None
        """
        color = changeColor(self.getAxisColor, self.setAxisColor, self)
        if color:
            self.settings.setValue('%s/axiscolor' % self.plotName(), color)

    @pyqtSignature('bool')
    def on_actionShowDataDialog_triggered(self, enable):
        """ Signal handler called to show or hide the data dialog.

        @return None
        """
        if enable:
            dlg = self.dataDialog = PlotDataDialog(self)
            try:
                tabs = self.window().centralTabs
            except (AttributeError, ):
                pass
            else:
                name = tabs.tabText(tabs.currentIndex())
                dlg.setWindowTitle(str(dlg.windowTitle()) % name)
                dlg.setWindowIcon(tabs.tabIcon(tabs.currentIndex()))
            self.connect(
                dlg, Signals.dialogFinished, self.on_dataDialog_finished)
            self.connect(
                dlg, Signals.highlightSelections, self.on_dataDialog_selected)
            dlg.show()
        elif self.dataDialog:
            self.dataDialog.close()
            self.dataDialog = None
        self.settings.setValue('%s/datadialog' % self.plotName(), enable)

    ## controls tree signal handlers

    def on_controlsTree_doubleClicked(self, index):
        """ Signal handler for control tree double click.

        @param index QModelIndex instance
        @return None
        """
        tree = self.controlsTree
        if index.isValid():
            pos = tree.visualRect(index).center()
            actions = tree.actions()
            for action in actions:
                action.setData(QVariant(pos))
            self.actionChangeCurveStyle.trigger()

    def on_controlsTree_itemChanged(self, item):
        """ Signal handler for all changes to control tree items.

        @param item changed tree widget item
        @return None
        """
        try:
            curve = item.curve
        except (AttributeError, ):
            pass
        else:
            self.enableCurve(item, enable=item.checkState()==Qt.Checked)
            self.updateAxis()
            self.saveSelections()

    def on_controlsTree_customContextMenuRequested(self, pos):
        """ Signal handler for context menu request over control tree.

        @param pos QPoint of mouse click
        @return None
        """
        tree = self.controlsTree
        index = tree.indexAt(pos)
        if index.isValid():
            item = self.controlsTreeModel.itemFromIndex(index)
            if not hasattr(item, 'curve'):
                return
            if item.curve.yAxis() == yRight:
                self.actionChangeCurveAxisY.setText('Move to Left Axis')
            else:
                self.actionChangeCurveAxisY.setText('Move to Right Axis')
            if item.curve.xAxis() == xTop:
                self.actionChangeCurveAxisX.setText('Move to Bottom Axis')
            else:
                self.actionChangeCurveAxisX.setText('Move to Top Axis')
            actions = tree.actions()
            for action in actions:
                action.setData(QVariant(pos))
            QMenu.exec_(actions, tree.mapToGlobal(pos))

    def on_dataDialog_finished(self, result):
        """ Signal handler for data dialog finish.

        Sets and saves state of data dialog display after its closed.

        @param result ignored
        @return None
        """
        self.actionShowDataDialog.setChecked(False)
        self.dataDialog = None
        self.on_dataDialog_selected([])
        self.settings.setValue('%s/datadialog' % self.plotName(), False)

    def on_dataDialog_selected(self, items):
        """ Signal handler for data dialog selection changes.

        @params items list of (index, item) two-tuples
        @return None
        """
        for marker in self.highlightMarkers:
            marker.detach()
        self.highlightMarkers = markers = []
        for index, item in items:
            try:
                x, y = index.row(), item.data[index.row()]
            except (IndexError, ):
                continue
            if x is None or y is None:
                continue
            curve = item.curve
            marker = curve.dataMarker.cloneFromValue(curve, x, y)
            markers.append(marker)
            marker.attach(self.plot)
        self.plot.replot()

    def on_plotSplitter_splitterMoved(self, pos, index):
        """ Signal handler for splitter move; saves state to user settings.

        @param pos ignored
        @param index ignored
        @return None
        """
        settings = self.settings
        statekey = '%s/%s' % (self.plotName(), settings.keys.splitstate)
        settings.setValue(statekey, self.plotSplitter.saveState())

    def syncPlot(self, sync=None):
        print '## sync?', sync
        session = self.session
        (session.registerMeta if sync else session.deregisterMeta)(self)

