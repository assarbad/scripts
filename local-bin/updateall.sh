#!/usr/bin/env bash
[[ -t 1 ]] && { cG="\e[1;32m"; cR="\e[1;31m"; cB="\e[1;34m"; cW="\e[1;37m"; cY="\e[1;33m"; cG_="\e[0;32m"; cR_="\e[0;31m"; cB_="\e[0;34m"; cW_="\e[0;37m"; cY_="\e[0;33m"; cZ="\e[0m"; export cR cG cB cY cW cR_ cG_ cB_ cY_ cW_ cZ; }
for tool in git rm hg find readlink sort pwd; do type $tool > /dev/null 2>&1 || { echo -e "${cR}ERROR:${cZ} couldn't find '$tool' which is required by this script."; exit 1; }; done
pushd $(dirname $0) > /dev/null; CURRABSPATH=$(readlink -nf "$(pwd)"); popd > /dev/null; # Get the directory in which the script resides
( [[ -n "$DEBUG" ]] || [[ -n "$DBG" ]] ) && { DBG=1; DEBUG=1; set -x; }
LOCKFILE="${TMPDIR=/tmp}/${CURRABSPATH//\//_}${0##*/}.lock"
if ! (set -o noclobber; echo "$$" > "$LOCKFILE") 2> /dev/null; then
	echo -e "${cR}ERROR:${cZ} Lock failed, PID $(cat "$LOCKFILE") [$LOCKFILE]" >&2
	exit 1
fi
trap 'rm -f "$LOCKFILE"; trap - INT TERM EXIT; exit $?' INT TERM EXIT
(
cd "$CURRABSPATH"
echo -e "Working directory: $(pwd)"
for repotype in Git Hg SVN; do
        find $repotype -maxdepth 1 -type d|sort -fu|while read dname; do
                case $repotype in
                Git)    if [[ -d "$dname/.git" ]]; then
                                echo -e "Updating for ${cW}$dname${cZ}"
                                if [[ "$(git --git-dir="$dname/.git" config --bool core.bare)" != "true" ]]; then
                                        echo "Removing work tree $dname"
                                        (cd "$dname" && find -maxdepth 1 ! -name .git -a ! -name . -exec rm -rf {} \;)
                                        echo "Making repository bare"
                                        git --git-dir="$dname/.git" config --bool core.bare true
                                fi
                                git --git-dir="$dname/.git" fetch --all
                                #git --git-dir="$dname/.git" remote prune origin
                                # TODO: Garbage collection for Git based on environment variable (so we can do it once every few hours instead of every sync)
                                #git --git-dir="$dname/.git" gc --auto --prune=all
                                #git --git-dir="$dname/.git" fsck
                        fi
                        ;;
                Hg)     if [[ -d "$dname/.hg" ]]; then
                                echo -e "Updating for ${cW}$dname${cZ}"
                                (cd "$dname" && find -maxdepth 1 ! -name .hg -a ! -name . -exec rm -rf {} \;)
                                hg --cwd "$dname" pull
                        fi
                        ;;
                SVN)    if [[ -x "$dname/sync" ]]; then
                                echo -e "Updating for ${cW}$dname${cZ}"
                                (cd "$dname" && ./sync)
                        fi
                        ;;
                esac
        done
done
)
