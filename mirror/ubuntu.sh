#!/usr/bin/env bash
UBUNTU_VERSION=${1:-22.04.2}
ARCHITECTURES=${ARCHITECTURES:-amd64}
BASEURL=${BASEURL:-https://releases.ubuntu.com/$UBUNTU_VERSION}
[[ -t 1 ]] && { cG="\e[1;32m"; cR="\e[1;31m"; cB="\e[1;34m"; cW="\e[1;37m"; cY="\e[1;33m"; cG_="\e[0;32m"; cR_="\e[0;31m"; cB_="\e[0;34m"; cW_="\e[0;37m"; cY_="\e[0;33m"; cZ="\e[0m"; export cR cG cB cY cW cR_ cG_ cB_ cY_ cW_ cZ; }
for tool in curl dirname find grep mv readlink sha256sum; do type $tool > /dev/null 2>&1 || { echo -e "${cR}ERROR:${cZ} couldn't find '$tool' which is required by this script."; exit 1; }; done
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
		if [[ -f "$DIRNAME/$fname" ]]; then
			echo -e "${cW}INFO:${cZ} file ${cW}${fname}${cZ} already downloaded"
		else
			( cd "$DIRNAME"; echo -e "${cW}INFO:${cZ} downloading ${cY}$DIRNAME/${cZ}${cW}$fname${cZ}"; set -x; curl --fail-early -O "$url" )
		fi
	done
}

# Per architecture downloads
for arch in $ARCHITECTURES; do
	DIRNAME="$UBUNTU_VERSION"
	if ( check_preexisting_hashes "$DIRNAME" --ignore-missing ); then
		echo -e "${cW}INFO:${cZ} skipping downloads into ${cY}$DIRNAME${cZ}"
		continue
	fi
	# Downloads
	download_several "$DIRNAME" $BASEURL/SHA256SUMS{,.gpg} $BASEURL/ubuntu-${UBUNTU_VERSION}-{live-server,desktop}-${arch}.iso
	( cd "$DIRNAME"; set -x; for i in SHA256SUMS{,.gpg}; do mv $i Ubuntu-$i; done )
	KUBUNTU_BASEURL="https://cdimage.ubuntu.com/kubuntu/releases/${UBUNTU_VERSION}/release"
	download_several "$DIRNAME" $KUBUNTU_BASEURL/kubuntu-${UBUNTU_VERSION}-desktop-${arch}.iso $KUBUNTU_BASEURL/SHA256SUMS{,.gpg}
	( cd "$DIRNAME"; set -x; for i in SHA256SUMS{,.gpg}; do mv $i Kubuntu-$i; done )
done
