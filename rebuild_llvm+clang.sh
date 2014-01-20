#!/usr/bin/env bash
# http://llvm.org/docs/GettingStarted.html#compiling-the-llvm-suite-source-code
RELEASE="release_34"
TARGETS="x86,x86_64,powerpc,mips,sparc"
BASEDIR="$HOME/LLVM"
# Preparational steps
for i in "llvm:git clone http://llvm.org/git/llvm.git" "llvm/tools/clang:git clone http://llvm.org/git/clang.git"; do
	PRJNAME=${i%%:*}
	GITCLONE=${i#*:}
	# Clone the repository if we don't have it
	[[ -d "$BASEDIR/$PRJNAME" ]] || $GITCLONE "$BASEDIR/$PRJNAME"
	# Sanity check the clone
	[[ -d "$BASEDIR/$PRJNAME/.git" ]] || { echo "ERROR: apparently we failed to clone $PRJNAME ($GITCLONE)."; exit 1; }
	# Set the Git stuff according to the docs
	( cd "$BASEDIR/$PRJNAME" && git config branch.master.rebase true ) || { echo "ERROR: could not set 'git config branch.master.rebase true' for $PRJNAME."; exit 1; }
	# Scrub the working copy
	( cd "$BASEDIR/$PRJNAME" && git clean -d -f -f ) || { echo "ERROR: failed to 'git clean' $PRJNAME."; exit 1; }
	# Get latest changes to the Git repo
	( cd "$BASEDIR/$PRJNAME" && git fetch ) || { echo "WARNING: failed to 'git fetch' $PRJNAME."; }
	# Check out the release
	( cd "$BASEDIR/$PRJNAME" && echo -n "$(echo $PRJNAME|tr 'a-z' 'A-Z'): " && git checkout $RELEASE ) || { echo "ERROR: failed to check out $RELEASE for $PRJNAME."; exit 1; }
	[[ -d "$BASEDIR/build-$PRJNAME" ]] && rm -rf "$BASEDIR/build-$PRJNAME"
	mkdir -p "$BASEDIR/build-$PRJNAME" || { echo "ERROR: could not create build-$PRJNAME directory."; exit 1; }
done
if [[ -d "$BASEDIR/build-llvm" ]]; then
	(
		cd "$BASEDIR/build-llvm" &&\
			"$BASEDIR/llvm/configure" --enable-optimized --enable-targets=$TARGETS && \
			make -j8 ENABLE_OPTIMIZED=1 DISABLE_ASSERTIONS=1
	)
fi
