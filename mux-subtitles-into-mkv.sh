#!/usr/bin/env bash
[[ -t 1 ]] && { cG="\e[1;32m"; cR="\e[1;31m"; cB="\e[1;34m"; cW="\e[1;37m"; cY="\e[1;33m"; cG_="\e[0;32m"; cR_="\e[0;31m"; cB_="\e[0;34m"; cW_="\e[0;37m"; cY_="\e[0;33m"; cZ="\e[0m"; export cR cG cB cY cW cR_ cG_ cB_ cY_ cW_ cZ; }
for tool in dirname find mkdir mkvmerge readlink; do type $tool > /dev/null 2>&1 || { echo -e "${cR}ERROR:${cZ} couldn't find '$tool' which is required by this script."; exit 1; }; done
pushd $(dirname $0) > /dev/null; CURRABSPATH=$(readlink -nf "$(pwd)"); popd > /dev/null; # Get the directory in which the script resides

function mux
{
	local VIDNAME="$1"
	local SUBNAME="${VIDNAME%.mkv}.srt"
	local muxed="muxed"
	local OUTNAME="${SUBNAME%/*}/$muxed/${VIDNAME##*/}"
	if [[ -f "$VIDNAME" ]] && [[ -f "$SUBNAME" ]]; then
		[[ -d "${OUTNAME%/*}" ]] || mkdir "${OUTNAME%/*}"
		if [[ -f "$OUTNAME" ]]; then
			echo "ALREADY MUXED: $OUTNAME"
		else
			mkvmerge \
				--output "${OUTNAME}" \
				--language 0:und \
				--default-track 0:yes \
				--display-dimensions 0:479x270 \
				--language 1:eng \
				--track-name 1:Stereo \
				--default-track 1:yes '(' "$VIDNAME" ')' \
				--language 0:eng '(' "$SUBNAME" ')' \
				--track-order 0:0,0:1,1:0
		fi
	fi
}

find -name '*.mkv'|while read fname; do
	mux "$fname"
done
