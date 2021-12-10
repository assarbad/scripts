#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: set autoindent smartindent softtabstop=4 tabstop=4 shiftwidth=4 expandtab:
from __future__ import print_function, with_statement, unicode_literals, division, absolute_import
__author__ = "Oliver Schneider"
__copyright__ = "2017-2021 Oliver Schneider (assarbad.net), under Public Domain/CC0, or MIT/BSD license where PD is not applicable"
__version__ = "0.1.3"
import fnmatch
import io
import os
import re
import sys
import xml.etree.ElementTree as ET
from collections import OrderedDict
from functools import cache
# A script to parse the XML from exported key lists (MSDN)

good_keychars = set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-")


@cache
def keytype(s):
    types = {
         "kms": "kms",
         "MultipleActivation": "mak",
         "MAK": "mak",
         "mak": "mak",
         "RTL": "rtl",
         "rtl": "rtl",
         "Retail": "rtl",
         "Static Activation Key": "sta",
         "sta": "sta",
         "STA": "sta",
         "OEM Key": "oem",
         "OEM": "oem",
         "Azure Dev Tools for Teaching KMS": "kms",
         "vol": "vol",
         "VA 1.0": "vol",
         }
    if s in types:
        return types[s]
    else:
        print("NOTE: %s not in list of known key types" % (s), file=sys.stderr)
        return s


def genkey(tree):
    if isinstance(tree, ET.ElementTree):
        root = tree.getroot()
    else:
        root = tree
    # <Your_Product_Keys><Product_Key Name= Key= Key_Type= Date_Key_Claimed= /></Your_Product_Keys>
    if root.tag == "Your_Product_Keys":
        for key in root.iter("Product_Key"):
            if "Name" in key.attrib and "Key" in key.attrib:
                retkey = key.attrib["Key"]
                if set(retkey) <= good_keychars:
                    retval = {"Name": None, "Type": None, "Date": None}
                    retval["Name"] = key.attrib["Name"].strip()
                    if "Key_Type" in key.attrib:
                        retval["Type"] = keytype(key.attrib["Key_Type"].strip())
                    if "Date_Key_Claimed" in key.attrib:
                        datestr = key.attrib["Date_Key_Claimed"][0:10].strip()
                        retval["Date"] = tuple([int(x) for x in datestr.split("-")])
                    yield retkey, retval
    # <YourKey><Product_Key Name=><Key ID= Type= ClaimedDate= >$KEY</Key><Product_Key></Your_Product_Keys>
    elif root.tag[-7:] == "YourKey" or root.tag == "root":  # seems, convoluted but takes care of namespace
        for pdkeys in root.iter("Product_Key"):
            for key in pdkeys.iter("Key"):
                retkey = key.text
                if set(retkey) <= good_keychars:
                    retval = {"Name": None, "Type": None, "Date": None}
                    retval["Name"] = pdkeys.attrib["Name"].strip()
                    if "Type" in key.attrib:
                        retval["Type"] = keytype(key.attrib["Type"].strip())
                    if "ClaimedDate" in key.attrib and len(key.attrib["ClaimedDate"]):
                        datestr = key.attrib["ClaimedDate"].strip()
                        datetpl = tuple([int(x) for x in datestr.split("/")])
                        if datetpl[2] >= 2000:  # correct the idiotic US date format
                            datetpl = (datetpl[2], datetpl[0], datetpl[1])
                        retval["Date"] = datetpl
                    yield retkey, retval
    return


def cal_items(o, m):
    # CALs
    if m:
        caltype = "unknown-CAL-type"
        if m.group(2) in ["User CAL", "user connections"]:
            caltype = "users"
        elif m.group(2) in ["Device CAL", "device connections"]:
            caltype = "devices"
        return "Windows Server %s Terminal Server CAL [%s %s]" % (m.group(1), m.group(3), caltype)


