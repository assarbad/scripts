#!/usr/bin/env python27
# -*- coding: ascii -*-
# vim: set autoindent smartindent softtabstop=4 tabstop=4 shiftwidth=4 expandtab:
from __future__ import print_function, with_statement, unicode_literals, division, absolute_import
import argparse
import fnmatch
import io
import os
import re
import sys

# Don't create .pyc or .pyo files
sys.dont_write_bytecode = True

re_cfgopen = re.compile(r"^[\s\t]+<Configuration(?:\r?\n)*$")
re_attr = re.compile(r'^[\s\t]+([A-Za-z0-9_][^=<]+)="([^"]*)"(?:\r?\n)*$')
re_cfgclose = re.compile(r"^[\s\t]+>(?:\r?\n)*$")
re_elemstart = re.compile(r"^[\s\t]+<([A-Za-z0-9_][^\r\n]+)(?:\r?\n)*$")
re_cfgend = re.compile(r"^[\s\t]+</Configuration>(?:\r?\n)*$")
re_elemend = re.compile(r"^[\s\t]+/>(?:\r?\n)*$")
re_attrx = re.compile(r'^([\s\t]+)(?:[A-Za-z0-9_][^=<]+)(=")(?:[^"]*)("(?:\r?\n)*)$')
verbose = 0

cfg_fixes = {
    "Debug|Win32" : { "OutputDirectory" : "$(SolutionDir)bin\dbg32" },
    "Debug|x64" : { "OutputDirectory" : "$(SolutionDir)bin\dbg64" },
    "Release|Win32" : { "OutputDirectory" : "$(SolutionDir)bin\rel32" },
    "Release|x64" : { "OutputDirectory" : "$(SolutionDir)bin\rel64" },
    "*" : {
        "IntermediateDirectory" : "$(SolutionDir)intermediate\$(ProjectName).$(PlatformName)_$(ConfigurationName)",
        "InheritedPropertySheets" : "$(SolutionDir)IncludeDirectories.vsprops;$(SolutionDir)OutputLocations.vsprops",
    },
}

def special_cases(basename, line, lineno, elems, attr, value, wanted_value):
    # check circumstances and manipulate the return value
    return wanted_value

def modified_line(basename, line, lineno, elems, attr, value, wanted_value):
    if wanted_value != value:
        wanted_value = special_cases(basename, line, lineno, elems, attr, value, wanted_value)
        if wanted_value != value:
            if verbose > 0:
                if verbose > 1:
                    print("\t\t/%s/@%s <= %r" % ("/".join(elems), attr, wanted_value), file=sys.stderr)
                else:
                    print("\t\t/%s/@%s" % ("/".join(elems), attr), file=sys.stderr)
            attrlist = line.split("\"")
            assert len(attrlist) == 3, "Attribute line (%s:%d) does not conform to expected format.\n%s" % (basename, lineno, line.strip())
            newline = "\"".join([attrlist[0], wanted_value, attrlist[2]])
            return (lineno, line, newline)
    if verbose > 0:
        print("\t\tSkipping %s at %s:%d. Already modified." % (attr, basename, lineno), file=sys.stderr)
    return None

