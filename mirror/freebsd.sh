#!/usr/bin/env bash
FREEBSD_VERSION=${1:-13.1}
ARCHITECTURES="amd64 i386"
BASEURL="https://download.freebsd.org/ftp/releases"
[[ -t 1 ]] && { cG="\e[1;32m"; cR="\e[1;31m"; cB="\e[1;34m"; cW="\e[1;37m"; cY="\e[1;33m"; cG_="\e[0;32m"; cR_="\e[0;31m"; cB_="\e[0;34m"; cW_="\e[0;37m"; cY_="\e[0;33m"; cZ="\e[0m"; export cR cG cB cY cW cR_ cG_ cB_ cY_ cW_ cZ; }
for tool in curl dirname find grep readlink sha256sum xz; do type $tool > /dev/null 2>&1 || { echo -e "${cR}ERROR:${cZ} couldn't find '$tool' which is required by this script."; exit 1; }; done
pushd $(dirname $0) > /dev/null; CURRABSPATH=$(readlink -nf "$(pwd)"); popd > /dev/null; # Get the directory in which the script resides

function check_preexisting_hashes
{
	local DIRNAME="$1"
	shift
	# Skip if downloaded and unpacked
	if [[ -f "$DIRNAME/SHA256SUMS" ]] && [[ -f "$DIRNAME/SHA256SUMS.asc" ]] && [[ -z "$OLDHASHES" ]]; then
		echo -e "${cW}INFO:${cZ} checking hashes in ${cW}$DIRNAME${cZ}"
		if ( cd "$DIRNAME"; set -x; sha256sum "$@" --check SHA256SUMS ); then
			echo -e "${cG}SUCCESS:${cZ} validated files"
			exit 0
		fi
	fi
	exit 1
}

function validate_using_hashfile_and_sign
{
	local DIRNAME="$1"
	shift
	local HASHFILESRC="${1:-SHA256}"
	shift
	local HASHFILE="${1:-SHA256SUMS}"
	shift
	if ( cd "$DIRNAME"; set -x; cat "$HASHFILESRC"|tee "${HASHFILE}"|sha256sum "$@" --check ); then
		echo -e "${cG}SUCCESS:${cZ} files successfully validated"
		if [[ -f "$DIRNAME/${HASHFILE}.asc" ]]; then
			( cd "$DIRNAME"; set -x; gpg --verify ${HASHFILE}.asc ) || exit $?
		else
			( cd "$DIRNAME"; set -x; gpg -bao ${HASHFILE}{.asc,} ) || exit $?
		fi
	else
		echo -e "${cR}ERROR:${cZ} Some files did not match the expected hashes!"
		exit 1
	fi
	exit 0
}

function download_several
{
	local DIRNAME="$1"
	shift
	[[ -d "$DIRNAME" ]] || mkdir -p "$DIRNAME"
	for url in "$@"; do
		local fname="${url##*/}"
		if [[ "${fname}" != "${fname%.xz}" ]] && [[ -f "$DIRNAME/${fname%.xz}" ]]; then
			echo -e "${cW}INFO:${cZ} file ${cW}${fname}${cZ} already unpacked, skipping download."
			continue
		fi
		if [[ -f "$DIRNAME/$fname" ]]; then
			echo -e "${cW}INFO:${cZ} file ${cW}${fname}${cZ} already downloaded"
		else
			( cd "$DIRNAME"; echo -e "${cW}INFO:${cZ} downloading ${cY}$DIRNAME/${cZ}${cW}$fname${cZ}"; set -x; curl --fail-early -O "$url" )
		fi
	done
}

for arch in $ARCHITECTURES; do
	DIRNAME="$FREEBSD_VERSION/$arch"
	# Skip if downloaded and unpacked
	if ( check_preexisting_hashes "$DIRNAME" --ignore-missing ); then
		echo -e "${cW}INFO:${cZ} skipping downloads into ${cY}$DIRNAME${cZ}"
		continue
	fi
	# Downloads
	download_several "$DIRNAME" $BASEURL/$arch/$arch/ISO-IMAGES/$FREEBSD_VERSION/FreeBSD-${FREEBSD_VERSION}-RELEASE-${arch}-{bootonly,disc1,dvd1}.iso.xz $BASEURL/$arch/$arch/ISO-IMAGES/$FREEBSD_VERSION/CHECKSUM.SHA{256,512}-FreeBSD-${FREEBSD_VERSION}-RELEASE-${arch}
done
for arch in $ARCHITECTURES; do
	DIRNAME="$FREEBSD_VERSION/$arch"
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
