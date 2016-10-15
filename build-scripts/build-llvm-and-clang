#!/usr/bin/env bash
# http://llvm.org/docs/GettingStarted.html#compiling-the-llvm-suite-source-code
# possible alternative: https://github.com/rsmmr/install-clang
[[ -t 1 ]] && { cG="\e[1;32m"; cR="\e[1;31m"; cB="\e[1;34m"; cW="\e[1;37m"; cY="\e[1;33m"; cG_="\e[0;32m"; cR_="\e[0;31m"; cB_="\e[0;34m"; cW_="\e[0;37m"; cY_="\e[0;33m"; cZ="\e[0m"; export cR cG cB cY cW cR_ cG_ cB_ cY_ cW_ cZ; }
( [[ -n "$DEBUG" ]] || [[ -n "$DBG" ]] ) && { DBG=1; DEBUG=1; set -x; }
MEANDMYSELF=${0##*/}
LLVM_RELEASE="${LLVM_RELEASE:-release_39}"
BINUTILS_RELEASE="${BINUTILS_RELEASE:-binutils-2_27}"
INSTALL_TO=${INSTALL_TO:-$HOME/bin/LLVM}
BASEDIR="${BASEDIR:-$(pwd)}"
TARGETS="Native"
let NOOPTIONAL=0
for tool in tee tar bzip2 sha1sum git date make cp; do type $tool > /dev/null 2>&1 || { echo -e "${cR}ERROR:${cZ} couldn't find '$tool' which is required by this script."; exit 1; }; done

function show_help
{
	echo -e "Syntax: $MEANDMYSELF [-h|-?] [-B] [-C|-c|-p|-r] [-g] [-i <install-dir>] [-O] [-t <targets>] [-v]"
	echo -e "\t${cW}-h | -?${cZ}"
	echo -e "\t  Show this help"
	echo -e "\t${cW}-B${cZ}"
	echo -e "\t  Do not actually build anything, but check out and prepare build directory."
	echo -e "\t${cW}-c${cZ}"
	echo -e "\t  Only check out updates from upstream, then exit."
	echo -e "\t${cW}-C${cZ}"
	echo -e "\t  Do not check out from the upstream repository."
	echo -e "\t${cW}-g${cZ}"
	echo -e "\t  Garbage collect after checkout."
	echo -e "\t${cW}-G${cZ}"
	echo -e "\t  Garbage collect aggressively (${cW}git gc --aggressive${cZ}) after checkout."
	echo -e "\t${cW}-i${cZ}"
	echo -e "\t  Set the installation directory. Can also be done by setting ${cW}INSTALL_TO${cZ}."
	echo -e "\t${cW}-O${cZ}"
	echo -e "\t  Do not build 'optional' components (i.e. binutils)."
	echo -e "\t${cW}-p${cZ}"
	echo -e "\t  Same as ${cW}-c${cZ} but also packages the Git repos in a .tgz file."
	echo -e "\t${cW}-r${cZ}"
	echo -e "\t  Revives the repositories previously packaged with ${cW}-p${cZ}. Implies ${cW}-c${cZ}."
	echo -e "\t  ${cW}NB:${cZ} to be called from the directory which contains ${MEANDMYSELF}."
	echo -e "\t${cW}-t${cZ} <targets> (default=Native)"
	echo -e "\t  Specify the target architectures for LLVM/Clang."
	echo -e "\t${cW}-v${cZ}"
	echo -e "\t  Be verbose about the actions (lines get leading '${cB}[DBG]${cZ}' string)."
	echo ""
	echo -e "${cW}NOTE:${cZ} the main difference between ${cW}-c${cZ} and ${cW}-B${cZ} is that ${cW}-B${cZ} will remove an existing"
	echo -e "      build directory and ${cW}-c${cZ} doesn't touch that at all."
}

function prepare_src
{
	local PRJNAME=${1%%:*}
	local GITCLONE=${1#*:}
	local GITREF=$2
	local PRJ=$(echo "${PRJNAME##*/}"|tr 'a-z' 'A-Z')
	if ((NOCHECKOUT==0)); then
		((VERBOSE)) && echo -e "${cB}[DBG:$PRJ]${cZ} Working on project $PRJNAME ($GITCLONE), branch/tag = $GITREF."
		# Clone the repository if we don't have it
		((VERBOSE)) && echo -e "${cB}[DBG:$PRJ]${cZ} Cloning repository if no clone exists."
		[[ -d "$BASEDIR/$PRJNAME" ]] || $GITCLONE "$BASEDIR/$PRJNAME"
		# Sanity check the clone
		((VERBOSE)) && echo -e "${cB}[DBG:$PRJ]${cZ} Verifying the clone exists now."
		[[ -d "$BASEDIR/$PRJNAME/.git" ]] || { echo -e "${cR}ERROR:${cZ} apparently we failed to clone $PRJNAME ($GITCLONE)."; exit 1; }
		# Set the Git stuff according to the docs
		((VERBOSE)) && echo -e "${cB}[DBG:$PRJ]${cZ} Setting branch.master.rebase to true."
		( cd "$BASEDIR/$PRJNAME" && git config branch.master.rebase true ) || { echo -e "${cR}ERROR:${cZ} could not set 'git config branch.master.rebase true' for $PRJNAME."; exit 1; }
		( cd "$BASEDIR/$PRJNAME" && echo -en "${cW}$PRJ:${cZ} branch.master.rebase = " && git config --get branch.master.rebase )
		( cd "$BASEDIR/$PRJNAME" && if [[ "xtrue" == "x$(git config --get core.bare)" ]]; then git config --bool core.bare false; fi ) || { echo -e "${cR}ERROR:${cZ} could not set 'git config --bool core.bare false' for $PRJNAME."; exit 1; }
		((REVIVEPKG)) && ( cd "$BASEDIR/$PRJNAME" && echo -ne "\tHard-resetting ($(git config --get core.bare)) after thawing it.\n\t-> "; git reset --hard )
		# Scrub the working copy
		((VERBOSE)) && echo -e "${cB}[DBG:$PRJ]${cZ} Cleaning extraneous files from Git clone."
		( cd "$BASEDIR/$PRJNAME" && git clean -d -f -x) || { echo -e "${cR}ERROR:${cZ} failed to 'git clean -d -f -x' $PRJNAME."; exit 1; }
		# Get latest changes to the Git repo
		((VERBOSE)) && echo -e "${cB}[DBG:$PRJ]${cZ} Fetching updates from upstream."
		( cd "$BASEDIR/$PRJNAME" && git fetch ) || { echo -e "${cY}WARNING:${cZ} failed to 'git fetch' $PRJNAME."; }
		# Prune branches
		((VERBOSE)) && echo -e "${cB}[DBG:$PRJ]${cZ} Pruning remote branches."
		( cd "$BASEDIR/$PRJNAME" && git remote prune origin ) || { echo -e "${cY}WARNING:${cZ} failed to 'git remote prune origin' $PRJNAME."; }
		# Check out the release
		((VERBOSE)) && echo -e "${cB}[DBG:$PRJ]${cZ} Checking out the files on current branch."
		( cd "$BASEDIR/$PRJNAME" && echo -en "${cW}$PRJ:${cZ} " && git checkout -f $GITREF ) || { echo -e "${cR}ERROR:${cZ} failed to check out $GITREF for $PRJNAME."; exit 1; }
		if git --git-dir="$BASEDIR/$PRJNAME/.git" rev-parse --symbolic --branches|grep -q "$GITREF"; then
			((VERBOSE)) && echo -e "${cB}[DBG:$PRJ]${cZ} Fast-forwarding, if possible."
			( cd "$BASEDIR/$PRJNAME" && echo -en "${cW}$PRJ:${cZ} " && git merge --ff-only origin/$GITREF ) || { echo -e "${cR}ERROR:${cZ} failed to fast-forward to origin/$GITREF for $PRJNAME."; exit 1; }
		fi
		((GARBAGECOLLECT)) && ( echo "Now garbage-collecting the repository${GCAGGRESSIVE:+ ($GCAGGRESSIVE)}"; cd "$BASEDIR/$PRJNAME" && git gc $GCAGGRESSIVE --prune=all)
	fi
	((ONLYCHECKOUT)) && return
	[[ -d "$BASEDIR/build/$PRJNAME" ]] && rm -rf "$BASEDIR/build/$PRJNAME"
	mkdir -p "$BASEDIR/build/$PRJNAME" || { echo -e "${cR}ERROR:${cZ} could not create build/$PRJNAME directory."; exit 1; }
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
while getopts "h?BcCgGi:Oprt:v" opt; do
	case "$opt" in
	h|\?)
		show_help
		exit 0
		;;
	c)  ((NOCHECKOUT)) && { echo -e "${cR}ERROR:${cZ} ${cY}-C${cZ} and ${cY}-c${cZ}/${cY}-p${cZ} are mutually exclusive."; exit 1; }
		ONLYCHECKOUT=1
		echo "Doing only a checkout"
		;;
	C)  ((ONLYCHECKOUT)) && { echo -e "${cR}ERROR:${cZ} ${cY}-C${cZ} and ${cY}-c${cZ}/${cY}-p${cZ} are mutually exclusive."; exit 1; }
		NOCHECKOUT=1
		echo -e "${cY}Skipping checkout${cZ}"
		;;
	B)  NOBUILD=1
		echo -e "${cY}Skipping build${cZ}"
		;;
	g)  GARBAGECOLLECT=1
		;;
	G)  GARBAGECOLLECT=1
		GCAGGRESSIVE="--aggressive"
		;;
	i)  [[ -n "$OPTARG" ]] || { echo -e "${cR}ERROR:${cZ} ${cY}-$opt${cZ} requires an argument." >&2; exit 1; }
		INSTALL_TO="$OPTARG"
		;;
	O)  NOOPTIONAL=1
		echo -e "${cY}Skipping build of optional components${cZ}"
		;;
	p)  ((NOCHECKOUT)) && { echo -e "${cR}ERROR:${cZ} ${cY}-C${cZ} and ${cY}-p${cZ}/${cY}-c${cZ} are mutually exclusive."; exit 1; }
		ONLYCHECKOUT=1
		PACKAGEGITGZ=1
		echo "Doing only a checkout and then packaging bare clones into .tbz (requires tar+bzip2)."
		;;
	r)  ((NOCHECKOUT)) || ONLYCHECKOUT=1
		REVIVEPKG=1
		echo "Reviving bare repos, followed a checkout."
		;;
	t)  [[ -n "$OPTARG" ]] && TARGETS="$OPTARG"
		[[ -n "$OPTARG" ]] || { echo -e "${cR}ERROR:${cZ} ${cY}-$opt${cZ} requires an argument." >&2; exit 1; }
		;;
	v)  VERBOSE=1
		((VERBOSE)) && echo -e "${cB}[DBG]${cZ} Enabling verbose run."
		;;
	esac
