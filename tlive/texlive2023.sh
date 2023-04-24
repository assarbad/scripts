#!/usr/bin/env bash
[[ -t 1 ]] && { cG="\e[1;32m"; cR="\e[1;31m"; cB="\e[1;34m"; cW="\e[1;37m"; cY="\e[1;33m"; cG_="\e[0;32m"; cR_="\e[0;31m"; cB_="\e[0;34m"; cW_="\e[0;37m"; cY_="\e[0;33m"; cZ="\e[0m"; export cR cG cB cY cW cR_ cG_ cB_ cY_ cW_ cZ; }
((${BASH_VERSION%%.*} >= 4)) || { echo -e "${cR}ERROR:${cZ}: expecting a minimum Bash version of 4. You have ${BASH_VERSION}."; exit 1; }
for tool in rsync sha256sum tar tee; do type $tool > /dev/null 2>&1 || { echo -e "${cR}ERROR:${cZ} couldn't find '$tool' which is required by this script."; exit 1; }; done
pushd $(dirname $0) > /dev/null; CURRABSPATH=$(readlink -nf "$(pwd)"); popd > /dev/null; # Get the directory in which the script resides
TGTDIR="$CURRABSPATH/texlive2023"
if [[ -d "$TGTDIR" ]]; then
	(set -x; rsync -avP --delete-after rsync://rsync.dante.ctan.org/CTAN/systems/texlive/tlnet/ "$TGTDIR/") || { echo -e "${cR}ERROR:${cZ} ${cW}rsync${cZ} failed!"; exit 1; }
	(set -x; cd "$CURRABSPATH"; tar -cf "${TGTDIR##*/}.tar" "${0##*/}" "${TGTDIR##*/}" && sha256sum "${TGTDIR##*/}.tar"|tee "$TGTDIR.tar.SHA256SUM") || { echo -e "${cR}ERROR:${cZ} ${cW}tar${cZ} failed!"; exit 1; }
else
	echo -e "${cG}INFO:${cZ} target directory ${cW}$TGTDIR${cZ} doesn't exist. Quitting."
fi
