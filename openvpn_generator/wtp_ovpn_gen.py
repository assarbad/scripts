#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: set autoindent smartindent sts=4 ts=4 sw=4 noet:
__author__ = "Oliver Schneider"
__copyright__ = "2015 Oliver Schneider (assarbad.net), under Public Domain/CC0, or MIT/BSD license where PD is not applicable"
__version__ = "0.1"
import os, sys

# Checking for compatibility with Python version
if (sys.version_info[0] != 2) or (sys.version_info < (2,7)):
	sys.exit("This script requires Python version 2.7 or better from the 2.x branch of Python.")

# Don't create .pyc or .pyo files
sys.dont_write_bytecode = True
import re
from ConfigParser import RawConfigParser
from glob import glob
from jinja2 import Environment, FileSystemLoader
from StringIO import StringIO

# Location of files
conffile = os.path.splitext(os.path.realpath(__file__))[0] + '.ini'
j2tpl = os.path.splitext(os.path.realpath(__file__))[0] + '.ovpn.j2'

# The default Jinja2 template that will be loaded if it doesn't exist as file
default_j2tpl = """\
client
dev tun
proto {{ proto.name }}
{%- for server in servers %}
remote {{ server }} {{ proto.port -}}
{% endfor %}
resolv-retry infinite
nobind
persist-key
persist-tun
ns-cert-type server
cipher bf-cbc
comp-lzo
verb 3
mute 20
mssfix 1300
#key-direction 1
{%- for item in inlines %}
<{{- item.name -}}>
{{ item.value -}}
</{{- item.name -}}>
{%- endfor %}
"""

# The default INI file that will be loaded if no INI file exists on disk
default_ini = """\
[files]
ca = ca.crt
cert = CN*.crt
key = CN*.key

[templates]
profile = witopia.ovpn.j2
"""

# The order of the servers in the lists matters!
servers = {
	'America_USA' : [
		'vpn.ashburn.witopia.net',
		'vpn.atlanta.witopia.net',
		'vpn.austin.witopia.net',
		'vpn.chicago.witopia.net',
		'vpn.columbus.witopia.net',
		'vpn.dallas.witopia.net',
		'vpn.denver.witopia.net',
		'vpn.detroit.witopia.net',
		'vpn.kansascity.witopia.net',
		'vpn.lasvegas.witopia.net',
		'vpn.longbeach.witopia.net',
		'vpn.losangeles.witopia.net',
		'vpn.miami.witopia.net',
		'vpn.newyork.witopia.net',
		'vpn.newark.witopia.net',
		'vpn.phoenix.witopia.net',
		'vpn.sanfrancisco.witopia.net',
		'vpn.seattle.witopia.net',
		'vpn.washingtondc.witopia.net',
		],
	'America_Canada' : [
		'vpn.montreal.witopia.net',
		'vpn.toronto.witopia.net',
		'vpn.vancouver.witopia.net',
		],
	'America_Latin' : [
		'vpn.buenosaires.witopia.net',
		'vpn.mexicocity.witopia.net',
		'vpn.panamacity.witopia.net',
		'vpn.riodejaneiro.witopia.net',
		'vpn.saopaulo.witopia.net',
		],
	'Europe' : [
		'vpn.amsterdam.witopia.net',
		'vpn.reykjavik.witopia.net',
		'vpn.brussels.witopia.net',
		'vpn.bucharest.witopia.net',
		'vpn.copenhagen.witopia.net',
		'vpn.dublin.witopia.net',
		'vpn.frankfurt.witopia.net',
		'vpn.helsinki.witopia.net',
		'vpn.istanbul.witopia.net',
		'vpn.kiev.witopia.net',
		'vpn.lisbon.witopia.net',
		'vpn.london.witopia.net',
		'vpn.luxembourg.witopia.net',
		'vpn.madrid.witopia.net',
		'vpn.valencia.witopia.net',
		'vpn.manchester.witopia.net',
		'vpn.milan.witopia.net',
		'vpn.moscow.witopia.net',
		'vpn.munich.witopia.net',
		'vpn.oslo.witopia.net',
		'vpn.paris.witopia.net',
		'vpn.prague.witopia.net',
		'vpn.riga.witopia.net',
		'vpn.rome.witopia.net',
		'vpn.stockholm.witopia.net',
		'vpn.vienna.witopia.net',
		'vpn.vilnius.witopia.net',
		'vpn.warsaw.witopia.net',
		'vpn.zurich.witopia.net',
		],
	'Asia' : [
		'vpn.cairo.witopia.net',
		'vpn.jerusalem.witopia.net',
		'vpn.bangkok.witopia.net',
		'vpn.hanoi.witopia.net',
		'vpn.hongkong.witopia.net',
		'vpn.kualalumpur.witopia.net',
		'vpn.newdelhi.witopia.net',
		'vpn.singapore.witopia.net',
		'vpn.seoul.witopia.net',
		'vpn.tokyo.witopia.net',
		],
	'Australia' : [
		'vpn.melbourne.witopia.net',
		'vpn.sydney.witopia.net',
		],
	'TCP' : [
		'tcpvpn.man.witopia.net',
		'tcpvpn.hkg.witopia.net',
		'tcpvpn.iad.witopia.net',
		'tcpvpn.lax.witopia.net',
		],
	}

