#!/usr/bin/env bash
# http://llvm.org/docs/GettingStarted.html#compiling-the-llvm-suite-source-code
# possible alternative: https://github.com/rsmmr/install-clang
MEANDMYSELF=${0##*/}
LLVM_RELEASE="release_34"
LIBCXXRT_RELEASE="stable"
MUSLLIBC_RELEASE="v1.1.3"
BINUTILS_RELEASE="binutils-2_24"
INSTALL_TO=$HOME/bin/LLVM
TARGETS="x86,x86_64"
BASEDIR="${BASEDIR:-$(pwd)}"
let NOOPTIONAL=0
for tool in tee tar bzip2 sha1sum git date make cp; do type $tool > /dev/null 2>&1 || { echo "ERROR: couldn't find '$tool' which is required by this script."; exit 1; }; done

function show_help
{
	echo -e "Syntax: $MEANDMYSELF [-h|-?] [-B] [-C|-c|-p|-r] [-O] [-t <targets>] [-v]"
	echo -e "\t-h | -?"
	echo -e "\t  Show this help"
	echo -e "\t-B"
	echo -e "\t  Do not actually build anything, but check out and prepare build directory."
	echo -e "\t-c"
	echo -e "\t  Only check out updates from upstream, then exit."
	echo -e "\t-C"
	echo -e "\t  Do not check out from the upstream repository."
	echo -e "\t-O"
	echo -e "\t  Do not build 'optional' components (i.e. musl + binutils)."
	echo -e "\t-p"
	echo -e "\t  Same as -c but also packages the Git repos in a .tgz file."
	echo -e "\t-r"
	echo -e "\t  Revives the repositories previously packaged with -p. Implies -c."
	echo -e "\t  NB: to be called from the directory which contains ${MEANDMYSELF}."
	echo -e "\t-t <targets> (default=$TARGETS)"
	echo -e "\t  Specify the target architectures for LLVM/Clang (such as x86, x86_64 ...)."
	echo -e "\t-v"
	echo -e "\t  Be verbose about the actions (lines get leading '[DBG]' string)."
	echo ""
	echo -e "NOTE: the main difference between -c and -B is that -B will remove an existing"
	echo -e "      build directory and -c doesn't touch that at all."
}

function prepare_src
{
	local PRJNAME=${1%%:*}
	local GITCLONE=${1#*:}
	local GITREF=$2
	local PRJ=$(echo "${PRJNAME##*/}"|tr 'a-z' 'A-Z')
	if ((NOCHECKOUT==0)); then
		((VERBOSE)) && echo "[DBG:$PRJ] Working on project $PRJNAME ($GITCLONE), branch/tag = $GITREF."
		# Clone the repository if we don't have it
		((VERBOSE)) && echo "[DBG:$PRJ] Cloning repository if no clone exists."
		[[ -d "$BASEDIR/$PRJNAME" ]] || $GITCLONE "$BASEDIR/$PRJNAME"
		# Sanity check the clone
		((VERBOSE)) && echo "[DBG:$PRJ] Verifying the clone exists now."
		[[ -d "$BASEDIR/$PRJNAME/.git" ]] || { echo "ERROR: apparently we failed to clone $PRJNAME ($GITCLONE)."; exit 1; }
		# Set the Git stuff according to the docs
		((VERBOSE)) && echo "[DBG:$PRJ] Setting branch.master.rebase to true."
		( cd "$BASEDIR/$PRJNAME" && git config branch.master.rebase true ) || { echo "ERROR: could not set 'git config branch.master.rebase true' for $PRJNAME."; exit 1; }
		( cd "$BASEDIR/$PRJNAME" && echo -n "$PRJ: branch.master.rebase = " && git config --get branch.master.rebase )
		( cd "$BASEDIR/$PRJNAME" && if [[ "xtrue" == "x$(git config --get core.bare)" ]]; then git config --bool core.bare false; fi ) || { echo "ERROR: could not set 'git config --bool core.bare false' for $PRJNAME."; exit 1; }
		((REVIVEPKG)) && ( cd "$BASEDIR/$PRJNAME" && echo -ne "\tHard-resetting ($(git config --get core.bare)) after thawing it.\n\t-> "; git reset --hard )
		# Scrub the working copy
		((VERBOSE)) && echo "[DBG:$PRJ] Cleaning extraneous files from Git clone."
		( cd "$BASEDIR/$PRJNAME" && git clean -d -f ) || { echo "ERROR: failed to 'git clean' $PRJNAME."; exit 1; }
		# Get latest changes to the Git repo
		((VERBOSE)) && echo "[DBG:$PRJ] Fetching updates from upstream."
		( cd "$BASEDIR/$PRJNAME" && git fetch ) || { echo "WARNING: failed to 'git fetch' $PRJNAME."; }
		# Check out the release
		((VERBOSE)) && echo "[DBG:$PRJ] Checking out the files on current branch."
		( cd "$BASEDIR/$PRJNAME" && echo -n "$PRJ: " && git checkout $GITREF ) || { echo "ERROR: failed to check out $GITREF for $PRJNAME."; exit 1; }
		if git --git-dir="$BASEDIR/$PRJNAME/.git" rev-parse --symbolic --branches|grep -q "$GITREF"; then
			((VERBOSE)) && echo "[DBG:$PRJ] Fast-forwarding, if possible."
			( cd "$BASEDIR/$PRJNAME" && echo -n "$PRJ: " && git merge --ff-only origin/$GITREF ) || { echo "ERROR: failed to fast-forward to origin/$GITREF for $PRJNAME."; exit 1; }
		fi
	fi
	((ONLYCHECKOUT)) && return
	[[ -d "$BASEDIR/build/$PRJNAME" ]] && rm -rf "$BASEDIR/build/$PRJNAME"
	mkdir -p "$BASEDIR/build/$PRJNAME" || { echo "ERROR: could not create build/$PRJNAME directory."; exit 1; }
}

function show_time_diff
{
	local START=$1
	local END=$2
	local MSG=$3
	[[ -n "$MSG" ]] || MSG="Runtime: %s"
	local DIFF=$((END-START))
	local DIFF_MIN=$((DIFF/60))
	local DIFF_SEC=$((DIFF%60))
	printf "$MSG\n" $(printf "%d:%02d" "$DIFF_MIN" "$DIFF_SEC")
}

while getopts "h?BcCOprt:v" opt; do
	case "$opt" in
	h|\?)
		show_help
		exit 0
		;;
	c)  ((NOCHECKOUT)) && { echo "ERROR: -C and -c/-p/-r are mutually exclusive."; exit 1; }
		ONLYCHECKOUT=1
		echo "Doing only a checkout"
		;;
	C)  ((ONLYCHECKOUT)) && { echo "ERROR: -C and -c/-p/-r are mutually exclusive."; exit 1; }
		NOCHECKOUT=1
		echo "Skipping checkout"
		;;
	B)  NOBUILD=1
		echo "Skipping build"
		;;
	O)  NOOPTIONAL=1
		echo "Skipping build of optional components"
		;;
	p)  ((NOCHECKOUT)) && { echo "ERROR: -C and -p/-c are mutually exclusive."; exit 1; }
		ONLYCHECKOUT=1
		PACKAGEGITGZ=1
		echo "Doing only a checkout and then packaging bare clones into .tbz (requires tar+bzip2)."
		;;
	r)  ((NOCHECKOUT)) && { echo "ERROR: -C and -r/-c are mutually exclusive."; exit 1; }
		ONLYCHECKOUT=1
		REVIVEPKG=1
		echo "Reviving, followed by a checkout."
		;;
	t)  [[ -n "$OPTARG" ]] && TARGETS="$OPTARG"
		[[ -n "$OPTARG" ]] || { echo "ERROR: -$opt requires an argument." >&2; exit 1; }
		;;
	v)  VERBOSE=1
		((VERBOSE)) && echo "[DBG] Enabling verbose run."
		;;
	esac
