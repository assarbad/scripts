#!/usr/bin/env bash
FREEBSD_VERSION=${1:-13.1}
ARCHITECTURES="amd64 i386"
[[ -t 1 ]] && { cG="\e[1;32m"; cR="\e[1;31m"; cB="\e[1;34m"; cW="\e[1;37m"; cY="\e[1;33m"; cG_="\e[0;32m"; cR_="\e[0;31m"; cB_="\e[0;34m"; cW_="\e[0;37m"; cY_="\e[0;33m"; cZ="\e[0m"; export cR cG cB cY cW cR_ cG_ cB_ cY_ cW_ cZ; }
for tool in curl dirname find grep readlink sha256sum xz; do type $tool > /dev/null 2>&1 || { echo -e "${cR}ERROR:${cZ} couldn't find '$tool' which is required by this script."; exit 1; }; done
pushd $(dirname $0) > /dev/null; CURRABSPATH=$(readlink -nf "$(pwd)"); popd > /dev/null; # Get the directory in which the script resides
BASEURL="https://download.freebsd.org/ftp/releases"
for arch in $ARCHITECTURES; do
	DIRNAME="$FREEBSD_VERSION/$arch"
	# Skip if downloaded and unpacked
	if [[ -f "$DIRNAME/SHA256SUMS" ]] && [[ -f "$DIRNAME/SHA256SUMS.asc" ]] && [[ -z "$OLDHASHES" ]]; then
		echo -e "${cW}INFO:${cZ} checking hashes in ${cW}$DIRNAME${cZ}"
		if ( cd "$DIRNAME"; set -x; sha256sum --check SHA256SUMS ); then
			echo -e "${cG}SUCCESS:${cZ} validated files"
		fi
	fi
	[[ -d "$DIRNAME" ]] || mkdir -p "$DIRNAME"
	# Downloads
	for url in $BASEURL/$arch/$arch/ISO-IMAGES/$FREEBSD_VERSION/FreeBSD-${FREEBSD_VERSION}-RELEASE-${arch}-{bootonly,disc1,dvd1}.iso.xz $BASEURL/$arch/$arch/ISO-IMAGES/$FREEBSD_VERSION/CHECKSUM.SHA{256,512}-FreeBSD-${FREEBSD_VERSION}-RELEASE-${arch}; do
		fname="${url##*/}"
		if [[ "${fname}" != "${fname%.xz}" ]] && [[ -f "$DIRNAME/${fname%.xz}" ]]; then
			echo -e "${cW}INFO:${cZ} file ${cW}${fname}${cZ} already unpacked, skipping download."
			continue
		fi
		if [[ -f "$DIRNAME/$fname" ]]; then
			echo -e "${cW}INFO:${cZ} file ${cW}${fname}${cZ} already downloaded"
		else
			( cd "$DIRNAME"; echo -e "${cW}INFO:${cZ} downloading ${cY}$DIRNAME/${cZ}${cW}$fname${cZ}"; set -x; curl -O "$url" )
		fi
	done
done
for arch in $ARCHITECTURES; do
	# Validate, unpack, extract relevant hashes, sign hash file
	if ( cd "$DIRNAME"; set -x; grep '.*\.iso\.xz' CHECKSUM.SHA256*| sha256sum --check ); then
		( cd "$DIRNAME"; set -x; for i in *.iso.xz; do xz -kd $i; done )
		if ( cd "$DIRNAME"; set -x; grep '.*\.iso' CHECKSUM.SHA256*|grep -v '.*\.iso\.xz'|tee "SHA256SUMS"|sha256sum --check ); then
			echo -e "${cG}SUCCESS:${cZ} ISO files successfully validated, removing .iso.xz files"
			( cd "$DIRNAME"; set -x; gpg -bao SHA256SUMS{.asc,} )
			( cd "$DIRNAME"; set -x; rm -f *.iso.xz )
		else
			echo -e "${cR}ERROR:${cZ} Some files did not match the expected hashes!"
		fi
	fi
done
