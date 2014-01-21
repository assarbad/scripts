#!/usr/bin/env bash
# http://llvm.org/docs/GettingStarted.html#compiling-the-llvm-suite-source-code
# possible alternative: https://github.com/rsmmr/install-clang
MEANDMYSELF=${0##*/}
LLVM_RELEASE="release_34"
LIBCXXRT_RELEASE="stable"
INSTALL_TO=$HOME/bin/LLVM
TARGETS="x86,x86_64,powerpc,mips,sparc"
BASEDIR="$HOME/LLVM"

function show_help
{
	echo -e "Syntax: $MEANDMYSELF [-h|-?] [-B] [-C] [-t <targets>] [-v]"
	echo -e "\t-h | -?"
	echo -e "\t  Show this help"
	echo -e "\t-B"
	echo -e "\t  Do not actually build anything, but check out and prepare build directory."
	echo -e "\t-c"
	echo -e "\t  Only check out updates from upstream, then exit."
	echo -e "\t-C"
	echo -e "\t  Do not check out from the upstream repository."
	echo -e "\t-t <targets> (default=$TARGETS)"
	echo -e "\t  Specify the target architectures for LLVM/Clang (such as x86, x86_64 ...)."
	echo ""
	echo -e "NOTE: the main difference between -c and -B is that -B will remove an existing"
	echo -e "      build directory and -c doesn't touch that at all."
}

function prepare_src
{
	local PRJNAME=${1%%:*}
	local GITCLONE=${1#*:}
	local GITREF=$2
	if ((NOCHECKOUT==0)); then
		# Clone the repository if we don't have it
		[[ -d "$BASEDIR/$PRJNAME" ]] || $GITCLONE "$BASEDIR/$PRJNAME"
		# Sanity check the clone
		[[ -d "$BASEDIR/$PRJNAME/.git" ]] || { echo "ERROR: apparently we failed to clone $PRJNAME ($GITCLONE)."; exit 1; }
		# Set the Git stuff according to the docs
		( cd "$BASEDIR/$PRJNAME" && git config branch.master.rebase true ) || { echo "ERROR: could not set 'git config branch.master.rebase true' for $PRJNAME."; exit 1; }
		( cd "$BASEDIR/$PRJNAME" && echo -n "$(echo $PRJNAME|tr 'a-z' 'A-Z'): branch.master.rebase = " && git config --get branch.master.rebase )
		# Scrub the working copy
		( cd "$BASEDIR/$PRJNAME" && git clean -d -f -f ) || { echo "ERROR: failed to 'git clean' $PRJNAME."; exit 1; }
		# Get latest changes to the Git repo
		( cd "$BASEDIR/$PRJNAME" && git fetch ) || { echo "WARNING: failed to 'git fetch' $PRJNAME."; }
	fi
	((ONLYCHECKOUT)) && return
	# Check out the release
	( cd "$BASEDIR/$PRJNAME" && echo -n "$(echo $PRJNAME|tr 'a-z' 'A-Z'): " && git checkout $GITREF ) || { echo "ERROR: failed to check out $GITREF for $PRJNAME."; exit 1; }
	[[ -d "$BASEDIR/build-$PRJNAME" ]] && rm -rf "$BASEDIR/build-$PRJNAME"
	mkdir -p "$BASEDIR/build-$PRJNAME" || { echo "ERROR: could not create build-$PRJNAME directory."; exit 1; }
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
	printf "$MSG\n" $(printf "%d:%02d" $DIFF_MIN $DIFF_SEC)
}

while getopts "h?BcCt:" opt; do
	case "$opt" in
	h|\?)
		show_help
		exit 0
		;;
	c)  ((NOCHECKOUT)) && { echo "ERROR: -C and -c are mutually exclusive."; exit 1; }
		ONLYCHECKOUT=1
		echo "Doing only a checkout"
		;;
	C)  ((ONLYCHECKOUT)) && { echo "ERROR: -C and -c are mutually exclusive."; exit 1; }
		NOCHECKOUT=1
		echo "Skipping checkout"
		;;
	B)  NOBUILD=1
		echo "Skipping build"
		;;
	t)  [[ -n "$OPTARG" ]] && TARGETS="$OPTARG"
		[[ -n "$OPTARG" ]] || { echo "ERROR: -$opt requires an argument." >&2; exit 1; }
		;;
	esac
done
let PM=$(grep -c processor /proc/cpuinfo)
let TIME_START=$(date +%s)
if ((NOBUILD==0)); then
	# Preparational steps
	for i in "llvm:git clone http://llvm.org/git/llvm.git" "llvm/tools/clang:git clone http://llvm.org/git/clang.git" "llvm/projects/compiler-rt:git clone http://llvm.org/git/compiler-rt.git" "llvm/projects/libcxx:git clone http://llvm.org/git/libcxx.git" "llvm/tools/clang/tools/extra:git clone http://llvm.org/git/clang-tools-extra.git"; do
		prepare_src "$i" "$LLVM_RELEASE"
	done
	for i in "llvm/projects/libcxxrt:git clone https://github.com/pathscale/libcxxrt"; do
		prepare_src "$i" "$LIBCXXRT_RELEASE"
	done
	((ONLYCHECKOUT)) && exit
	let TIME_GIT=$(date +%s)
	if [[ -d "$BASEDIR/build-llvm" ]]; then
		pushd "$BASEDIR/build-llvm" && \
			"$BASEDIR/llvm/configure" --prefix=$INSTALL_TO --disable-docs --enable-optimized --enable-targets=$TARGETS && \
			let TIME_CONFIGURE=$(date +%s) && \
			make -j$PM ENABLE_OPTIMIZED=1 DISABLE_ASSERTIONS=1 && \
			let TIME_MAKE=$(date +%s) && \
			make -j$PM ENABLE_OPTIMIZED=1 DISABLE_ASSERTIONS=1 install && \
			let TIME_INSTALL=$(date +%s) && \
		popd
		for i in scan-view scan-build; do
			cp -r "$BASEDIR/llvm/tools/clang/tools/$i"/*  "$INSTALL_TO"/ || { echo "WARNING: could not copy $i binaries/scripts."; }
		done
	else
		echo "ERROR: no directory $BASEDIR/build-llvm."
		exit 1
	fi
fi
let TIME_END=$(date +%s)
show_time_diff $TIME_START $TIME_GIT      "Git operations took: %s"
show_time_diff $TIME_GIT $TIME_CONFIGURE  "./configure took:    %s"
show_time_diff $TIME_CONFIGURE $TIME_MAKE "GNU make took:       %s"
show_time_diff $TIME_MAKE $TIME_INSTALL   "Installation took:   %s"
show_time_diff $TIME_START $TIME_END      "Overall runtime:     %s (m:ss) with $PM parallel job(s)"