done
echo -e "\tWorking directory: $BASEDIR"
let PM=$(grep -c processor /proc/cpuinfo)
((VERBOSE)) && echo "[DBG] Number of parallel jobs, based on processor count: $PM."
let TIME_START=$(date +%s)
((VERBOSE)) && echo "[DBG] Preparing core projects."
# Preparational steps
for i in "llvm:git clone http://llvm.org/git/llvm.git" "llvm/tools/clang:git clone http://llvm.org/git/clang.git" "llvm/projects/compiler-rt:git clone http://llvm.org/git/compiler-rt.git" "llvm/projects/libcxx:git clone http://llvm.org/git/libcxx.git" "llvm/tools/clang/tools/extra:git clone http://llvm.org/git/clang-tools-extra.git"; do
	prepare_src "$i" "$LLVM_RELEASE"
done
((VERBOSE)) && echo "[DBG] Preparing third-party projects."
prepare_src "llvm/projects/libcxxrt:git clone https://github.com/pathscale/libcxxrt" "$LIBCXXRT_RELEASE"
if ((NOOPTIONAL == 0)); then
	prepare_src "3rdparty/musl:git clone git://git.musl-libc.org/musl" "$MUSLLIBC_RELEASE"
	prepare_src "3rdparty/binutils:git clone git://sourceware.org/git/binutils-gdb.git" "$BINUTILS_RELEASE"
