import os, re, sys
from os.path import basename, dirname, join, realpath
try:
	import pefile
except ImportError:
	try:
		sys.path.append(join(realpath(dirname(__file__)), "pefile"))
		import pefile
	except:
		raise

def main(pename):
	from pefile import PE
	print "Parsing %s" % pename
	pe = PE(pename)
	if not getattr(pe, "DIRECTORY_ENTRY_EXPORT", None):
		return "ERROR: given file has no exports."
	modname = basename(pename)
	libname = re.sub(r"(?i)^.*?([^\\/]+)\.(?:dll|exe|sys|ocx)$", r"\1.lib", modname)
	defname = libname.replace(".lib", ".def")
	print "Writing module definition file %s for %s" % (defname, modname)
	with open(defname, "w") as f: # want it to throw, no sophisticated error handling here
		print >>f, "LIBRARY %s\n" % (modname)
		print >>f, "EXPORTS"
		numexp = 0
		for exp in [x for x in pe.DIRECTORY_ENTRY_EXPORT.symbols if x.name]:
			numexp += 1
			print >>f, "\t%s" % (exp.name)
	print "Wrote %s with %d exports" % (defname, numexp)
	print "\n\nUse this to create the export lib:\n\tlib /def:%s /out:%s" % (defname, libname)

if __name__ == '__main__':
	if len(sys.argv) != 2:
		sys.exit("ERROR:\n\tSyntax: fakelib <dllfile>\n")
	sys.exit(main(sys.argv[1]))
