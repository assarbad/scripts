#!/usr/bin/env bash
# vim: set autoindent smartindent tabstop=4 shiftwidth=4 noexpandtab filetype=sh:
[[ -t 1 ]] && { cG="\033[1;32m"; cR="\033[1;31m"; cB="\033[1;34m"; cW="\033[1;37m"; cY="\033[1;33m"; cG_="\033[0;32m"; cR_="\033[0;31m"; cB_="\033[0;34m"; cW_="\033[0;37m"; cY_="\033[0;33m"; cZ="\033[0m"; export cR cG cB cY cW cR_ cG_ cB_ cY_ cW_ cZ; }
for tool in awk faketime gpg; do type $tool > /dev/null 2>&1 || { echo -e "${cR}ERROR:${cZ} couldn't find '$tool' which is required by this script."; exit 1; }; done
[[ -n "$DEBUG" ]] && set -x
declare -r BASEDATE='2024-12-31 23:59:59Z'
declare -r DURATION="3y"
declare -r EXPIREDONLY="&& \$3 ~ /expired/"
#declare -r EXPIREDONLY=''
( set -x; gpg -Kv --with-subkey-fingerprints --batch 2> /dev/null \
	| awk '$1 == "sec" { getline; KID=$1; next; } $1 == "uid" && $3 !~ /revoked/ '"$EXPIREDONLY"' { printf("%s", KID); DELIM=" "; for (f=2; f<=NF; ++f) { printf("%s%s", DELIM, $f); }; printf("\n") }' ) \
	| \
while read -r KEYID REMAINDER; do
	printf "Processing ${cW}%s${cZ} (${cG}%s${cZ})\n" "$KEYID" "$REMAINDER"
	(
		set -x
		faketime "$BASEDATE" gpg --quick-set-expire "$KEYID" "$DURATION"
		faketime "$BASEDATE" gpg --quick-set-expire "$KEYID" "$DURATION" '*'
		echo -e "trust\n5\ny\n" | gpg --command-fd 0 --edit-key "$KEYID"
	)
done
