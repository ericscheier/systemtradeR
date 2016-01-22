#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""ProfitPy - There you go again...

ProfitPy is a platform for developing and executing trading
strategies.
"""
from distutils.core import setup


classifiers = """
Development Status :: 5 - Production/Stable
Intended Audience :: Developers
License :: OSI Approved :: BSD License
Natural Language :: English
Operating System :: OS Independent
Programming Language :: Python
Topic :: Office/Business :: Financial
Topic :: Office/Business :: Financial :: Investment
"""


doclines = __doc__.split('\n')


setup(
    name = 'ProfitPy',
    version = "0.2a",
    description = doclines[0],
    author = 'Troy Melhase',
    author_email = 'troy@gci.net',
    url = 'http://code.google.com/p/profitpy/',
    license = 'GPL License',
    packages = ['profit', 'profit/lib', ],# FIXME
    classifiers = filter(None, classifiers.split('\n')),
    long_description = '\n'.join(doclines[2:]),
    platforms = ['any'],
    download_url = 'http://profitpy.googlecode.com/files/:release_file:',
)