def process_vcproj(fpath, dryrun):
    basename = os.path.basename(fpath)
    print("Processing %s <%s>" % (basename, fpath), file=sys.stderr)
    inp, out, elems, mods, lineno, cfgname = [], [], [], [], 0, None
    with io.open(fpath, "rb") as inputfile:
        while True:
            line = inputfile.readline()
            out.append(line) # always append after reading, no matter what was read
            lineno += 1
            if not line:
                if verbose > 0:
                    print("\tDone after %d line(s)" % (lineno), file=sys.stderr)
                break
            # <Configuration
            if re_cfgopen.match(line):
                assert re_elemstart.match(line), "This line (%s:%d) should also open an element.\n%s" % (basename, lineno, line.strip())
                elems = ["Configuration"]
                line = inputfile.readline()
                out.append(line) # always append after reading, no matter what was read
                lineno += 1
                if not line:
                    raise RuntimeError("PANIC: unexpected end of input! (%s:%d)" % (basename, lineno))
                # <Configuration Name="..."
                m = re_attr.match(line)
                assert m, "Expected line (%s:%d) to be the Name attribute for <%s />.\n" % (basename, lineno, elems[-1], line.strip())
                assert m.group(1) == "Name", "Expected line (%s:%d) to be the Name attribute for <%s />.\n" % (basename, lineno, elems[-1], line.strip())
                cfgname = m.group(2)
                if not cfgname in cfg_fixes and "*" not in cfg_fixes:
                    assert cfgname not in cfg_fixes
                    if verbose > 0:
                        print("\tEntering <%s Name=\"%s\" />, skipping to tools (%s:%d)" % (elems[-1], cfgname, basename, lineno), file=sys.stderr)
                    while True:
                        line = inputfile.readline()
                        out.append(line) # always append after reading, no matter what was read
                        lineno += 1
                        if not line:
                            raise RuntimeError("PANIC: end of input from nested loop! (%s:%d)" % (basename, lineno))
                        if re_cfgclose.match(line):
                            cfgname = None
                            break
                        assert re_attr.match(line), "Expected an attribute assignment line (%s:%d).\n%s" % (basename, lineno, line.strip()) # up to the closing ">" we should see one attribute per line
                else:
                    seenattr = set()
                    if verbose > 0:
                        print("\tEntering <%s Name=\"%s\" /> for attribute patching (%s:%d)" % (elems[-1], cfgname, basename, lineno), file=sys.stderr)
                    assert cfgname in cfg_fixes or "*" in cfg_fixes
                    loc_fixes = cfg_fixes[cfgname]
                    if "*" in cfg_fixes:
                        for k, v in cfg_fixes["*"].iteritems():
                            if k not in loc_fixes:
                                loc_fixes[k] = v
                    needattr = set(loc_fixes.keys())
                    while True:
                        line = inputfile.readline()
                        out.append(line) # always append after reading, no matter what was read
                        lineno += 1
                        if not line:
                            raise RuntimeError("PANIC: end of input from nested loop! (%s:%d)" % (basename, lineno))
                        if re_cfgclose.match(line):
                            missing = needattr - seenattr
                            if len(missing):
                                preclose = out.pop()
                                for attr in missing:
                                    m = re_attrx.match(out[-1])
                                    assert m, "This must match (%s:%d), anything else is an error.\n%s" % (basename, lineno, out[-1].strip())
                                    newline = "%s%s%s%s%s" % (m.group(1), attr, m.group(2), loc_fixes[attr], m.group(3))
                                    if verbose > 0:
                                        print("\t\t\tInserting missing: %s" % (attr), file=sys.stderr)
                                    mods.append((lineno, None, newline,))
                                    out.append(newline)
                                out.append(preclose)
                            cfgname = None
                            break
                        m = re_attr.match(line)
                        assert m, "Expected to find an attribute assignment line (%s:%d).\n%s" % (basename, lineno, line.strip()) # up to the closing ">" we should see one attribute per line
                        attr, value = m.group(1), m.group(2)
                        assert attr not in seenattr, "Attribute %s already seen before?! Setting it twice is probably an error." % (attr)
                        seenattr.add(attr)
                        if attr in loc_fixes:
                            moddedline = modified_line(basename, line, lineno, elems, attr, value, loc_fixes[attr])
                            if moddedline:
                                line = moddedline[2]
                                mods.append(moddedline)
                                out.pop() # remove last line from output stack
                                out.append(line) # put the modified line instead
            if cfgname is not None:
                # Find <Tool /> elements until we hit </Configuration>
                while True:
                    line = inputfile.readline()
                    out.append(line) # always append after reading, no matter what was read
                    lineno += 1
                    if not line:
                        raise RuntimeError("PANIC: end of input when looking for <Tool /> elements and </Configuration>! (%s:%d)" % (basename, lineno))
                    # Early closing </Configuration>
                    if re_cfgend.match(line):
                        cfgname = None
                        break # found the closing </Configuration>
                    m = re_elemstart.match(line)
                    assert m, "Expected line (%s:%d) to open a <Tool /> element.\n%s" % (basename, lineno, line.strip())
                    assert m.group(1) == "Tool", "Expected line (%s:%d) to open a <Tool /> element.\n%s" % (basename, lineno, line.strip())
                    while True:
                        line = inputfile.readline()
                        out.append(line) # always append after reading, no matter what was read
                        lineno += 1
                        if not line:
                            raise RuntimeError("PANIC: end of input inside <Tool /> element! (%s:%d)" % (basename, lineno))
                        if toolname:
                            if re_elemend.match(line):
                                break
                            m = re_attr.match(line)
                            assert m, "Expected line (%s:%d) with attribute of <Tool /> element.\n%s" % (basename, lineno, line.strip())
                            assert isinstance(cfgname, basestring)
                            # TODO: additional fixes?!
                        else:
                            m = re_attr.match(line)
                            assert m, "Expected line (%s:%d) with Name attribute of <Tool /> element.\n%s" % (basename, lineno, line.strip())
                            assert m.group(1) == "Name", "Expected line (%s:%d) to be a Name attribute line.\n%s" % (basename, lineno, line.strip())
                            toolname = m.group(2)
    if len(mods) > 0:
        if dryrun:
            print("\t%d modification(s) needed" % (len(mods)), file=sys.stderr)
            if verbose > 0:
                print("Modifications to %s" % (basename))
                print("=" * 70)
                for lno, oldline, newline in mods:
                    print("@@ -%d,1 +%d,1 @@" % (lno, lno))
                    if oldline is not None:
                        print("-", oldline.rstrip())
                    if newline is not None:
                        print("+", newline.rstrip())
        else:
            with io.open(fpath, "wb") as outputfile:
                outputfile.write("".join(out))
                if verbose > 0:
                    print("\t%d modification(s) applied" % (len(mods)), file=sys.stderr)
        return (len(mods), lineno,)
    return (0, lineno,)

