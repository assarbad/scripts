#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: set autoindent smartindent softtabstop=4 tabstop=4 shiftwidth=4 noexpandtab:
__author__ = "Oliver Schneider"
__copyright__ = "2015 Oliver Schneider (assarbad.net), under Public Domain/CC0, or MIT/BSD license where PD is not applicable"
__version__ = "1.2"
import os, sys

# Checking for compatibility with Python version
if (sys.version_info[0] != 2) or (sys.version_info < (2,7)):
    sys.exit("This script requires Python version 2.7 or better from the 2.x branch of Python.")

import functools, mechanize, time
from datetime import datetime
from HTMLParser import HTMLParser
from urlparse import urljoin, urlparse, urlunparse
from fnmatch import fnmatch
from stat import S_IRUSR, S_IWUSR, S_IXUSR, S_IRGRP, S_IWGRP, S_IXGRP, S_IROTH, S_IWOTH, S_IXOTH

dbglvl = 0

def touch(fname, times=None):
	"Touch a file to set its mtime, using Unix epoch for the time"
	with file(fname, 'a'):
		os.utime(fname, times)

def touchdt(fname, dt):
	"Touch a file to set its mtime, but use datetime"
	numsecs = (dt - datetime(1970, 1, 1)).total_seconds()
	return touch(fname, (numsecs, numsecs))

def set_dbglvl(val):
	global dbglvl
	dbglvl = val

def get_dbglvl(val):
	return dbglvl

class Mirror(object):
	"A class which takes care of mirroring linked files from a website (HTML)"
	def __init__(self, basepath, baseurl='', nodownload=False):
		dbglvl = globals().get('dbglvl', -1)
		typechecks = { 'basepath' : basestring, 'baseurl' : basestring, 'nodownload' : bool }
		for l, t in typechecks.iteritems():
			if not isinstance(locals()[l], t):
				raise TypeError('%s must be a %r value' % t)
		# Create download directory if it doesn't exist
		if not os.path.exists(basepath):
			os.makedirs(basepath)
		if not os.path.isdir(basepath):
			raise RuntimeError('basepath must be a directory, but evidently is not')
		self.__basepath, self.__baseurl, self.__nodownload = basepath, baseurl, nodownload
		# Prepare the browser instance from mechanize
		br = mechanize.Browser()
		br.set_handle_robots(False)
		br.set_handle_equiv(True)
		br.set_handle_redirect(True)
		br.set_handle_referer(True)
		br.addheaders = [
			("User-agent", "Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; rv:11.0) like Gecko"),
			("Accept", "text/html, application/xhtml+xml, */*"),
			("Accept-Charset", ""),
			("Accept-Language", "en-US"),
			("Connection", "Keep-Alive"),
			]
		if dbglvl > 1:
			br.set_debug_http(True)
			br.set_debug_redirects(True)
			br.set_debug_responses(True)
		self.__br = br
	def process(self, urlitems, redownload=False):
		"""\
		Processes a mirroring request based on the passed urlitems
		"""
		dbglvl = globals().get('dbglvl', 0)
		# Sanity checks
		if not isinstance(urlitems, dict) and not callable(urlitems):
			raise TypeError('urlitems parameter must be a dict')
		downloadables = {} # dict to keep unique URLs
		if callable(urlitems):
			for dl, downloaded in urlitems(functools.partial(Mirror.downloads_from_page, self)):
				if not downloaded:
					downloadables[dl] = 0
		elif len(urlitems):
			# Further sanity checks
			for url, criteria in urlitems.iteritems():
				if not isinstance(url, basestring):
					raise TypeError('the keys in urlitems must be strings (the URL)')
				if not callable(criteria) and not isinstance(criteria, (list, tuple)):
					raise TypeError('the urlitems values must be callable or lists or tuples; but for %s it is a %r' % (url, type(criteria)))
				if not callable(criteria):
					for i in criteria:
						if not isinstance(i, basestring):
							raise TypeError('urlitems list values must contain string values only')
			# Parse the given URLs to find downloads matching our criteria
			for url, criteria in urlitems.iteritems():
				for dl in self.downloads_from_page(url, criteria):
					downloadables[dl] = 0
		for dl in sorted(downloadables.keys()):
			self.download(dl, redownload=redownload)
	def open(self, *args, **kwargs):
		"Pass-through function for mechanize.Browser.open()"
		return self.__br.open(*args, **kwargs)
	def downloads_from_page(self, url, criteria=None):
		"Function to download relevant links from a website"
		dbglvl = globals().get('dbglvl', 0)
		self.open(url) # browse to the page with the downloadable items
		if criteria is None:
			criteria = lambda x: True # match all
		if not callable(criteria):
			def make_match_function():
				pattern_list = criteria
				def match(url):
					matches = [url for pattern in pattern_list if fnmatch(urlparse(url).path, pattern)]
					if dbglvl > 2:
						print >> sys.stderr, "Pattern list: %r" % [x for x in pattern_list]
						print >> sys.stderr, "URL matching patterns: %r" % ([urlparse(url).path for url in matches])
					return len(matches) > 0
				return match
			if dbglvl > 2:
				print >> sys.stderr, "Using match function"
			criteria = make_match_function()
		hostname = urlparse(url).hostname
		retval = {}
		for lnk in self.__br.links():
			fullurl = urljoin(lnk.base_url, lnk.url)
			if urlparse(fullurl).hostname == hostname:
				# "Normalize" the URL by stripping local anchor references or query parts
				upo = urlparse(fullurl)
				fullurl = urlunparse((upo.scheme,upo.netloc,upo.path,'','','',))
				if criteria(fullurl):
					retval[fullurl] = 0
		return retval.keys()
	def download(self, url, localpath = None, redownload=False):
		dbglvl = globals().get('dbglvl', 0)
		if localpath is None:
			# compute a local path for the file to download
			localpath = os.path.join(self.__basepath, url.replace(self.__baseurl, ''))
			if ('http://' in localpath) or ('https://' in localpath):
				raise RuntimeError('logic flawed, did not expect to see a path with scheme identifier in it')
		# Download the file
		try:
			response = self.__br.open(url)
			# Get Last-Modified header value already parsed
			lm = response.info().getdate("Last-Modified")
			# Convert to datetime object
			remotedt = datetime(*lm[0:6]) if lm is not None else datetime.utcnow()
			if dbglvl > 0:
				print >> sys.stderr, "%s [%s]\n\t%s" % (url, remotedt, localpath)
			# Decide whether to download or not
			if os.path.exists(localpath):
				localdt = datetime.fromtimestamp(os.path.getmtime(localpath))
				redownload = redownload or (remotedt > localdt)
			else:
				redownload = True
			if self.__nodownload:
				redownload = False
			if redownload:
				if not os.path.isdir(os.path.dirname(localpath)):
					os.makedirs(os.path.dirname(localpath))
				fname, info = self.__br.retrieve(url, localpath)
				if fname:
					print "Downloaded: %s" % (localpath)
				touchdt(localpath, remotedt)
				os.chmod(localpath, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)
			else:
				print "Not downloading: %s" % (localpath)
			return 0
		except (mechanize.HTTPError,mechanize.URLError) as e:
			if isinstance(e,mechanize.HTTPError):
				print >> sys.stderr, "HTTP error code %d [%s]" % (e.code, url)
				if os.path.exists(fname):
					os.unlink(fname)
			else:
				print >> sys.stderr, "ERROR: %s " % str(e.reason.args)
		return 1
