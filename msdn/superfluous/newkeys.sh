#!/usr/bin/env bash
[[ -t 1 ]] && { cG="\e[1;32m"; cR="\e[1;31m"; cB="\e[1;34m"; cW="\e[1;37m"; cY="\e[1;33m"; cG_="\e[0;32m"; cR_="\e[0;31m"; cB_="\e[0;34m"; cW_="\e[0;37m"; cY_="\e[0;33m"; cZ="\e[0m"; export cR cG cB cY cW cR_ cG_ cB_ cY_ cW_ cZ; }
for tool in find rm touch git pushd popd sort awk grep tee cat mv; do type $tool > /dev/null 2>&1 || { echo -e "${cR}ERROR:${cZ} couldn't find '$tool' which is required by this script."; exit 1; }; done
pushd $(dirname $0) > /dev/null; CURRABSPATH=$(readlink -nf "$(pwd)"); popd > /dev/null; # Get the directory in which the script resides
rm -rf "$CURRABSPATH/.git"
git -C "$CURRABSPATH" init
rm "$CURRABSPATH"/*.txt{,_}
touch "$CURRABSPATH/allkeys.txt"
git -C "$CURRABSPATH" add .gitignore allkeys.txt newkeys.sh
git -C "$CURRABSPATH" config commit.gpgsign false
git -C "$CURRABSPATH" config diff.tool bcompare
git -C "$CURRABSPATH" config difftool.bcompare.path $(which bcompare)
git -C "$CURRABSPATH" commit -m "Empty"
find "$CURRABSPATH/../keys" -type f -iname '*_keys*.xml'|sort -r|while read fname; do
	DIRNAME="$(dirname $fname)"
	( \
		set -x; \
		cd "$CURRABSPATH"; \
		mv allkeys.txt allkeys.txt_; \
		( \
			cat allkeys.txt_; \
			"$CURRABSPATH/../combine-msdn-keys.py" "$fname" 2> /dev/null|grep -P '^\t'|awk '{print $1}' )|sort -u|tee allkeys.txt && \
			command git add -u && \
			if command git diff-index --quiet HEAD; then echo "$fname"|tee -a nonews.txt; else command git commit -m "$DIRNAME"; fi \
	)
done
( set -x; rm -f "$CURRABSPATH"/allkeys.txt{,_} )
( set -x; rm -rf "$CURRABSPATH/.git" )
if [[ -f "$CURRABSPATH/nonews.txt" ]]; then
	( set -x; rm -f "$(cat "$CURRABSPATH/nonews.txt")" )
	( set -x; rm -f "$CURRABSPATH/nonews.txt" )
fi