def main(**kwargs):
    dirs = kwargs.get("dirs", ["."])
    dryrun = kwargs.get("dryrun", False)
    global verbose
    verbose = kwargs.get("verbose", 0)
    modsum, linesum, filesum = 0, 0, 0
    for dir in dirs:
        if not os.path.exists(dir):
            print("Warning: %s not found." % (dir), file=sys.stderr)
        for r, _, fnames in os.walk(dir):
            for fn in fnmatch.filter(fnames, '*.vcproj'):
                fpath = os.path.join(r, fn)
                modnum, lineno = process_vcproj(fpath, dryrun)
                filesum += 1
                modsum += modnum
                linesum += lineno
    print("SUMMARY: %d modification(s) on %d line(s) %shave been applied to %d file(s)" % (modsum, linesum, "would (DRY RUN!) " if dryrun else "", filesum), file=sys.stderr)
    return 0

def parse_args():
    from argparse import ArgumentParser
    parser = ArgumentParser(description="Manipulate .vcproj files (tested with VS2005)")
    parser.add_argument('dirs', metavar='DIRECTORY', type=str, nargs='+',
                    help='Directories in which to apply the changes')
    parser.add_argument("-v", "--verbose", action="count", default=0,
                        help="Turn up verbosity to see more details of what is going on. Use several v to increase the verbosity level, e.g. '-vvv'.")
    parser.add_argument("-D", "--dryrun", "--dry", "--dry-run", action="store_true", default=False,
                        help="Will perform a dry run. Meaning that none of the actions will actually change files.")
    return parser.parse_args()

if __name__ == "__main__":
    args = parse_args()
    try:
        sys.exit(main(**vars(args)))
    except SystemExit:
        pass
    except ImportError:
        raise # re-raise
    except RuntimeError:
        raise # re-raise
    except:
        raise # re-raise
