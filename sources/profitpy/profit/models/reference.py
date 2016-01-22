#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Mostly copyright © 2008 Trolltech.

## This is a copy-and-pasted-formated-for-python version of the Qt 4.4
## Model Subclassing Reference, along with the documentation for each
## of the functions.  Don't use the ReferenceModel as a base class, as
## it does not work correctly with views.

from PyQt4.QtCore import Qt, QModelIndex


class ReferenceModel:
    """ ReferenceModel -> do not use this class; consider it a
    reference example.  Method docstrings were culled from the
    Trolltech Qt4 docs.

    """

    ##
    ## According to the docs, read-only models need these methods:
    ##

    def flags(self, index=QModelIndex()):
        """ Returns the item flags for the given index.

        The base class implementation returns a combination of flags
        that enables the item (ItemIsEnabled) and allows it to be
        selected (ItemIsSelectable).

        Used by other components to obtain information about each item
        provided by the model. In many models, the combination of
        flags should include Qt::ItemIsEnabled and
        Qt::ItemIsSelectable.
        """

    def data(self, index=QModelIndex(), role=Qt.DisplayRole):
        """ Returns the data stored under the given role for the item
        referred to by the index.

        Used to supply item data to views and delegates. Generally,
        models only need to supply data for Qt::DisplayRole and any
        application-specific user roles, but it is also good practice
        to provide data for Qt::ToolTipRole, Qt::AccessibleTextRole,
        and Qt::AccessibleDescriptionRole.
        """

    def headerData(self, section, orientation, role=Qt.DisplayRole):
        """ Returns the data for the given role and section in the
        header with the specified orientation.

        For horizontal headers, the section number corresponds to the
        column number of items shown beneath it. For vertical headers,
        the section number typically to the row number of items shown
        alongside it

        Provides views with information to show in their headers. The
        information is only retrieved by views that can display header
        information.
        """

    def rowCount(self, parent=QModelIndex()):
        """ Returns the number of rows under the given parent. When
        the parent is valid it means that rowCount is returning the
        number of children of parent.

        Tip: When implementing a table based model, rowCount() should
        return 0 when the parent is valid.

        Provides the number of rows of data exposed by the model.
        """

    ##
    ## QAbstractTableModel nad QAbstractItemModel require the
    ## columnCount method also:
    ##

    def columnCount(self, parent=QModelIndex()):
        """
        Returns the number of columns for the children of the given
        parent. When the parent is valid it means that rowCount is
        returning the number of children of parent.

        Tip: When implementing a table based model, columnCount()
        should return 0 when the parent is valid.

        Provides the number of columns of data exposed by the
        model. List models do not provide this function because it is
        already implemented in QAbstractListModel.
        """

    ##
    ## Editable models must provide flags, setData and setHeaderData.
    ##

    def flags(self, index=QModelIndex()):
        """ Returns the item flags for the given index.

        The base class implementation returns a combination of flags
        that enables the item (ItemIsEnabled) and allows it to be
        selected (ItemIsSelectable).

        Must return an appropriate combination of flags for each
        item. In particular, the value returned by this function must
        include Qt::ItemIsEditable in addition to the values applied
        to items in a read-only model.
        """

    def setData(self, index, value, role=Qt.EditRole):
        """ Sets the role data for the item at index to value. Returns
        true if successful; otherwise returns false.

        The dataChanged() signal should be emitted if the data was
        successfully set.

        The base class implementation returns false. This function and
        data() must be reimplemented for editable models. Note that
        the dataChanged() signal must be emitted explicitly when
        reimplementing this function.

        Used to modify the item of data associated with a specified
        model index. To be able to accept user input, provided by user
        interface elements, this function must handle data associated
        with Qt::EditRole. The implementation may also accept data
        associated with many different kinds of roles specified by
        Qt::ItemDataRole. After changing the item of data, models must
        emit the dataChanged() signal to inform other components of
        the change.
        """

    def setHeaderData(self, section, orientation, value, role=Qt.EditRole):
        """ Sets the data for the given role and section in the header
        with the specified orientation to the value supplied. Returns
        true if the header's data was updated; otherwise returns
        false.

        Note that the headerDataChanged() signal must be emitted
        explicitly when reimplementing this function.

        Used to modify horizontal and vertical header
        information. After changing the item of data, models must emit
        the headerDataChanged() signal to inform other components of
        the change.
        """

    ##
    ## Resizable models must provide insertRows and removeRows.
    ##

    def insertRows(self, row, count, parent=QModelIndex()):
        """ On models that support this, inserts count rows into the
        model before the given row. The items in the new row will be
        children of the item represented by the parent model index.

        If row is 0, the rows are prepended to any existing rows in
        the parent. If row is rowCount(), the rows are appended to any
        existing rows in the parent. If parent has no children, a
        single column with count rows is inserted.

        Returns true if the rows were successfully inserted; otherwise
        returns false.

        The base class implementation does nothing and returns false.

        If you implement your own model, you can reimplement this
        function if you want to support insertions. Alternatively, you
        can provide you own API for altering the data.

        Used to add new rows and items of data to all types of
        model. Implementations must call beginInsertRows() before
        inserting new rows into any underlying data structures, and
        call endInsertRows() immediately afterwards.
        """

    def removeRows(self, row, count, parent=QModelIndex()):
        """ On models that support this, removes count rows starting
        with the given row under parent parent from the model. Returns
        true if the rows were successfully removed; otherwise returns
        false.

        The base class implementation does nothing and returns false.

        If you implement your own model, you can reimplement this
        function if you want to support removing. Alternatively, you
        can provide you own API for altering the data.

        Used to remove rows and the items of data they contain from
        all types of model. Implementations must call
        beginRemoveRows() before inserting new columns into any
        underlying data structures, and call endRemoveRows()
        immediately afterwards.
        """

    def insertColumns(self, column, count, parent=QModelIndex()):
        """ On models that support this, inserts count new columns
        into the model before the given column. The items in each new
        column will be children of the item represented by the parent
        model index.

        If column is 0, the columns are prepended to any existing
        columns. If column is columnCount(), the columns are appended
        to any existing columns. If parent has no children, a single
        row with count columns is inserted.

        Returns true if the columns were successfully inserted;
        otherwise returns false.

        The base class implementation does nothing and returns false.

        If you implement your own model, you can reimplement this
        function if you want to support insertions. Alternatively, you
        can provide you own API for altering the data.

        Used to add new columns and items of data to table models and
        hierarchical models. Implementations must call
        beginInsertColumns() before rows are removed from any
        underlying data structures, and call endInsertColumns()
        immediately afterwards.
        """

    def removeColumns(self, column, count, parent=QModelIndex()):
        """ On models that support this, removes count columns
        starting with the given column under parent parent from the
        model. Returns true if the columns were successfully removed;
        otherwise returns false.

        The base class implementation does nothing and returns false.

        If you implement your own model, you can reimplement this
        function if you want to support removing. Alternatively, you
        can provide you own API for altering the data.

        Used to remove columns and the items of data they contain from
        table models and hierarchical models. Implementations must
        call beginRemoveColumns() before columns are removed from any
        underlying data structures, and call endRemoveColumns()
        immediately afterwards.
        """

    ##
    ## Hierarchical models need to provide functions that views can
    ## call to navigate the tree-like structures they expose, and
    ## obtain model indexes for items.
    ##

    def index(self, row, column, parent=QModelIndex()):
        """Returns the index of the item in the model specified by the given row, column and parent index.

        When reimplementing this function in a subclass, call
        createIndex() to generate model indexes that other components
        can use to refer to items in your model.

        Given a model index for a parent item, this function allows
        views and delegates to access children of that item. If no
        valid child item - corresponding to the specified row, column,
        and parent model index, can be found, the function must return
        QModelIndex(), which is an invalid model index.
        """

    def parent(self, index):
        """ Returns the parent of the model item with the given index,
        or QModelIndex() if it has no parent.

        A common convention used in models that expose tree data
        structures is that only items in the first column have
        children. For that case, when reimplementing this function
        in a subclass the column of the returned QModelIndex would
        be 0.

        Note: When reimplementing this function in a subclass, be
        careful to avoid calling QModelIndex member functions,
        such as QModelIndex::parent(), since indexes belonging to
        your model will simply call your implementation, leading
        to infinite recursion.

        Provides a model index corresponding to the parent of any
        given child item. If the model index specified corresponds
        to a top-level item in the model, or if there is no valid
        parent item in the model, the function must return an
        invalid model index, created with the empty QModelIndex()
        constructor.
        """
