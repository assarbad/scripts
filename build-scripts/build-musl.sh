#!/usr/bin/env bash
[[ -t 1 ]] && { cG="\e[1;32m"; cR="\e[1;31m"; cB="\e[1;34m"; cW="\e[1;37m"; cY="\e[1;33m"; cG_="\e[0;32m"; cR_="\e[0;31m"; cB_="\e[0;34m"; cW_="\e[0;37m"; cY_="\e[0;33m"; cZ="\e[0m"; export cR cG cB cY cW cR_ cG_ cB_ cY_ cW_ cZ; }
( [[ -n "$DEBUG" ]] || [[ -n "$DBG" ]] ) && set -x
MEANDMYSELF=${0##*/}
MUSLLIBC_RELEASE="v1.1.15"
INSTALL_TO=${INSTALL_TO:-$HOME/bin/musl}
BASEDIR="${BASEDIR:-$(pwd)}"
CACHEDIR="$BASEDIR/cache"
for tool in grep tee git date make gcc; do type $tool > /dev/null 2>&1 || { echo -e "${cR}ERROR:${cZ} couldn't find '$tool' which is required by this script."; exit 1; }; done

function show_help
{
	echo -e "Syntax: $MEANDMYSELF [-h|-?] [-i <install-dir>] [-v] [-s|-S] [-a|-A]"
	echo -e "\t${cW}-h | -?${cZ}"
	echo -e "\t  Show this help"
	echo -e "\t${cW}-i${cZ}"
	echo -e "\t  Set the installation directory. Can also be done by setting ${cW}INSTALL_TO${cZ}."
	echo -e "\t${cW}-v${cZ}"
	echo -e "\t  Be verbose about the actions (lines get leading '${cB}[DBG]${cZ}' string)."
	echo ""
}

function prepare_src
{
	local PRJNAME=${1%%:*}
	local GITCLONE=${1#*:}
	local GITREF=$2
	local PRJ=$(echo "${PRJNAME##*/}"|tr 'a-z' 'A-Z')
	if ((NOCHECKOUT==0)); then
		[[ -d "$CACHEDIR" ]] || mkdir -p "$CACHEDIR"
		((VERBOSE)) && echo -e "${cB}[DBG:$PRJ]${cZ} Working on project $PRJNAME ($GITCLONE), branch/tag = $GITREF."
		# Clone the repository if we don't have it
		((VERBOSE)) && echo -e "${cB}[DBG:$PRJ]${cZ} Cloning repository if no clone exists."
		[[ -d "$CACHEDIR/$PRJNAME" ]] || $GITCLONE "$CACHEDIR/$PRJNAME"
		# Sanity check the clone
		((VERBOSE)) && echo -e "${cB}[DBG:$PRJ]${cZ} Verifying the clone exists now."
		[[ -d "$CACHEDIR/$PRJNAME/.git" ]] || { echo -e "${cR}ERROR:${cZ} apparently we failed to clone $PRJNAME ($GITCLONE)."; exit 1; }
		# Set the Git stuff according to the docs
		((VERBOSE)) && echo -e "${cB}[DBG:$PRJ]${cZ} Setting branch.master.rebase to true."
		( cd "$CACHEDIR/$PRJNAME" && git config branch.master.rebase true ) || { echo -e "${cR}ERROR:${cZ} could not set 'git config branch.master.rebase true' for $PRJNAME."; exit 1; }
		( cd "$CACHEDIR/$PRJNAME" && echo -en "${cW}$PRJ:${cZ} branch.master.rebase = " && git config --get branch.master.rebase )
		( cd "$CACHEDIR/$PRJNAME" && if [[ "xtrue" == "x$(git config --get core.bare)" ]]; then git config --bool core.bare false; fi ) || { echo -e "${cR}ERROR:${cZ} could not set 'git config --bool core.bare false' for $PRJNAME."; exit 1; }
		((REVIVEPKG)) && ( cd "$CACHEDIR/$PRJNAME" && echo -ne "\tHard-resetting ($(git config --get core.bare)) after thawing it.\n\t-> "; git reset --hard )
		# Scrub the working copy
		((VERBOSE)) && echo -e "${cB}[DBG:$PRJ]${cZ} Cleaning extraneous files from Git clone."
		( cd "$CACHEDIR/$PRJNAME" && git clean -d -f ) || { echo -e "${cR}ERROR:${cZ} failed to 'git clean' $PRJNAME."; exit 1; }
		# Get latest changes to the Git repo
		((VERBOSE)) && echo -e "${cB}[DBG:$PRJ]${cZ} Fetching updates from upstream."
		( cd "$CACHEDIR/$PRJNAME" && git fetch ) || { echo -e "${cY}WARNING:${cZ} failed to 'git fetch' $PRJNAME."; }
		# Check out the release
		((VERBOSE)) && echo -e "${cB}[DBG:$PRJ]${cZ} Checking out the files on current branch."
		( cd "$CACHEDIR/$PRJNAME" && echo -en "${cW}$PRJ:${cZ} " && git checkout $GITREF ) || { echo -e "${cR}ERROR:${cZ} failed to check out $GITREF for $PRJNAME."; exit 1; }
		if git --git-dir="$CACHEDIR/$PRJNAME/.git" rev-parse --symbolic --branches|grep -q "$GITREF"; then
			((VERBOSE)) && echo -e "${cB}[DBG:$PRJ]${cZ} Fast-forwarding, if possible."
			( cd "$CACHEDIR/$PRJNAME" && echo -en "${cW}$PRJ:${cZ} " && git merge --ff-only origin/$GITREF ) || { echo -e "${cR}ERROR:${cZ} failed to fast-forward to origin/$GITREF for $PRJNAME."; exit 1; }
		fi
		((GARBAGECOLLECT)) && ( echo "Now garbage-collecting the repository${GCAGGRESSIVE:+ ($GCAGGRESSIVE)}"; cd "$CACHEDIR/$PRJNAME" && git gc $GCAGGRESSIVE --prune=all)
	fi
	((ONLYCHECKOUT)) && return
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

[[ "$1" == "--help" ]] && { show_help; exit 0; }
while getopts "h?saSAi:v" opt; do
	case "$opt" in
	h|\?)
		show_help
		exit 0
		;;
	i)  [[ -n "$OPTARG" ]] || { echo -e "${cR}ERROR:${cZ} ${cY}-$opt${cZ} requires an argument." >&2; exit 1; }
		INSTALL_TO="$OPTARG"
		;;
	v)  VERBOSE=1
		((VERBOSE)) && echo -e "${cB}[DBG]${cZ} Enabling verbose run."
		;;
	*)
		echo -e "${cY}WARNING:${cZ} unknown option '$opt'"
		;;
	esac