done
if ((${LLVM_RELEASE##*_} > 36)); then
	if ((ONLYCHECKOUT == 0)); then
		echo -e "${cW}INFO:${cZ} preparing for build using CMake"
		for tool in cmake; do type $tool > /dev/null 2>&1 || { echo -e "${cR}ERROR:${cZ} couldn't find '$tool' which is required by this script."; exit 1; }; done
		let CMAKE_BUILD=1
	fi
	TARGETS="Native"
else
	if ((ONLYCHECKOUT == 0)); then
		let CMAKE_BUILD=0
		echo -e "${cW}INFO:${cZ} preparing for build using autotools"
	fi
	TARGETS="x86,x86_64"
fi
echo -e "\tWorking directory: $BASEDIR"
let PM=$(grep -c processor /proc/cpuinfo)
((VERBOSE)) && echo -e "${cB}[DBG]${cZ} Number of parallel jobs, based on processor count: $PM."
let TIME_START=$(date +%s)
((VERBOSE)) && echo -e "${cB}[DBG]${cZ} Preparing core projects."
# Preparational steps
for i in "llvm:git clone http://llvm.org/git/llvm.git" "llvm/tools/clang:git clone http://llvm.org/git/clang.git" "llvm/projects/compiler-rt:git clone http://llvm.org/git/compiler-rt.git" "llvm/projects/libcxx:git clone http://llvm.org/git/libcxx.git" "llvm/projects/libcxxabi:git clone http://llvm.org/git/libcxxabi.git" "llvm/tools/clang/tools/extra:git clone http://llvm.org/git/clang-tools-extra.git"; do
	prepare_src "$i" "$LLVM_RELEASE"
done
((VERBOSE)) && echo -e "${cB}[DBG]${cZ} Preparing third-party projects."
if ((NOOPTIONAL == 0)); then
	prepare_src "3rdparty/binutils:git clone git://sourceware.org/git/binutils-gdb.git" "$BINUTILS_RELEASE"
fi
let TIME_GIT=$(date +%s)
if ((ONLYCHECKOUT==0)) && ((NOBUILD==0)); then
	((VERBOSE)) && echo -e "${cB}[DBG]${cZ} Doing build for $TARGETS into $INSTALL_TO."
	if [[ -d "$BASEDIR/build/llvm" ]]; then
		pushd "$BASEDIR/build/llvm" || { echo -e "${cR}ERROR:${cZ} could not ${cW}pushd${cZ}."; exit 1; }
		if (( CMAKE_BUILD )); then
			( set -x; cmake ${TRACE:+--trace} -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$INSTALL_TO" -DLLVM_BUILD_DOCS=OFF -DLLVM_ENABLE_DOXYGEN=OFF -DCMAKE_BUILD_TYPE="Release" -DLLVM_TARGETS_TO_BUILD="${TARGETS//,/;}" "$BASEDIR/llvm" ) || { echo -e "${cR}ERROR:${cZ}  ${cW}cmake${cZ} failed."; exit 1; }
		else
			( set -x; "$BASEDIR/llvm/configure" --prefix=$INSTALL_TO --disable-docs --disable-doxygen --enable-optimized --enable-targets=$TARGETS ) || { echo -e "${cR}ERROR:${cZ}  ${cW}./configure${cZ} failed."; exit 1; }
		fi
		let TIME_CONFIGURE=$(date +%s)
		( set -x; make -j$PM ENABLE_OPTIMIZED=1 DISABLE_ASSERTIONS=1 ${DBG:+TOOL_VERBOSE=1} )  || { echo -e "${cR}ERROR:${cZ}  ${cW}make${cZ} failed."; exit 1; }
		let TIME_MAKE=$(date +%s)
		( set -x; make -j$PM ENABLE_OPTIMIZED=1 DISABLE_ASSERTIONS=1 ${DBG:+TOOL_VERBOSE=1} install )  || { echo -e "${cR}ERROR:${cZ}  ${cW}make install${cZ} failed."; exit 1; }
		popd || { echo -e "${cR}ERROR:${cZ} could not ${cY}popd${cZ}."; exit 1; }
		let TIME_INSTALL=$(date +%s)
		if ((NOOPTIONAL == 0)); then
			pushd "$BASEDIR/3rdparty/binutils" || { echo -e "${cR}ERROR:${cZ} could not ${cW}pushd${cZ}."; exit 1; }
			( set -x; CC="$INSTALL_TO/bin/clang" ./configure --disable-werror --disable-gold --enable-ld --program-suffix=.clang --prefix=$INSTALL_TO ) || { echo -e "${cR}ERROR:${cZ} ${cY}./configure${cZ} (clang) failed."; exit 1; }
			( set -x; make -j$PM && make install ) || { echo -e "${cR}ERROR:${cZ} ${cW}make${cZ} or ${cW}make install${cZ} (clang) failed."; exit 1; }
			popd || { echo -e "${cR}ERROR:${cZ} could not ${cW}popd${cZ}."; exit 1; }
		fi
		let TIME_BINUTILS=$(date +%s)
	else
		echo -e "${cR}ERROR:${cZ} no directory $BASEDIR/build/llvm."
		exit 1
	fi
fi
if ((ONLYCHECKOUT==1)) || ((NOBUILD==1)); then
	show_time_diff $TIME_START $TIME_GIT      "Git operations took: %s"
fi
if ((PACKAGEGITGZ==1)); then
	TIMESTAMP=$(date +%Y-%m-%dT%H-%M-%S)
	TARNAME="packaged-${TIMESTAMP}-LLVM+binutils.tbz"
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
		echo -e "#!/usr/bin/env bash\nT=\"$TARNAME\"\nD=\"$TIMESTAMP-LLVM\"\nR=\"$REVIVE\"\nU=\"$UNPACKER\"\necho \"Unpacking \$T into ./\$D \$( [[ \"x\$1\" == \"x-c\" ]] && echo \"and removing archive plus unpacker upon success\" )\"\nmkdir \"./\$D\" && tar -C \"./\$D\" -xjf \"./\$T\" && ( cd \"./\$D\" && [[ -x \$R ]] && \$R && rm -f \$R )\n[[ \"x\$1\" == \"x-c\" ]] && { echo \"Also removing \$U and \$T\"; rm -f \"./\$U\" \"./\$T\"; }" \
			| tee "./$UNPACKER" > /dev/null && chmod +x "./$UNPACKER"
	)
	let TIME_TGZ=$(date +%s)
	show_time_diff $TIME_GIT $TIME_TGZ          "Packaging took:      %s"
fi
let TIME_END=$(date +%s)
if ((ONLYCHECKOUT==0)) && ((NOBUILD==0)); then
	if (( CMAKE_BUILD )); then
		show_time_diff $TIME_GIT $TIME_CONFIGURE    "CMake       took:    %s"
	else
		show_time_diff $TIME_GIT $TIME_CONFIGURE    "./configure took:    %s"
	fi
	show_time_diff $TIME_CONFIGURE $TIME_MAKE   "GNU make took:       %s"
	show_time_diff $TIME_MAKE $TIME_INSTALL     "Installation took:   %s"
	show_time_diff $TIME_INSTALL $TIME_BINUTILS "Binutils took:       %s"
fi
show_time_diff $TIME_START $TIME_END      "Overall runtime:     %s (m:ss) with $PM parallel job(s)"
