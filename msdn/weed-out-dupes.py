#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: set autoindent smartindent softtabstop=4 tabstop=4 shiftwidth=4 expandtab:
from __future__ import print_function, with_statement, unicode_literals, division, absolute_import

__author__ = "Oliver Schneider"
__copyright__ = "2021 Oliver Schneider (assarbad.net), under Public Domain/CC0, or MIT/BSD license where PD is not applicable"
__version__ = "0.1"
import fnmatch
import io
import os
import re
import sys
import xml.etree.ElementTree as ET
from collections import OrderedDict

# from functools import cache
# A script to consolidate the XML from exported key lists (MSDN)
# The names of passed .xml files or .xml files in passed directories are processed in
# descending order (e.g. when named YYYYMMD_KeysExport.xml, the newest will be first)
# where the first file plays a special role in that we only care about keys not in that
# XML file, but in the other ones.

good_keychars = set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-")
TOO_MANY_THRESHOLD = 60


def genkey(tree):
    if isinstance(tree, ET.ElementTree):
        root = tree.getroot()
    else:
        root = tree
    # NB: Only the newer format for now
    # <YourKey><Product_Key Name=><Key ID= Type= ClaimedDate= >$KEY</Key><Product_Key></Your_Product_Keys>
    if root.tag[-7:] == "YourKey" or root.tag == "root":  # seems, convoluted but takes care of namespace
        for pdkeys in root.iter("Product_Key"):
            for key in pdkeys.iter("Key"):
                retkey = key.text
                if set(retkey) <= good_keychars:
                    yield retkey


def yield_known_keys(tree, knownset):
    if isinstance(tree, ET.ElementTree):
        root = tree.getroot()
    else:
        root = tree
    # NB: Only the newer format for now
    # <YourKey><Product_Key Name=><Key ID= Type= ClaimedDate= >$KEY</Key><Product_Key></Your_Product_Keys>
    if root.tag[-7:] == "YourKey" or root.tag == "root":  # seems, convoluted but takes care of namespace
        for pdkeys in root.iter("Product_Key"):
            assert "Name" in pdkeys.attrib, "Expected the <Product_Key /> to have a name "
            for key in pdkeys.iter("Key"):
                if key.text in knownset:
                    yield pdkeys.attrib["Name"], key


def main():
    if len(sys.argv) < 2:
        sys.exit("Usage: %s <XML files or dirs ...>" % sys.argv[0])
    f = {}
    # Go through all the paths given on the command line
    for argpath in sys.argv[1:]:
        if fnmatch.fnmatch(argpath, "*.xml"):
            xmlfname = os.path.realpath(argpath)
            f[xmlfname] = argpath
        elif os.path.isdir(argpath):
            for r, _, fnames in os.walk(argpath):
                for fn in fnmatch.filter(fnames, "*.xml"):
                    f[os.path.realpath(os.path.join(r, fn))] = fn
    fkeys = OrderedDict()
    xmltrees = OrderedDict()
    first = None
    nondupes = set()
    # Sort path names in descending order and extract keys per file
    # The first one plays a special role
    for fname in sorted(f.keys(), reverse=True):
        xmldata = ""
        with io.open(fname, "r", encoding="utf-8") as xmlfile:
            # \u2019 (thin space) is contained in some exported XML files
            xmldata = re.sub(r' xmlns="[^"]+"', "", xmlfile.read().replace("\n", "").replace("\u2019", " ").replace("\xa0", "").replace("\xc2", ""))
        if not len(xmldata):
            print("ERROR: %s appears to be empty or only line breaks." % (f[fname]), file=sys.stderr)
            continue
        try:
            tree = ET.fromstring(xmldata.encode("utf-8"))
            assert isinstance(tree, ET.Element), "The tree should be an ElementTree, but got %r" % (tree)
            print("Parsed: {}".format(fname), file=sys.stderr)
            xmltrees[fname] = tree
            current = set()
            for key in genkey(tree):
                current.add(key)
            if first is None:
                first = current
            elif fname not in fkeys:
                fkeys[fname] = current
        except UnicodeError as e:
            print("Error: with file %s: %s. Ignoring that file." % (fname, e), file=sys.stderr)
            continue
    toomany = set()
    # Try to figure out the keys that are uniqe with each new file
    for fname, keyset in fkeys.items():
        if keyset is None:
            print("WARNING: empty set in {}".format(fname), file=sys.stderr)
            continue
        uniqueset = keyset - first - nondupes
        if uniqueset:
            print("{} unique keys in {}".format(len(uniqueset), fname), file=sys.stderr)
            if len(uniqueset) >= TOO_MANY_THRESHOLD:
                toomany.add(fname)
            else:
                nondupes |= uniqueset
    # Now remove the files with too many new uniques
    for fname in toomany:
        del fkeys[fname]
        del xmltrees[fname]
    # Container to hold string fragments from which we'll build XML later
    newtree_products = {}
    # Go through the list once more, this time collecting XML nodes
    for fname, tree in xmltrees.items():
        for prodname, keynode in yield_known_keys(tree, nondupes):
            if prodname not in newtree_products:
                newtree_products[prodname] = set()
            newtree_products[prodname].add(ET.tostring(keynode, encoding="unicode"))
    xmlstrings = ["<root><YourKey>"]
    for prodname in sorted(newtree_products.keys()):
        keys = [x for x in newtree_products[prodname]]
        xmlstrings.append('<Product_Key Name="{}" KeyRetrievalNote="">{}</Product_Key>'.format(prodname, "".join(sorted(keys))))
    xmlstrings.append("</YourKey></root>")
    xml = ET.fromstringlist(xmlstrings)
    print(ET.tostring(xml, encoding="unicode"))


if __name__ == "__main__":
    main()