def render_profiles(profile, **kwargs):
	""" Renders the profiles, one per region """
	# First check the profile template and write a default one if none exists
	if not os.path.isfile(profile):
		profile = os.path.realpath(profile)
		print >> sys.stderr, "Writing default Jinja2 template %s" % (profile)
		with open(profile, 'w') as f:
			f.write(default_j2tpl)
	inlines = []
	# Go through the files mentioned in the [files] section
	for n, f in kwargs.iteritems():
		if not os.path.isfile(f):
			if '*' in f or '?' in f:
				fl = glob(f)
				if len(fl) == 1:
					f = fl[0]
				else:
					return "ERROR: %sshell glob '%s' resolves to %d items: %r" % (n, f, len(fl), fl)
			else:
				return "ERROR: %s file '%s' must exist or be a shell glob resolving to exactly one file." % (n, f)
		with open(f, 'r') as f:
			inlines.append({ 'name': n, 'value': f.read() })
	env = Environment(loader=FileSystemLoader(os.path.dirname(profile)))
	tpl = env.get_template(os.path.basename(profile))
	protocols = { 'tcp' : { 'port': 443, 'name': 'tcp' }, 'udp' : { 'port': 1194, 'name': 'udp' } }
	for region, lst in servers.iteritems():
		print >> sys.stderr, "Region: %s (%d)" % (region, len(lst))
		proto = protocols['tcp'] if lst[1].startswith('tcpvpn.') else protocols['udp']
		with open('witopia_' + region.replace('/', '') + '.ovpn', 'w') as f:
			f.write(tpl.render(servers=lst, proto=proto, inlines=inlines))
	return 0

def main(conffile):
	""" Parses the INI or the defaults """
	try:
		ini = RawConfigParser()
		if os.path.exists(conffile):
			ini.read(conffile)
			print >> sys.stderr, "Read %s" % (conffile)
		else:
			fp = StringIO(default_ini)
			ini.readfp(fp)
			print >> sys.stderr, "Writing defaults to %s" % (conffile)
			with open(conffile, 'w') as f:
				f.write(default_ini)
		files = {}
		profile = None
		for scn in ini.sections():
			if 'files' == scn:
				for k, v in ini.items(scn):
					files[k] = v
			if 'templates' == scn:
				profile = ini.get(scn, 'profile')
		return render_profiles(profile, **files)
	except:
		raise

if __name__ == '__main__':
	sys.exit(main(conffile))