CORRECTION_REGEXES = [
        (r"^(Visual Basic 2010 Express Registration Key|Visual Studio Express 2010 for Visual Basic Registration Key)",
            "Visual Studio Express 2010 (Visual Basic)"),
        (r"(Visual C# 2010 Express Registration Key|Visual Studio Express 2010 for Visual C# Registration Key)",
            "Visual Studio Express 2010 (Visual C#)"),
        (r"(Visual C\+\+ 2010 Express Registration Key|Visual Studio Express 2010 for Visual C\+\+ Registration Key)",
            "Visual Studio Express 2010 (Visual C++)"),
        (r"(Visual Studio \.NET|Visual Studio \.NET Professional)",
            "Visual Studio .NET Professional"),
        (r"(Visual Studio 2010 Professional|Visual Studio Professional 2010)",
            "Visual Studio Professional 2010"),
        (r"(Visual Studio Express 2012 for Web|Visual Studio Express 2012 for Windows 8)",
            "Visual Studio Express 2012 for Web (+Windows 8)"),
        (r"Windows Server (2003|2008|2008 R2|2012) (?:Terminal Server|Terminal Services|Remote Desktop Services) ((?:User CAL|user connections)|(?:Device CAL|device connections)) \((\d+)\)",  # noqa: E501
            cal_items),
        (r"^Windows Server (?:2004 |2004 or 20H2 |2019 )?Remote Desktop Services (user|device) connections\s\((\d+)\)",
            lambda o, m: "Windows Server (incl. 2004, 20H2, 2019) Remote Desktop Services {} connections ({})".format(m.group(1), m.group(2))),
        (r"Windows Web Server 2008|Windows HPC Server 2008 and Windows Web Server 2008",
            "Windows HPC (+Web) Server 2008"),
        (r"Windows Server 2008 Enterprise and Windows Server 2008 Standard|Windows Server 2008 Standard",
            "Windows Server 2008 Enterprise & Standard"),
        (r"(10-digit|Visual SourceSafe 6\.0|All products requiring a 10-digit product key|Legacy 10-digit product key)",
            "All legacy products requiring a 10-digit product key"),
        (r"Windows Embedded Compact 2013 \(MSDN\)|Windows Embedded Compact 2013",
            "Windows Embedded Compact 2013"),
        (r"Windows 8.1 Enterprise and Enterprise N|Windows 8.1 Enterprise, Enterprise N, Pro VL, and Pro N VL",
            "Windows 8.1 Enterprise, Enterprise N, Pro VL, and Pro N VL"),
        (r"(?:Windows Server 2012 Storage Server|Windows Storage Server 2012) (Standard|Workgroup)",
            lambda o, m: "Windows Storage Server 2012 {}".format(m.group(1))),
        (r"^Windows 10 (?:for )?Education N(?: and KN)?$",
            "Windows 10 for Education N (+KN)"),
        (r"^Windows (10|11) (?:for )?Education( N)?$",
            lambda o, m: "Windows {} for Education{}".format(m.group(1), m.group(2) or "")),
        (r"^Windows (10|11) Pro(?:fessional)? for Workstations( N)?$",
            lambda o, m: "Windows {} Pro for Workstations{}".format(m.group(1), m.group(2) or "")),
        (r"^Windows (10|11) Pro(?:fessional)?( N)? for Workstations$",
            lambda o, m: "Windows {} Pro for Workstations{}".format(m.group(1), m.group(2) or "")),
        (r"^Windows (10|11) Pro(fessional)?(?: \(BizSpark\))?$",
            lambda o, m: "Windows {} Pro".format(m.group(1))),
        (r"^Windows 10 Pro(?:fessional)? N(?: and KN)?$",
            "Windows 10 Pro N (+KN)"),
        (r"^Windows 11 Pro(?:fessional)? N$",
            "Windows 11 Pro N"),
        (r"^Windows Server (?:2004 |2004 or 20H2 |2019 )?(Standard|Datacenter)$",
            lambda o, m: "Windows Server {} (incl. 2004, 20H2, 2019)".format(m.group(1))),
        (r"^Windows 10 Enterprise 2015 LTSB N and KN$",
            "Windows 10 Enterprise 2015 LTSB N (+KN)"),
        (r"^Windows 10 Enterprise N(?: and KN)?$",
            "Windows 10 Enterprise N (+KN)"),
        (r"^Windows 11 Enterprise N(?: \(BizSpark\))?$",
            "Windows 11 Enterprise N"),
        (r"^Windows 10 Home N(?: and KN)?$",
            "Windows 10 Home N (+KN)"),
        (r"^Windows 11 Home N$",
            "Windows 11 Home N"),
        ]


CACHED_REGEXES = OrderedDict()


@cache
def correct_name(n):
    # Pre-populate the cache
    if not CACHED_REGEXES:
        for item in CORRECTION_REGEXES:
            if item not in CACHED_REGEXES:
                # Create cached compiled regex
                CACHED_REGEXES[item] = re.compile(item[0])

    subject = n.strip()
    for item, regex in CACHED_REGEXES.items():
        regex_string, replacement = item
        m = regex.match(subject)
        if m:
            if callable(replacement):
                return replacement(subject, m)
            return replacement

    # Return "unchanged" (only surrounding whitespace goes off)
    return subject


