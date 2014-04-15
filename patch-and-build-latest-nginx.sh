#!/usr/bin/env bash
[[ -e "/etc/debian_version" ]] || { echo "ERROR: this script requires Debian/Ubuntu to run."; exit 1; }
CURRDATE=$(date +"%Y-%m-%dT%H-%M-%S")
BASENAME=nginx
# Adjust this to be full, extras or another flavor
FLAVOUR=light
PACKAGE=nginx-$FLAVOUR
WORKDIR="$HOME/${BASENAME}_${CURRDATE}"
GITHUBBASE="https://github.com/"
GITHUBREPOS="tszming/nginx-rewrite-request-body-module.git:ngx-rewrite-request-body-module agentzh/replace-filter-nginx-module.git:ngx-replace-filter-module agentzh/sregex.git:sregex"
# Check for Git being installed and initiate installation if it's not installed, yet
if [[ -z "$(type git 2> /dev/null)" ]]; then
	if [[ $UID -eq 0 ]]; then
		apt-get install git || { echo "ERROR: Need Git to proceed. But something failed when attempting to install it with apt-get. Consult the output above."; exit 1; }
	else
		echo "ERROR: Git is not installed. Since you aren't the superuser I am not going to attempt to install it either. Quitting."
		exit 1
	fi
fi
# Same for build-essential
if ! dpkg -l|grep ^ii|grep -q build-essential; then
	if [[ $UID -eq 0 ]]; then
		apt-get install build-essential || { echo "ERROR: Need 'build-essential' package to proceed. But something failed when attempting to install it with apt-get. Consult the output above."; exit 1; }
	else
		echo "ERROR: 'build-essential' package is not installed. Since you aren't the superuser I am not going to attempt to install it either. Quitting."
		exit 1
	fi
