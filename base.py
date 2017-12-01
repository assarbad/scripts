#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: set autoindent smartindent softtabstop=4 tabstop=4 shiftwidth=4 expandtab:
from __future__ import print_function, with_statement, unicode_literals, division, absolute_import
__author__ = "Oliver Schneider"
#__copyright__ = "Copyright (C) Oliver Schneider (assarbad.net)"
__copyright__ = "2017 Oliver Schneider (assarbad.net), under Public Domain/CC0, or MIT/BSD license where PD is not applicable"
__version__ = "0.1"
__compatible__ = ((2, 6), (2, 7), (3, 3), (3, 4), (3, 5), (3, 6))
__doc__ = """
=========
 PROGRAM
=========
"""
import argparse
import os
import sys

# Checking for compatibility with Python version
if not sys.version_info[:2] in __compatible__:
    sys.exit("This script is only compatible with the following Python versions: %s." % (", ".join(["%d.%d" % (z[0], z[1]) for z in __compatible__]))) # pragma: no cover

# Don't create .pyc or .pyo files
sys.dont_write_bytecode = True
# If we have modules stored relative to this script path
# sys.path.append(os.path.dirname(os.path.realpath(__file__)))

# Python 2.x/3.x compatibility
try:
    basestring # pylint: disable=basestring-builtin
except NameError: # pragma: no cover
    basestring = str # pylint: disable=redefined-builtin
try:
    xrange # pylint: disable=xrange-builtin
except NameError: # pragma: no cover
    xrange = range # pylint: disable=redefined-builtin

def py3compat_cmp(a, b):
    """Replacement for the missing cmp() builtin in Python 3.x"""
    if a == b:
        return 0
    if a < b:
        return -1
    return 1

def py26compat_cmp_to_key(mycmp):
    """Convert a cmp= function into a key= function"""
    class K(object): # pylint: disable=too-few-public-methods
        """This is a compatibility adapter class for Python 2.6"""
        def __init__(self, obj, *args): # pylint: disable=unused-argument
            self.obj = obj
        def __lt__(self, other):
            return mycmp(self.obj, other.obj) < 0
        def __gt__(self, other):
            return mycmp(self.obj, other.obj) > 0
        def __eq__(self, other):
            return mycmp(self.obj, other.obj) == 0
        def __le__(self, other):
            return mycmp(self.obj, other.obj) <= 0
        def __ge__(self, other):
            return mycmp(self.obj, other.obj) >= 0
        def __ne__(self, other):
            return mycmp(self.obj, other.obj) != 0
    return K

try:
    cmp # pylint: disable=cmp-builtin
except NameError: # pragma: no cover
    cmp = py3compat_cmp # pylint: disable=redefined-builtin

def parse_args():
    """ """
    from argparse import ArgumentParser
    parser = ArgumentParser(description="PROGRAM")
    parser.add_argument("--nologo", action="store_const", dest="nologo", const=True,
            help="Don't show info about this script.")
    return parser.parse_args()

def main(**kwargs):
    """ """
    pass

if __name__ == "__main__":
    args = parse_args()
    try:
        main(**vars(args))
    except SystemExit:
        pass
    except ImportError:
        raise # re-raise
    except RuntimeError:
        raise # re-raise
    except:
        print(__doc__)
        raise # re-raise
