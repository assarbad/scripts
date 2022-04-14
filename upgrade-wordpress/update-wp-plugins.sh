#!/usr/bin/env bash
# vim: set autoindent smartindent tabstop=4 shiftwidth=4 noexpandtab filetype=sh:
[[ -t 1 ]] && { cG="\033[1;32m"; cR="\033[1;31m"; cB="\033[1;34m"; cW="\033[1;37m"; cY="\033[1;33m"; cG_="\033[0;32m"; cR_="\033[0;31m"; cB_="\033[0;34m"; cW_="\033[0;37m"; cY_="\033[0;33m"; cZ="\033[0m"; export cR cG cB cY cW cR_ cG_ cB_ cY_ cW_ cZ; }
for tool in find grep perl sed sudo tar wc; do type $tool > /dev/null 2>&1 || { echo -e "${cR}ERROR:${cZ} couldn't find '$tool' which is required by this script."; exit 1; }; done
[[ -n "$DEBUG" ]] && set -x
pushd $(dirname $0) > /dev/null; CURRABSPATH=$(readlink -nf "$(pwd)"); popd > /dev/null; # Get the directory in which the script resides

function update_content
{
	local UPDFILE="$1"
	local BLOGDIR="$2"
	local BASEDIR="$3"
	local CONTENTTYPE="$4"
	local BLOGBASE="$BASEDIR/$BLOGDIR"
	local WPCONFIG="$BLOGBASE/wp-config.php"
	[[ -f "$WPCONFIG" ]] || WPCONFIG="$BASEDIR/wp-config.php"
	# Import the DB credentials as variables by the same name as the defines in PHP
	eval $(perl -pe "s/define\('(DB_(?:NAME|USER|PASSWORD|HOST))', '([^']+)'\);.+/\$1='\$2';/img;" "$WPCONFIG" 2>/dev/null|grep -E '^DB_(NAME|USER|PASSWORD|HOST)')
	source <(grep -oP '^\$wp_version\s+=\s+[^;]+' "$BLOGBASE/wp-includes/version.php"|sed -e 's|\$||g;s| ||g')
	[[ -n "$wp_version" ]] || { echo -e "${cR}ERROR${cZ}: could not determine WordPress version."; exit 1; }
	if ( set -x; unzip -d "$WPTEMPDIR" "$UPDFILE" ); then
		let COUNT=$(find "$WPTEMPDIR" -maxdepth 1 -mindepth 1 -type d -printf '%f\n'|wc -l)
		if ((COUNT == 1)); then
			PLDIRNAME=$(find "$WPTEMPDIR" -maxdepth 1 -mindepth 1 -type d -printf '%f')
			if [[ -d "$BLOGBASE/wp-content/$CONTENTTYPE/$PLDIRNAME" ]] || [[ -n "$NONEXISTING" ]]; then
				[[ -f "$CURRABSPATH/.update-wp-$CONTENTTYPE.pre-move" ]] && ( set -x; source "$CURRABSPATH/.update-wp-$CONTENTTYPE.pre-move" )
				if ( set -x;  rm -rf "$BLOGBASE/wp-content/$CONTENTTYPE/$PLDIRNAME" ) || [[ -n "$NONEXISTING" ]]; then
					if ( set -x;  mv "$WPTEMPDIR/$PLDIRNAME" "$BLOGBASE/wp-content/$CONTENTTYPE"/ ); then
						echo -e "${cG}SUCCESS${cZ}: at this point you may want to take a fresh backup."
						[[ -f "$CURRABSPATH/.update-wp-$CONTENTTYPE.post-move" ]] && ( set -x; source "$CURRABSPATH/.update-wp-$CONTENTTYPE.post-move" )
						( set -x; sudo chmod -R -x,+X "$BLOGBASE" )
						( set -x; sudo chown -R $(whoami):www-data "$BLOGBASE" )
						[[ -f "$CURRABSPATH/.update-blog.post-permission-fix" ]] && ( set -x; source "$CURRABSPATH/.update-blog.post-permission-fix" )
					else
						echo -e "${cR}ERROR${cZ}: failed to move new ${cW}$PLDIRNAME${cZ} into ${cW}wp-content/$CONTENTTYPE/${cZ}."
						exit 1
					fi
				else
					echo -e "${cR}ERROR${cZ}: failed to remove old directory ${cW}wp-content/$CONTENTTYPE/$PLDIRNAME${cZ}."
					exit 1
				fi
			else
				echo -e "${cR}ERROR${cZ}: there is no directory ${cW}$PLDIRNAME${cZ} inside ${cW}wp-content/$CONTENTTYPE${cZ}, yet."
				exit 1
			fi
		else
			echo -e "${cR}ERROR${cZ}: unexpected number of unpacked (top-level) directories: $COUNT."
			exit 1
		fi
	else
		echo -e "${cR}ERROR${cZ}: could not unpack update contents into temporary folder."
		exit 1
	fi
}

case "${0##*/}" in
	update*themes.sh | update*themes | update*theme.sh | update*theme)
		CTYPE=themes
		;;
	*)
		CTYPE=plugins
		;;
	# update*plugins.sh | update*plugins | update*plugin.sh | update*plugin)
esac

WPTEMPDIR=$(mktemp -dp $(pwd))
trap 'rm -rf "$WPTEMPDIR"; trap - INT TERM EXIT; exit $?' INT TERM EXIT
find "$CURRABSPATH" -name 'wp-login.php' -printf '%h\n' 2> /dev/null|while read name; do
	BLOGDIR=${name#$CURRABSPATH/}
	echo "BLOGDIR=$BLOGDIR BASEDIR=$CURRABSPATH"
	for updfile in "$@"; do
		( update_content "$updfile" "$BLOGDIR" "$CURRABSPATH" "$CTYPE" )
	done
done
