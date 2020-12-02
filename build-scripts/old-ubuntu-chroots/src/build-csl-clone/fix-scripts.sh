#!/usr/bin/env bash
[[ -t 1 ]] && { cG="\e[1;32m"; cR="\e[1;31m"; cB="\e[1;34m"; cW="\e[1;37m"; cY="\e[1;33m"; cG_="\e[0;32m"; cR_="\e[0;31m"; cB_="\e[0;34m"; cW_="\e[0;37m"; cY_="\e[0;33m"; cZ="\e[0m"; export cR cG cB cY cW cR_ cG_ cB_ cY_ cW_ cZ; }
pushd $(dirname $0) > /dev/null; CURRABSPATH=$(readlink -nf "$(pwd)"); popd > /dev/null; # Get the directory in which the script resides
TOOLS_NEEDED="readlink rm cat chmod chown sed mawk head tee"
for tool in $TOOLS_NEEDED; do type $tool > /dev/null 2>&1 || { echo -e "${cR}ERROR:${cZ} couldn't find '$tool' which is required by this script."; exit 1; }; done
set -e
for script in src/arm-20*-arm-none-linux-gnueabi.sh; do
	F=${script##*/}
	NEWNAME=${script%.sh}
	RELNAME0=${NEWNAME##*/}
	RELNAME=${RELNAME0%-arm-*}
	TRIPLET=${RELNAME0#$RELNAME-}
	RELNUM=${RELNAME#arm-}
	RELDT=${RELNUM%-*}
	[[ -f "$NEWNAME" ]] && rm -f "$NEWNAME"
	(set -x; sed -E \
		-e 's|^\t\t|                |g' \
		-e 's|^\t|        |g' \
		-e 's|/scratch/maciej/arm-linux-2014\.05-rel|\${SCRATCH}/\${TCRELEASE}|g' \
		-e 's|/scratch/jroelofs/builds/fallrelease|\${SCRATCH}/\${TCRELEASE}|g' \
		-e 's|/scratch/jbrown/2013\.05-arm-linux-release|\$SCRATCH/\$TCRELEASE|g' \
		-e 's|/scratch/jbrown/arm-linux|\${SCRATCH}/\${TCRELEASE}|g' \
		-e 's|/scratch/nsidwell/arm/linux/src/|\$CURRABSPATH/|g' \
		-e 's|/scratch/nsidwell/arm/linux|\${SCRATCH}/\${TCRELEASE}|g' \
		-e "s|'--with-hosts=i686-pc-linux-gnu i686-mingw32'|--with-hosts=i686-pc-linux-gnu|g" \
		-e 's|--exclude=host-i686-mingw32 ||g' \
		-e '/^\/usr\/local\/tools\/gcc-4.3.3\/bin\/i686-pc-linux-gnu-strip/ s|\/usr\/local\/tools\/gcc-4.3.3\/bin\/||' \
		-e 's|--with-xml-catalog-files=/usr/local/tools/gcc-4.3.3/share/sgml/docbook/docbook-xsl/catalog.xml |--with-xml-catalog-files=|' \
		-e 's|i686-pc-linux-gnu|\${TCBUILD}|g' \
		-e 's|/opt/codesourcery|\${TCPREFIX}|g' \
		-e 's|'$RELNUM'|\${TCRELNUM}|g' \
		-e 's|-'$TRIPLET'|\${TCHOST}|g' \
		-e 's|'$TRIPLET'|\${TCTRIPLET}|g' \
		-e 's|Sourcery CodeBench Lite |\${TCNAME} |g' \
		-e 's|Sourcery CodeBench Lite |\${TCNAME}|g' \
		-e "s| '--with-brand=Sourcery CodeBench Lite'||g" \
		-e 's|-'$RELDT'|-\${TCRELDATE}|g' \
		-e 's|/'$RELDT'|/\${TCRELDATE}|g' \
		-e "s|<<'EOF0'|<<EOF0|g" \
		-e '/^pushenvvar CSL_SCRIPTDIR/d' \
		-e '/^pushenvvar PATH/d' \
		-e '/^pushenvvar LD_LIBRARY_PATH/d' \
		-e '/^pushenvvar FLEXLM_NO_CKOUT_INSTALL_LIC/d' \
		-e '/^pushenvvar LM_APP_DISABLE_CACHE_READ/d' \
		-e "/^pushenvvar/ s|'|\"|g" \
		-e '/^pushenvvar/ s|-ar rc"|-ar"|g' \
		-e '/^pushenvvar/ s|\s+"$|"|g' \
		-e '/^mkdir -p/ { /\/obj$/s|/obj$|/{obj,src}|g }' \
		-e 's|^make -j4|make -j\$NUMCPUS|g' \
		-e 's| --with-bugurl=https://support.codesourcery.com/GNUToolchain/||g' \
		-e 's|/\./|/|g' \
		-e 's|\s+$||g' \
		-e "s|'(--with-pkgversion=[^']*)'|\"\\1\"|g" \
		"$script" > "$NEWNAME.sed" )
	AWKSCRIPT=$(cat << EOF
BEGIN {
	TASKS=0;
	REMOVED_TASKS=0;
}
function correct_tasknum(taskstr) {
	orig = taskstr
	# Remove surrounding brackets
	gsub(/\\[/, "", taskstr)
	gsub(/\\]/, "", taskstr)
	# Get parts
	split(taskstr, a, "/")
	gsub(/^0+/, "", a[1])
	gsub(/^0+/, "", a[2])
	t = int(a[1])
	tasks = int(a[2])
	gsub(/^/, "was: ", taskstr)
	return sprintf("%03i [%s]", t-REMOVED_TASKS, taskstr)
}
FNR==1 {
	print "SCRATCH=\${SCRATCH:-\$CURRABSPATH/scratch}"
	print "TCRELEASE=\${TCRELEASE:-$RELNAME}"
	print "TCRELNUM=\${TCRELEASE#arm-}"
	print "TCNAME=\${TCNAME:-CSL-clone}"
	print "TCRELDATE=\${TCRELNUM%-*}"
	print "TCPREFIX=\${TCPREFIX:-/opt/\$TCRELEASE}"
	print "TCTRIPLET=\${TCTRIPLET:-$TRIPLET}"
	print "TCHOST=\${TCHOST:-\"-\$TCTRIPLET\"}"
	print "TCBUILD=\${TCBUILD:-\$(uname -m)-linux-gnu}"
	print "BLDDATE=\$(date +'%Y%m%d')"
	print "BLDLOG=\"\$CURRABSPATH/build_\$BLDDATE.log\""
	print "let NUMCPUS=\$(grep -c processor /proc/cpuinfo || echo 4)"
	print "let START_TASK=\${START_TASK:-0}"
	print "let OVERALL_START=\$(date +%s)"
	print ""
	print "function run_configure"
	print "{"
	print "\tlocal CONFIGURE=\"\$1\""
	print "\tlocal CONFPATH=\"\${CONFIGURE%/*}\""
	print "\tlocal TIMESTAMP=\"\$(date +%Y-%m-%dT%H-%M-%S)\""
	print "\techo \"\$TIMESTAMP = \$(pwd)\"|tee -a \"\$BLDLOG\""
	print "\techo \"\$TIMESTAMP +\" \"\$@\"|tee -a \"\$BLDLOG\""
	print "\tcase \"\$CONFPATH\" in"
	print "\t\t# This fixes an issue where configure ends up in an infinite loop (addressed by re-running autoconf)"
	print "\t\t*/obj/glibc-src-*)"
	# print "\t\t\tif [[ \"\${CONFPATH##*/}\" == \"default\" ]]; then"
	# print "\t\t\t\techo \"\$TIMESTAMP | autoconf [in \${CONFPATH%/*}]\"|tee -a \"\$BLDLOG\""
	# print "\t\t\t\t( set -x; cd \"\${CONFPATH%/*}\"; autoconf )"
	# print "\t\t\tfi"
	print "\t\t\techo \"\$TIMESTAMP | autoconf [in \$CONFPATH]\"|tee -a \"\$BLDLOG\""
	print "\t\t\t( set -x; cd \"\$CONFPATH\"; autoconf )"
	print "\t\t\t;;"
	print "\t\t*)"
	print "\t\t\t;;"
	print "\tesac"
	print "\t( set -x; pwd; \"\$@\" )"
	print "}"
	print ""
	print "function make"
	print "{"
	print "\tlocal TIMESTAMP=\"\$(date +%Y-%m-%dT%H-%M-%S)\""
	print "\techo \"\$TIMESTAMP = \$(pwd)\"|tee -a \"\$BLDLOG\""
	print "\techo \"\$TIMESTAMP + make\" \"\$@\"|tee -a \"\$BLDLOG\""
	print "\t( set -x; pwd; command make \"\$@\" )"
	print "}"
	print ""
	next
}
# Remove unused functions, by commenting them out
\$0 ~ /^(update_dir_clean|copy_dir_exclude|copy_dir_only)\s*\(\)/ {
	print "# " \$0
	do {
		getline
		print "# " \$0
		if (\$1 ~ /}/) {
			break
		}
	} while(1);
	next
}
# Fix the path passed as first argument to copy_dir_clean()
TASKS > 0 && \$1 ~ /^copy_dir_clean\$/ && \$2 ~ /^\\\${SCRATCH}\// {
	gsub(/\\\${SCRATCH}\/\\\${TCRELEASE}\/src\//, "\$CURRABSPATH\/", \$2)
	print
	next
}
# Remove check_mentor_trademarks function
\$0 ~ /^check_mentor_trademarks\s*\(\)/ {
	do {
		getline
		if (\$1 ~ /}/) {
			break
		}
	} while(1);
	next
}
# Remove the license file code
/_LICENSE_FILE\)/ {
	do {
		getline
		if (/;;\$/) {
			next
		}
	} while(1);
}
# Remove calls to check_mentor_trademarks, which end up calling configure in the directory passed as arg #1
\$1 ~ /^check_mentor_trademarks/ {
	gsub(/^check_mentor_trademarks /, "")
	gsub(/^.+\$/, sprintf("%s/configure", \$1), \$1)
	print
	next
}
# Remove mingw32 tasks
\$1 ~ /#/ && \$2 ~ /^task\$/ && \$4 ~ /i686-mingw32/ {
	TASKS++
	REMOVED_TASKS++
	gsub(/^.+$/, sprintf("REMOVED: %s", \$2), \$2)
	gsub(/\\[/, "[was: ", \$3)
	print
	do {
		getline
		if (\$1 ~ /#/ && \$2 ~ /^task\$/) {
			TASKS++
			if (\$4 ~ /i686-mingw32/) { # another such block
				REMOVED_TASKS++
				gsub(/^.+$/, sprintf("REMOVED: %s", \$2), \$2)
				gsub(/\\[/, "[was: ", \$3)
				print
			} else {
				print
				break
			}
		}
	} while(1);
	next
}
# Remove source package tasks
# also remove: /init/cleanup and */gmp/postinstall (the check is failing on recent systems) ...
\$1 ~ /#/ && \$2 ~ /^task\$/ && ( \$4 ~ /\/init\/(source_package|cleanup)/ || \$4 ~ /\/gmp\/postinstall\$/ ) {
	TASKS++
	REMOVED_TASKS++
	\$1 = ""
	\$2 = "Task"
	gsub(/^.+$/, sprintf("REMOVED: %s", \$2), \$2)
	gsub(/\\[/, "[was: ", \$3)
	gsub(/^[ \t]+/, "", \$0) # trim leading blanks
	printf "printf \"\${cR}-- \${cZ}%s\${cZ}%sn\"\n", \$0, "\\\\"
	FALLTHROUGH=0
	do {
		getline
		if (\$1 ~ /#/ && \$2 ~ /^task\$/) {
			TASKS++
			if (\$4 ~ /\/init\/(source_package|cleanup)/ || \$4 ~ /\/gmp\/postinstall\$/) { # another such block
				REMOVED_TASKS++
				\$1 = ""
				\$2 = "Task"
				gsub(/^.+$/, sprintf("REMOVED: %s", \$2), \$2)
				gsub(/\\[/, "[was: ", \$3)
				gsub(/^[ \t]+/, "", \$0) # trim leading blanks
				printf "printf \"\${cR}-- \${cZ}%s\${cZ}%sn\"\n", \$0, "\\\\"
			} else {
				FALLTHROUGH=1
				TASKS--
				break
			}
		}
	} while(1);
	if(!FALLTHROUGH) next
}
# Fix all the task descriptions to be both comment and output
/^# task \[/ {
	\$2 = "Task"
	if (TASKS) {
		print "let CURRTIME=\$(date +%s)"
		printf "echo \"\$(date +%%Y-%%m-%%dT%%H-%%M-%%S) Task took: \$((CURRTIME-TASK_START)) seconds (\$((CURRTIME-OVERALL_START)) seconds overall)\"|tee -a \"\$BLDLOG\"\n"
		printf "fi\n\n"
	} else {
		printf "trap 'echo \"\$(date +%%Y-%%m-%%dT%%H-%%M-%%S) Last executing task: \$TASKS_SO_FAR (to continue from there: env START_TASK=\$TASKS_SO_FAR ...)\"|tee -a \"\$BLDLOG\"; trap - INT TERM EXIT; exit \$?' INT TERM EXIT\n"
	}
	TASKS++
	printf "let TASKS_SO_FAR=%i\n", TASKS-REMOVED_TASKS
	print "if ((START_TASK <= TASKS_SO_FAR)); then"
	printf "let TASK_START=\$(date +%%s)\n"
	\$3 = correct_tasknum(\$3)
	print
	\$1 = ""
	gsub(/^[ \t]+/, "", \$0) # trim leading blanks
	printf "printf \"\${cW}%s\${cZ}%sn\"\n", \$0, "\\\\"
	printf "echo \"\$(date +%%Y-%%m-%%dT%%H-%%M-%%S) %s\"|tee -a \"\$BLDLOG\"\n", \$0
	next
}
# Adjust output for the version info text file
/^Version Information\$/ {
	print
	do {
		getline
		if (\$1 ~ /^Host\$/ && \$2 ~ /^spec/) {
			gsub(/ i686-mingw32/, "")
		}
		print
		if (\$1 ~ /^Target:/) {
			break
		}
	} while(1);
	next
}
/^Build Information\$/ {
	print
	do {
		getline
		if (\$1 ~ /^Build/) {
			if (\$2 ~ /^date:/) {
				gsub(/^\\d+$/, "\$BLDDATE", \$3)
			}
		}
		print
		if (/^EOF0/) {
			break
		}
	} while(1);
	next
}
TASKS > 0 && \$1 ~ /^pushenvvar\$/ && \$2 ~ /^(CC_FOR_BUILD|CC|CXX)\$/ {
	if (\$3 !~ /^\"/ && \$3 !~ /\"\$/) {
		gsub(/^/, "\"\${USE_CCACHE:+\$USE_CCACHE }", \$3)
		gsub(/\$/, "\"", \$3)
		print
	} else {
		gsub(/^\"/, "\"\${USE_CCACHE:+\$USE_CCACHE }", \$3)
		print
	}
	next
}
# Replace double slashes in paths with single one and get rid of /./ in paths as well
TASKS > 0 && \$1 ~ /^(copy|chmod|touch|rm|cp|ln|\\\${SCRATCH}\/|\\\${TCRELNUM}-objcopy)/ {
	# We loop to replace as often as it takes
	do {
		SLINE=\$0
		gsub(/\/\//, "/", \$0)
		gsub(/\/\.\//, "/", \$0)
	} while(SLINE != \$0)
}
# Make the configure command visible by enabling -x
TASKS > 0 && \$1 ~ /\/configure\$/ {
	printf "run_configure \"%s\"", \$1
	\$1 = ""
	print
	#printf "( set -x; %s )\n", \$0
	next
}
# Simply pass through
{
	print
}
END {
	printf "echo \"\$(date +%%Y-%%m-%%dT%%H-%%M-%%S) Task took: \$((\$(date +%%s)-TASK_START)) seconds\"|tee -a \"\$BLDLOG\"\n"
	print("fi\n")
	printf "REMOVED_TASKS=%i\n", REMOVED_TASKS
	printf "OVERALL_TASKS=%i\n", TASKS-REMOVED_TASKS
	printf "ORIGINAL_TASKS=%i\n", TASKS
}
EOF
)
	(set -x; head -n3 "$0"|tee "$NEWNAME"; mawk "$AWKSCRIPT" "$NEWNAME.sed"|mawk -v RS= -v ORS='\n\n' '1' >> "$NEWNAME" && chmod +x "$NEWNAME")
	(set -x; rm "$NEWNAME.sed")
done
