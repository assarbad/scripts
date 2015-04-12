#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: set autoindent smartindent softtabstop=4 tabstop=4 shiftwidth=4 noexpandtab:
__author__ = "Oliver Schneider"
__copyright__ = "2015 Oliver Schneider (assarbad.net), under Public Domain/CC0, or MIT/BSD license where PD is not applicable"
__version__ = "2.1"
import os, sys, time

# Checking for compatibility with Python version
if (sys.version_info[0] != 2) or (sys.version_info < (2,7)):
    sys.exit("This script requires Python version 2.7 or better from the 2.x branch of Python.")

# Don't create .pyc or .pyo files
sys.dont_write_bytecode = True
# We have two modules stored relative to this script path
sys.path.append(os.path.dirname(os.path.realpath(__file__)))
# Additional modules
from mirrhelp import Mirror, touch, touchdt

def main(**kwargs):
	"Main function of this script"
	if 'debug' in kwargs:
		from mirrhelp import set_dbglvl
		set_dbglvl(kwargs.get('debug'))
	from fnmatch import fnmatch
	from urlparse import urlparse
	from mirrhelp import dbglvl, lock_script
	lock_script('AFL-mirror')
	mirror = Mirror(kwargs.get('directory'), baseurl = 'http://lcamtuf.coredump.cx/afl/')
	def afl_pages(downloads_from_page):
		for dlpage in downloads_from_page('http://lcamtuf.coredump.cx/afl/', criteria=('*/', '*.htm', '*.html',)):
			for download in downloads_from_page(dlpage, criteria=('*.tgz', '*.txt',)):
				basename = os.path.basename(urlparse(download).path)
				skipit = False
				for p in ['afl-0.*.tgz', 'afl-1.[012345]*.tgz', 'afl-1.6[01234]*.tgz']:
					skipit = skipit or fnmatch(basename, p)
					if skipit:
						break
				if (dbglvl > 1) and skipit:
					print >> sys.stderr, "Skipping %s" % basename
				if not skipit:
					yield download, False
	mirror.process(
			afl_pages,
			redownload=kwargs.get('redownload', False))
	return 0

def parse_args():
	"Argument parsing wrapper"
	from argparse import ArgumentParser
	parser = ArgumentParser(description='Mirror script for american fuzzy lop (afl)')
	parser.add_argument('--version', '-V', action='version', version=__version__,
						help='show the program version and exit')
	parser.add_argument('--debug', '-d', action='count', default=0,
						help='turn on debugging (more extensive logging) and increase detail')
	parser.add_argument('--directory', '-D', '--dir', action='store', default=os.path.join(os.path.dirname(os.path.realpath(__file__)), 'releases'),
						help='directory into which to mirror the files', metavar='DIR')
	parser.add_argument('--noignore', '-I', '--no-ignore',  action='store_true',
						help='do not ignore some pre-existing downloads, also check them against remote timestamp')
	parser.add_argument('--redownload', '-r',  action='store_true',
						help='force a re-download, even if the local file exists and is up-to-date')
	return parser.parse_args()

if __name__ == "__main__":
	sys.exit(main(**vars(parse_args())))
