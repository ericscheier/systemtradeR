#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>

# TODO: write docstrings on series types

import warnings
warnings.filterwarnings('ignore', category=DeprecationWarning, module='numpy')

from profit.series.basic import *
try:
    from profit.series.advanced import *
except (ImportError, ):
    pass
