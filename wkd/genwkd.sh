#!/usr/bin/env bash
[[ -t 1 ]] && { cG="\e[1;32m"; cR="\e[1;31m"; cB="\e[1;34m"; cW="\e[1;37m"; cY="\e[1;33m"; cG_="\e[0;32m"; cR_="\e[0;31m"; cB_="\e[0;34m"; cW_="\e[0;37m"; cY_="\e[0;33m"; cZ="\e[0m"; export cR cG cB cY cW cR_ cG_ cB_ cY_ cW_ cZ; }
((${BASH_VERSION%%.*} >= 4)) || { echo -e "${cR}ERROR:${cZ}: expecting a minimum Bash version of 4. You have ${BASH_VERSION}."; exit 1; }
for tool in awk gpg sort wc; do type $tool > /dev/null 2>&1 || { echo -e "${cR}ERROR:${cZ} couldn't find '$tool' which is required by this script."; exit 1; }; done
pushd $(dirname $0) > /dev/null; CURRABSPATH=$(readlink -nf "$(pwd)"); popd > /dev/null; # Get the directory in which the script resides

for recipient in "$@"; do
	gpg --with-wkd-hash -K $recipient 2> /dev/null|awk '$1 == "uid" { print; getline; print $1 }'
	NUMHASHES=$(gpg --with-wkd-hash -K $recipient 2> /dev/null|awk '$1 == "uid" { getline; print $1 }'|sort -u|wc -l)
	HASHES=$(gpg --with-wkd-hash -K $recipient 2> /dev/null|awk '$1 == "uid" { getline; print $1 }'|sort -u)
	if ((NUMHASHES == 0)) || [[ -z "$HASHES" ]]; then
		echo -e "${cR}ERROR:${cZ} no hash generated (try '${cW}gpg --with-wkd-hash -K $recipient${cZ}' manually)"
		exit 1
	fi
	for hashval in $HASHES; do
		hashval=${hashval%%@*}
		echo -e "Hash is: ${cW}$hashval${cZ}"
		if [[ ! -d "$CURRABSPATH/hu" ]]; then
			mkdir -p "$CURRABSPATH/hu" || { echo -e "${cR}ERROR:${cZ} error while creating 'hu' subdirectory"; exit 1; }
			if [[ ! -f "$CURRABSPATH/hu/$hashval" ]]; then
				( set -x; gpg -o "$CURRABSPATH/hu/$hashval" --export-options export-minimal --export $recipient )
			fi
		fi
	done
done