done
echo -e "Working directory: $BASEDIR"
let PM=$(grep -c processor /proc/cpuinfo)
((VERBOSE)) && echo -e "${cB}[DBG]${cZ} Number of parallel jobs, based on processor count: $PM."
let TIME_START=$(date +%s)
((VERBOSE)) && echo -e "${cB}[DBG]${cZ} Preparing core projects."
PRJNAME="musl-libc"
prepare_src "$PRJNAME:git clone http://git.musl-libc.org/cgit/musl/" "$MUSLLIBC_RELEASE"

TARGETARCH=$(gcc -dumpmachine)
TARGETDUPL=${TARGETARCH#*-}
TARGETARCH=${TARGETARCH%%-*}
if [[ "$TARGETARCH" == "x86_64" ]] && [[ $(gcc -dumpmachine) == $(gcc -print-multiarch) ]]; then
	if gcc -print-multi-lib|grep -q '^32;'; then
		echo -e "${cW}INFO:${cZ} Building 32-bit ${cW}and${cZ} 64-bit Intel/AMD musl-libc"
		TARGETARCH=$TARGETARCH,i386
		let SPECIALSPEC=1
	fi
fi
echo -e "TARGETARCH=$TARGETARCH"

# --bindir=DIR            user executables [EPREFIX/bin]
# --libdir=DIR            library files for the linker [PREFIX/lib]
# --includedir=DIR        include files for the C compiler [PREFIX/include]
# --syslibdir=DIR         location for the dynamic linker [/lib]
for tgt in ${TARGETARCH//,/ }; do
	echo -e "${cW}$tgt${cZ}"
	((VERBOSE)) && echo -e "${cB}[DBG:$PRJ]${cZ} Cleaning extraneous files from Git clone."
	( cd "$CACHEDIR/$PRJNAME" && git clean -d -f ) || { echo -e "${cR}ERROR:${cZ} failed to 'git clean' $PRJNAME."; exit 1; }
	case "$tgt" in
	i?86|x86_32) # 32-bit Intel/AMD
		( \
			PREFIX="$INSTALL_TO" ; \
			BITNESS="32" ; \
			{ ((SPECIALSPEC)) && { DIRS="--bindir=$PREFIX/bin$BITNESS --libdir=$PREFIX/lib$BITNESS --includedir=$PREFIX/include$BITNESS"; rm -rf "$PREFIX/"{bin,lib,include}$BITNESS; true ; } || { rm -rf "$PREFIX/"{bin,lib,include}; true; } ; } ; \
			cd "$CACHEDIR/$PRJNAME" && \
			make distclean && \
			( set -x; env CFLAGS=-m$BITNESS ./configure --prefix="$PREFIX" $(echo "$DIRS ")--disable-shared --target="${tgt}-${TARGETDUPL}" ) && \
			cp config.mak "../${tgt}-config.mak" && \
			make -j $PM && \
			make install \
			)
		;;
	x86_64) # 64-bit Intel/AMD
		( \
			PREFIX="$INSTALL_TO" ; \
			BITNESS="64" ; \
			{ ((SPECIALSPEC)) && { DIRS="--bindir=$PREFIX/bin$BITNESS --libdir=$PREFIX/lib$BITNESS --includedir=$PREFIX/include$BITNESS"; rm -rf "$PREFIX/"{bin,lib,include}$BITNESS; true ; } || { rm -rf "$PREFIX/"{bin,lib,include}; true; } ; } ; \
			cd "$CACHEDIR/$PRJNAME" && \
			make distclean && \
			( set -x; env CFLAGS=-m$BITNESS ./configure --prefix="$PREFIX" $(echo "$DIRS ")--disable-shared --target="${tgt}-${TARGETDUPL}" ) && \
			cp config.mak "../${tgt}-config.mak" && \
			make -j $PM && \
			make install \
			)
		;;
	*) # native
		( \
			cd "$CACHEDIR/$PRJNAME" && \
			make distclean && \
			./configure --prefix="$INSTALL_TO" --disable-shared && \
			cp config.mak "../${tgt}-config.mak" && \
			make -j $PM && \
			make install \
			)
		;;
	esac
done

let TIME_END=$(date +%s)
show_time_diff $TIME_START $TIME_END      "Overall runtime:     %s (m:ss) with $PM parallel job(s)"
