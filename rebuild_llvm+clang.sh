#!/usr/bin/env bash
# http://llvm.org/docs/GettingStarted.html#compiling-the-llvm-suite-source-code
# possiblke alternative: https://github.com/rsmmr/install-clang
LLVM_RELEASE="release_34"
LIBCXXRT_RELEASE="stable"
INSTALL_TO=$HOME/bin/LLVM
TARGETS="x86,x86_64,powerpc,mips,sparc"
BASEDIR="$HOME/LLVM"

function prepare_src
{
	local PRJNAME=${1%%:*}
	local GITCLONE=${1#*:}
	local GITREF=$2
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

let PM=$(grep -c processor /proc/cpuinfo)
let TIME_START=$(date +%s)
# Preparational steps
for i in "llvm:git clone http://llvm.org/git/llvm.git" "llvm/tools/clang:git clone http://llvm.org/git/clang.git" "llvm/projects/compiler-rt:git clone http://llvm.org/git/compiler-rt.git" "llvm/projects/libcxx:git clone http://llvm.org/git/libcxx.git" "llvm/tools/clang/tools/extra:git clone http://llvm.org/git/clang-tools-extra.git"; do
	prepare_src "$i" "$LLVM_RELEASE"
done
for i in "llvm/projects/libcxxrt:git clone https://github.com/pathscale/libcxxrt"; do
	prepare_src "$i" "$LIBCXXRT_RELEASE"
done
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
let TIME_END=$(date +%s)
show_time_diff $TIME_START $TIME_GIT      "Git operations took: %s"
show_time_diff $TIME_GIT $TIME_CONFIGURE  "./configure took:    %s"
show_time_diff $TIME_CONFIGURE $TIME_MAKE "GNU make took:       %s"
show_time_diff $TIME_MAKE $TIME_INSTALL   "Installation took:   %s"
show_time_diff $TIME_START $TIME_END      "Overall runtime:     %s (m:ss) with $PM parallel job(s)"
