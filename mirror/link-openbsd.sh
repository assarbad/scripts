#!/usr/bin/env bash
OPENBSD_VERSION=${1:-7.2}
ARCHITECTURES="amd64 i386"
[[ -t 1 ]] && { cG="\e[1;32m"; cR="\e[1;31m"; cB="\e[1;34m"; cW="\e[1;37m"; cY="\e[1;33m"; cG_="\e[0;32m"; cR_="\e[0;31m"; cB_="\e[0;34m"; cW_="\e[0;37m"; cY_="\e[0;33m"; cZ="\e[0m"; export cR cG cB cY cW cR_ cG_ cB_ cY_ cW_ cZ; }
for tool in cp dirname readlink; do type $tool > /dev/null 2>&1 || { echo -e "${cR}ERROR:${cZ} couldn't find '$tool' which is required by this script."; exit 1; }; done
pushd $(dirname $0) > /dev/null; CURRABSPATH=$(readlink -nf "$(pwd)"); popd > /dev/null; # Get the directory in which the script resides
for arch in $ARCHITECTURES; do
	DIRNAME="$OPENBSD_VERSION/$arch"
	( set -x; cp -alf $DIRNAME/install${OPENBSD_VERSION//./}.iso OpenBSD-${OPENBSD_VERSION}-${arch}.iso )
done