def dumpkeys(keys):
    prodkeys = {}
    for k, v in keys.items():
        nml = v["Name"]
        if isinstance(nml, list):
            nm = "|".join(sorted([x for x in set(nml)]))
            if nm not in prodkeys:
                prodkeys[nm] = []
            prodkeys[nm].append((k, v["Date"], v["Type"]))
        elif isinstance(nm, str):
            print("ERROR: not a list for '%s'. Skipping." % (k), file=sys.stderr)
    print("Number of products: %d" % (len(prodkeys)), file=sys.stderr)
    for pd in sorted(prodkeys.keys(), key=lambda v: v.lower()):
        (productnames, keys) = (pd, prodkeys[pd])
        # Skip these, no need as they aren't available longterm anyway ...
        if re.search(r"Preview|RC[0-9]|Beta|No key is required for this product", productnames):
            continue
        # productnames = correct_name(productnames)
        # ktypes = len(set([x[2] for x in keys]))
        print("%s" % ("\n".join(sorted(productnames.split("|")))))
        lastdate = None
        # List keys without date
        # for issues in [k for k in keys if k[1] is None]:
        #     print("WARNING: %s %s" % (pd, repr(issues)), file=sys.stderr)
        # Sort by date entries (primary) and key (secondary)
        # if len(keys) > 1:
        #     print(repr(keys[1]), file=sys.stderr)
        for key in sorted(keys, key=lambda v: (v[1][0:2] if v[1] is not None else (0, 0,), v[0])):
            ktype = " {%s}" % key[2]
            if len(key) > 1 and not key[1] is None:
                if lastdate is None:  # first iteration, so append the date
                    lastdate = key[1][0:2]
                    print("\t%s%s [%04d/%02d]" % (key[0], ktype, lastdate[0], lastdate[1]))
                else:  # subsequent iterations
                    if lastdate[0:2] == key[1][0:2]:
                        print("\t%s%s" % (key[0], ktype))
                    else:
                        lastdate = key[1][0:2]
                        print("\t%s%s [%04d/%02d]" % (key[0], ktype, lastdate[0], lastdate[1]))

            else:
                print("\t%s%s" % (key[0], ktype))


def main():
    if len(sys.argv) < 2:
        sys.exit("Usage: %s <directory with XML files|single XML file>" % sys.argv[0])
    p = sys.argv[1]
    if not os.path.exists(p):
        sys.exit("ERROR: %s not found." % p)
    # Get names of all XML files
    f = {}
    # Either take a single .xml file
    if (len(sys.argv) == 2) and fnmatch.fnmatch(sys.argv[1], '*.xml'):
        xmlfname = os.path.realpath(sys.argv[1])
        print("Single XML file: {}".format(xmlfname), file=sys.stderr)
        f[xmlfname] = {}
    # ... or a directory full of them
    else:
        for r, _, fnames in os.walk(p):
            for fn in fnmatch.filter(fnames, '*.xml'):
                f[os.path.join(r, fn)] = fn
    keys = {}
    fkeys = {}
    fsets = {}
    for fn in sorted(f.keys()):
        if fn not in fkeys:
            fkeys[fn] = {}
        xmldata = ""
        with io.open(fn, "r", encoding="utf-8") as xmlfile:
            # \u2019 (thin space) is contained in some exported XML files
            xmldata = re.sub(r' xmlns="[^"]+"', '', xmlfile.read().replace('\n', '').replace('\u2019', ' ').replace('\xa0', '').replace('\xc2', ''))
        if not len(xmldata):
            print("ERROR: %s appears to be empty or only line breaks." % (f[fn]), file=sys.stderr)
            continue
        try:
            tree = ET.fromstring(xmldata.encode("utf-8"))
            assert isinstance(tree, ET.Element), "The tree should be an ElementTree, but got %r" % (tree)
        except UnicodeError as e:
            print("Error: with file %s: %s. Ignoring that file." % (fn, e), file=sys.stderr)
            continue
        for k, v in genkey(tree):
            fkeys[fn][k] = v
            if k in keys:
                if keys[k] != v:
                    if keys[k]["Name"] != correct_name(v["Name"]):  # is it the same?
                        # Different names or different types?
                        if isinstance(keys[k]["Name"], list):  # oh, it's a list
                            realname = correct_name(v["Name"])
                            if realname.strip().lower() in "\n".join(keys[k]["Name"]).strip().lower():
                                continue  # skip this, it's in the list already
                            keys[k]["Name"].append(realname)
                            continue
                        elif isinstance(keys[k]["Name"], str):
                            keys[k]["Name"] = [correct_name(keys[k]["Name"])]  # make new list from string
                            continue
                        else:
                            print("WARNING: key %s already in list:\nold: %s\nnew: %s" % (k, keys[k], v), file=sys.stderr)
            else:
                v["Name"] = [correct_name(v["Name"])]  # make list
                keys[k] = v
    keycount = 0
    previous_unique = set()
    nonew = []
    for fn in sorted(fkeys.keys()):
        ks = fkeys[fn]
        keycount = keycount + len(ks)
        fsets[fn] = set(fkeys[fn].keys())
        previous_count = len(previous_unique)
        previous_unique |= fsets[fn]
        if len(previous_unique) - previous_count == 0:
            nonew.append(fn)
        print("File: %s -> %d keys [+ %d -> unique: %d]" % (fn, len(ks), len(previous_unique) - previous_count, len(previous_unique)), file=sys.stderr)
    print("%d unique keys found" % (len(keys)), file=sys.stderr)
    print("%d keys found (with duplicates)" % (keycount), file=sys.stderr)
    dumpkeys(keys)
    if len(nonew):
        print("\nNo new keys in the following files:\n", file=sys.stderr)
        for fn in sorted(nonew):
            print(fn, file=sys.stderr)


if __name__ == "__main__":
    main()