fi
# Create work folder and change into it
mkdir -p "$WORKDIR" || { echo "ERROR: Could not create $WORKDIR."; exit 1; }
if [[ -d "$WORKDIR" ]]; then
	(
		cd "$WORKDIR" && \
			apt-get source $PACKAGE || { echo "ERROR: Couldn't get the source for $PACKAGE package (via: apt-get source $PACKAGE)."; exit 1; }
		# Find the bloody folder into which it gets unpacked
		SRCDIR=$(for i in *.orig.tar.gz; do SRC=${i%%.orig.tar.gz}; SRC=${SRC//_/-}; [[ -d "$SRC" ]] && echo "$SRC"; done)
		[[ -d "$SRCDIR" ]] || { echo "ERROR: Couldn't determine the directory into which the source for $PACKAGE got unpacked by 'apt-get source'."; exit 1; }
		echo "FOUND: $SRCDIR"
		MISSING_BUILD_DEPS=$(apt-get -s build-dep $PACKAGE|grep ^Inst|cut -f 2 -d ' ')
		if [[ -n "$MISSING_BUILD_DEPS" ]]; then
			if [[ $UID -eq 0 ]]; then
				echo "Installing build dependencies"i
				apt-get build-dep $PACKAGE || { echo "ERROR: Failed to install build dependencies for $PACKAGE package (via: apt-get build-dep $PACKAGE)."; exit 1; }
			else
				echo "ERROR: build dependencies for $PACKAGE are not installed. Since you aren't the superuser I am not going to attempt to install it either. Quitting."
				echo -e "\tThe dependencies are (apt-get -s build-dep $PACKAGE|grep ^Inst|cut -f 2 -d ' '):"
				apt-get -s build-dep $PACKAGE|grep ^Inst|cut -f 2 -d ' '|sed 's/^/\t /'
				echo "ERROR (recap): the above is a list of missing build dependencies. Have your admin install them (with: apt-get build-dep $PACKAGE), then come back."
				exit 1
			fi
		else
			echo "INFO: all build dependencies satisfied. Good."
		fi
		# This happens on some systems, but not on all. But since this folder would be created anyway, we may just as well preempt it.
		[[ -d "$WORKDIR/$SRCDIR/debian/modules" ]] || mkdir -p "$WORKDIR/$SRCDIR/debian/modules"
		if [[ -d "$WORKDIR/$SRCDIR/debian/modules" ]]; then
			(
				if cd "$WORKDIR/$SRCDIR/debian/modules"; then
					for i in $GITHUBREPOS; do
						REPOURI=${i%%:*}
						REPODIR=${i##*:}
						git clone "$GITHUBBASE$REPOURI" "$REPODIR"
					done && \
						echo "Building and installing sregex library" && cd sregex && make
				fi
			) || { echo "ERROR: something went wrong, consult the output above."; exit 1; }
			echo "Changing into $WORKDIR/$SRCDIR"
			# Back to the base folder
			if cd "$WORKDIR/$SRCDIR"; then
				CUSTOMRULES=debian/rules.CUSTOM
				echo "Time to modify them rules, innit?"
				cat debian/rules | \
					sed "/^FLAVOURS/cFLAVOURS:=$FLAVOUR" > "$CUSTOMRULES" && chmod a+x "$CUSTOMRULES"
				# Need to include those nginx modules
				for i in $GITHUBREPOS; do
					REPODIR=${i##*:}
					# Filter out those that don't start with "ngx-"
					[[ "${REPODIR##ngx-}" == "$REPODIR" ]] && continue
					perl -i -pe "s/^(\t+)(cd \\$\(BUILDDIR_$FLAVOUR\)[^\n]+)/\1\2\n\1    --add-module=\\$\(MODULESDIR\)\/$REPODIR \\\/sm" "$CUSTOMRULES"
				done
				# Make sure dh_make doesn't attempt to build/check/install the other flavors
				(
					cd debian && for i in nginx-*.{dirs,install,manpages,init,postinst,preinst,prerm,lintian-overrides,debhelper.log,substvars}; do
						[[ "${i//nginx-common/}" == "$i" ]] || continue
						[[ "${i//nginx-doc/}" == "$i" ]] || continue
						[[ "${i//nginx-$FLAVOUR/}" == "$i" ]] || continue
						rm -f "$i"
					done
				) || { echo "ERROR: something went wrong, consult the output above."; exit 1; }
				grep ^FLAVOURS "$CUSTOMRULES"
				# Patch up the config to favor the static lib
				debian/modules/ngx-replace-filter-module/config
				export SREGEX_INC="$WORKDIR/$SRCDIR/debian/modules/sregex/src"
				export SREGEX_LIB="$WORKDIR/$SRCDIR/debian/modules/sregex"
				NGXREGEX="$WORKDIR/$SRCDIR/debian/modules/ngx-replace-filter-module/config"
				mv "$NGXREGEX" "$NGXREGEX.bak"
				cat "$NGXREGEX.bak" | \
					perl -pe 's/^(ngx_feature_libs=")(-lsregex)(")/\1-Wl,-Bstatic \2 -Wl,-Bdynamic\3/' | \
					perl -pe 's/(SREGEX_LIB )(-lsregex)(")/\1-Wl,-Bstatic \2 -Wl,-Bdynamic\3/' > "$NGXREGEX"
				# Now build the package(s)
				dpkg-buildpackage -rfakeroot -uc -b -R$CUSTOMRULES
			else
				echo "ERROR: failed to change into $WORKDIR/$SRCDIR/debian/modules"
				exit 1
			fi
		else
			echo "ERROR: failed to change into $WORKDIR/$SRCDIR"
			exit 1
		fi
	) || { echo "ERROR: something went wrong, consult the output above."; exit 1; }
fi
# Removing the obsolete packages (basically empty because of the magic we worked above!)
(
	cd "$WORKDIR" && for i in *.deb; do
		[[ "${i//nginx-common/}" == "$i" ]] || continue
		[[ "${i//nginx-doc/}" == "$i" ]] || continue
		[[ "${i//nginx-$FLAVOUR/}" == "$i" ]] || continue
		rm -f "$i"
	done
)
echo -e "\n\nFind your packages under $WORKDIR now. The files are:\n\t $(cd "$WORKDIR" && echo ${PACKAGE}*.deb)"
echo -e "\nHere the commands to copy to the directory you're in:\n"
find "$WORKDIR" -name "${PACKAGE}*.deb"|while read debname; do
	echo "cp \"$debname\" ."
done
