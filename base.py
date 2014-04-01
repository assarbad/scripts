#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: set autoindent smartindent softtabstop=4 tabstop=4 shiftwidth=4 expandtab:
__author__ = "Oliver Schneider <oliver@assarbad.net>"
__copyright__ = "Copyright (C) Oliver Schneider (assarbad.net)"
__version__ = '0.1'
__doc__ = """
=========
 PROGRAM
=========
"""
import os, sys
# Checking for compatibility with Python version
if (sys.version_info[0] != 2) or (sys.version_info < (2,6)):
    sys.exit("This script requires Python version 2.6 or better from the 2.x branch of Python.")

## Cater the different Python versions
#try:
#    import cElementTree as ET
#    from cElementTree import XMLParser
#except ImportError:
#    try:
#        import xml.etree.cElementTree as ET
#        from xml.etree.ElementTree import XMLParser
#    except ImportError:
#        print >> sys.stderr, "ERROR: Failed to import cElementTree from any known place"
#        raise
## Require a minimum set of packages
#try:
#    import copy, pprint, time, traceback
#except ImportError:
#    print >> sys.stderr, "ERROR: Could not import one of the external prerequisites for this package."
#    raise
# Shim class over optparse, if argparse isn't available
try:
    from argparse import ArgumentParser, HelpFormatter
    class MyArgumentParser(ArgumentParser):
        def __init__(self, prog=None, usage=None, description=None, epilog=None, version=None, parents=[], formatter_class=HelpFormatter, prefix_chars='-', fromfile_prefix_chars=None, argument_default=None, conflict_handler='error', add_help=True):
            __version = version
            version = None
            superinit = super(MyArgumentParser, self).__init__
            superinit(prog=prog, usage=usage, description=description, epilog=epilog, parents=parents, formatter_class=formatter_class, prefix_chars=prefix_chars, fromfile_prefix_chars=fromfile_prefix_chars, argument_default=argument_default, conflict_handler=conflict_handler, add_help=add_help)
            if __version is not None:
                self.add_argument('--version', action='version', version=__version)
except ImportError:
    class MyArgumentParser(object):
        __op = None
        def __init__(self, prog=None, usage=None, description=None, epilog=None, version=None, parents=[], formatter_class=None, prefix_chars='-', fromfile_prefix_chars=None, argument_default=None, conflict_handler='error', add_help=True):
            if version is None:
                version = __version__
            from optparse import OptionParser
            self.__op = OptionParser(prog=prog, usage=usage, description=description, epilog=epilog, version=version, formatter=formatter_class, conflict_handler=conflict_handler, add_help_option=add_help)
            # Glue between optparse and argparse
            self.__dict__['add_argument'] = self.__op.add_option
        def parse_args(self, args=None, values=None):
            (options, args) = self.__op.parse_args()
            return args

def parse_args():
    """
    """
    parser = MyArgumentParser(description='PROGRAM')
    parser.add_argument('--nologo', action='store_const', dest='nologo', const=True,
            help='Don\'t show info about this script.')
    return parser.parse_args()

def main(**kwargs):
    """
    """
    pass

if __name__ == '__main__':
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
        print __doc__
        raise # re-raise
