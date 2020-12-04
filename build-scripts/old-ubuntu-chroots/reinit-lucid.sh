#!/usr/bin/env bash
# vim: set autoindent smartindent ts=4 sw=4 sts=4 noet filetype=sh:
[[ -t 1 ]] && { cG="\e[1;32m"; cR="\e[1;31m"; cB="\e[1;34m"; cW="\e[1;37m"; cY="\e[1;33m"; cG_="\e[0;32m"; cR_="\e[0;31m"; cB_="\e[0;34m"; cW_="\e[0;37m"; cY_="\e[0;33m"; cZ="\e[0m"; export cR cG cB cY cW cR_ cG_ cB_ cY_ cW_ cZ; }
for tool in proot readlink sha256sum tar tee xz; do type $tool > /dev/null 2>&1 || { echo -e "${cR}ERROR:${cZ} couldn't find '$tool' which is required by this script."; exit 1; }; done
pushd $(dirname $0) > /dev/null; CURRABSPATH=$(readlink -nf "$(pwd)"); popd > /dev/null; # Get the directory in which the script resides
source "$CURRABSPATH/.reinitrc-lucid"

let PREPS=${PREPS:-3}
if ((CONTINUE)); then
	echo -e "${cW}INFO:${cZ} Skipping cleanup of old rootfs and reinitialization (CONTINUE=$CONTINUE)"
else
	echo -e "${cW}INFO:${cZ} Cleaning up old rootfs"
	if [[ -d "$CURRABSPATH/rootfs" ]]; then
		(cd "$CURRABSPATH"; set -x; rm -rf "rootfs")
	fi
	mkdir -p "$CURRABSPATH/rootfs" || { echo -e "${cR}ERROR:${cZ} failed to create subdirectory rootfs."; exit 1; }
	if [[ ! -e "$PREPARED_ROOTFS" ]] || [[ ! -e "$PREPARED_ROOTFS.xz" ]]; then
		if [[ -e "$PREPARED_ROOTFS" ]]; then
			if ( cd "$CURRABSPATH"; sha256sum -c "$PREPARED_ROOTFS.SHA256SUM" ); then
				(cd "$CURRABSPATH"; set -x; tar -xf "$PREPARED_ROOTFS") || { echo -e "${cR}ERROR:${cZ} failed to unpack existing tarball of rootfs."; exit 1; }
			else
				echo -e "${cR}ERROR:${cZ} failed to verify hash for existing tarball of rootfs."
				exit 1
			fi
		elif [[ -e "$PREPARED_ROOTFS.xz" ]]; then
			if ( cd "$CURRABSPATH"; sha256sum -c "$PREPARED_ROOTFS.xz.SHA256SUM" ); then
				(cd "$CURRABSPATH"; set -x; tar -xf "$PREPARED_ROOTFS.xz") || { echo -e "${cR}ERROR:${cZ} failed to unpack existing tarball of rootfs."; exit 1; }
			else
				echo -e "${cR}ERROR:${cZ} failed to verify hash for existing tarball of rootfs."
				exit 1
			fi
		else
			if ( cd "$CURRABSPATH"; sha256sum -c "$PRISTINE_ROOTFS.SHA256SUM" ); then
				(cd "$CURRABSPATH"; set -x; tar -C rootfs -xf "$PRISTINE_ROOTFS" || true) # we expect errors when running unprivileged
			else
				echo -e "${cR}ERROR:${cZ} failed to verify hash for pristine tarball of rootfs."
				exit 1
			fi
		fi
	fi
fi

if ((PREPS>0)); then
	echo -e "${cW}INFO(PREPS #1):${cZ} Preparing rootfs for APT cache (PREPS=$PREPS)"
	tee "$CURRABSPATH/rootfs/etc/apt/apt.conf.d/01apt-cacher-ng" <<-EOF
		Acquire::http { Proxy "http://127.0.0.1:3142"; };
		Acquire::https { Proxy "https://"; };
	EOF
	tee "$CURRABSPATH/rootfs/etc/mtab" <<-EOF
		/dev/nosuch / ext4 relatime 0 0
	EOF
else
	echo -e "${cY}INFO:${cZ} Skipping PREPS #1"
fi

if ((PREPS>1)); then
	echo -e "${cW}INFO(PREPS #2):${cZ} Preparing rootfs (PREPS=$PREPS)"
	(cd "$CURRABSPATH"; set -x; bin/enter-proot -- /usr/bin/env NOINSTALL=1 /root/bin/prepare-clang-build.sh)
	(cd "$CURRABSPATH"; set -x; bin/enter-proot -- /root/bin/clean-lucid-10.04.sh)
	(cd "$CURRABSPATH"; set -x; bin/enter-proot -- /root/bin/prepare-clang-build.sh)
	(cd "$CURRABSPATH"; set -x; bin/enter-proot -- /root/bin/clean-lucid-10.04.sh)
else
	echo -e "${cY}INFO:${cZ} Skipping PREPS #2"
fi

if ((CONTINUE)) || ((PREPS>2)); then
	# Overwrite the tarball no matter what
	echo -e "${cW}INFO (PREPS #3):${cZ} Creating tarball of rootfs (PREPS=$PREPS)"
	(cd "$CURRABSPATH"; set -x; tar --exclude-vcs -cf "$PREPARED_ROOTFS" rootfs) || { echo -e "${cR}ERROR:${cZ} failed to create tarball of rootfs."; exit 1; }
	(cd "$CURRABSPATH"; set -x; sha256sum "$PREPARED_ROOTFS"|tee "$PREPARED_ROOTFS.SHA256SUM") || { echo -e "${cR}ERROR:${cZ} failed to compute hash of tarball for the rootfs."; exit 1; }
	# Remove the compressed tarball, if any
	rm -f "$PREPARED_ROOTFS.xz" "$PREPARED_ROOTFS.xz.SHA256SUM"
else
	echo -e "${cY}INFO:${cZ} Skipping PREPS #3"
fi

if [[ -e "$PREPARED_ROOTFS" ]] && [[ ! -e "$PREPARED_ROOTFS.xz" ]]; then
	echo -e "${cW}INFO:${cZ} Compressing tarball of rootfs"
	let NUMCPUS=$(grep -c processor /proc/cpuinfo || echo 1)
	(cd "$CURRABSPATH"; set -x; xz -f9eT $NUMCPUS "$PREPARED_ROOTFS") || { echo -e "${cR}ERROR:${cZ} failed to compress tarball of rootfs."; exit 1; }
	(cd "$CURRABSPATH"; set -x; sha256sum "$PREPARED_ROOTFS.xz"|tee "$PREPARED_ROOTFS.xz.SHA256SUM") || { echo -e "${cR}ERROR:${cZ} failed to compute hash of compressed tarball for the rootfs."; exit 1; }
	(cd "$CURRABSPATH"; set -x; rm -f "$PREPARED_ROOTFS.SHA256SUM")
fi

exit 0