fi
let TIME_GIT=$(date +%s)
if ((ONLYCHECKOUT==0)) && ((NOBUILD==0)); then
	((VERBOSE)) && echo "[DBG] Doing build for $TARGETS into $INSTALL_TO."
	if [[ -d "$BASEDIR/build/llvm" ]]; then
		pushd "$BASEDIR/build/llvm" && \
			"$BASEDIR/llvm/configure" --prefix=$INSTALL_TO --disable-docs --enable-optimized --enable-targets=$TARGETS && \
			let TIME_CONFIGURE=$(date +%s) && \
			make -j$PM ENABLE_OPTIMIZED=1 DISABLE_ASSERTIONS=1 && \
			let TIME_MAKE=$(date +%s) && \
			make -j$PM ENABLE_OPTIMIZED=1 DISABLE_ASSERTIONS=1 install && \
		popd
		for i in scan-view scan-build; do
			cp -r "$BASEDIR/llvm/tools/clang/tools/$i"/*  "$INSTALL_TO/bin/"/ || { echo "WARNING: could not copy $i binaries/scripts."; }
		done
		let TIME_INSTALL=$(date +%s)
		if ((NOOPTIONAL == 0)); then
			pushd "$BASEDIR/3rdparty/binutils" && \
				CC="$INSTALL_TO/bin/clang" ./configure --disable-werror --disable-gold --enable-ld --program-suffix=.clang --prefix=$INSTALL_TO && \
				make -j$PM && \
				make install && \
			popd
		fi
		let TIME_BINUTILS=$(date +%s)
	else
		echo "ERROR: no directory $BASEDIR/build/llvm."
		exit 1
	fi
fi
if ((ONLYCHECKOUT==1)) || ((NOBUILD==1)); then
	show_time_diff $TIME_START $TIME_GIT      "Git operations took: %s"
fi
if ((PACKAGEGITGZ==1)); then
	TIMESTAMP=$(date +%Y-%m-%dT%H-%M-%S)
	TARNAME="packaged-${TIMESTAMP}-LLVM+musl+binutils.tbz"
	UNPACKER="unpack-$TIMESTAMP-LLVM"
	echo "Packaging the source into $TARNAME"
	(
		REVIVE=./revive
		cd "$BASEDIR"
		echo -e "#!/usr/bin/env bash\n./$MEANDMYSELF -r"|tee $REVIVE > /dev/null && chmod +x $REVIVE
		echo "Now packing the contents with tar+bzip2"
		tar -cjf "$TARNAME" $MEANDMYSELF $REVIVE $(find llvm 3rdparty -type d -name '.git') && \
			echo "Find the package under the name $TARNAME"
		rm $REVIVE
		echo -e "#!/usr/bin/env bash\necho \"Unpacking $TARNAME into ./$TIMESTAMP \$( [[ \"x\$1\" == \"x-c\" ]] && echo \"and removing archive plus unpacker upon success\" )\"\nmkdir \"./$TIMESTAMP\" && tar -C \"./$TIMESTAMP\" -xjf \"./$TARNAME\" && ( cd \"./$TIMESTAMP\" && [[ -x $REVIVE ]] && $REVIVE && rm -f $REVIVE )\n[[ \"x\$1\" == \"x-c\" ]] && { echo \"Also removing $UNPACKER and $TARNAME\"; rm -f \"./$UNPACKER\" \"./$TARNAME\"; }" \
			| tee "./$UNPACKER" > /dev/null && chmod +x "./$UNPACKER"
	)
	let TIME_TGZ=$(date +%s)
	show_time_diff $TIME_GIT $TIME_TGZ          "Packaging took:      %s"
fi
let TIME_END=$(date +%s)
if ((ONLYCHECKOUT==0)) && ((NOBUILD==0)); then
	show_time_diff $TIME_GIT $TIME_CONFIGURE    "./configure took:    %s"
	show_time_diff $TIME_CONFIGURE $TIME_MAKE   "GNU make took:       %s"
	show_time_diff $TIME_MAKE $TIME_INSTALL     "Installation took:   %s"
	show_time_diff $TIME_INSTALL $TIME_BINUTILS "Binutils took:       %s"
fi
show_time_diff $TIME_START $TIME_END      "Overall runtime:     %s (m:ss) with $PM parallel job(s)"
