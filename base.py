#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: set autoindent smartindent softtabstop=4 tabstop=4 shiftwidth=4 noexpandtab:
__author__ = "Oliver Schneider"
#__copyright__ = "Copyright (C) Oliver Schneider (assarbad.net)"
__copyright__ = "2015 Oliver Schneider (assarbad.net), under Public Domain/CC0, or MIT/BSD license where PD is not applicable"
__version__ = "0.1"
__doc__ = """
=========
 PROGRAM
=========
"""
import os, sys

# Checking for compatibility with Python version
if (sys.version_info[0] != 2) or (sys.version_info < (2,6)):
	sys.exit("This script requires Python version 2.6 or better from the 2.x branch of Python.")

# Don't create .pyc or .pyo files
sys.dont_write_bytecode = True
# If we have modules stored relative to this script path
# sys.path.append(os.path.dirname(os.path.realpath(__file__)))


def parse_args():
	""" """
	parser = ArgumentParser(description='PROGRAM')
	parser.add_argument('--nologo', action='store_const', dest='nologo', const=True,
			help='Don\'t show info about this script.')
	return parser.parse_args()

def main(**kwargs):
	""" """
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
