#!/usr/bin/env bash
# vim: set autoindent smartindent tabstop=4 shiftwidth=4 noexpandtab filetype=sh:
[[ -t 1 ]] && { cG="\033[1;32m"; cR="\033[1;31m"; cB="\033[1;34m"; cW="\033[1;37m"; cY="\033[1;33m"; cG_="\033[0;32m"; cR_="\033[0;31m"; cB_="\033[0;34m"; cW_="\033[0;37m"; cY_="\033[0;33m"; cZ="\033[0m"; export cR cG cB cY cW cR_ cG_ cB_ cY_ cW_ cZ; }
for tool in find grep mysqldump perl sed sha1sum sha256sum sudo tar tee wc wget; do type $tool > /dev/null 2>&1 || { echo -e "${cR}ERROR:${cZ} couldn't find '$tool' which is required by this script."; exit 1; }; done
[[ -n "$DEBUG" ]] && set -x
pushd $(dirname $0) > /dev/null; CURRABSPATH=$(readlink -nf "$(pwd)"); popd > /dev/null; # Get the directory in which the script resides

function fetch_and_verify
{
	local UPDURL="$1"
	local DLNAME="$(mktemp -dp $(pwd))/${UPDURL##*/}"
	# Make sure we clean up after ourselves
	trap 'echo "Removing temporary download path"; ( set -x; rm -rf "'${DLNAME%/*}'" ); trap - INT TERM EXIT; exit $?' INT TERM EXIT
	echo -e "Downloading ${cW}$UPDURL${cZ} -> ${cW}$DLNAME${cZ}" > /dev/stderr
	if wget -qO "$DLNAME" "$UPDURL" > /dev/stderr; then
		echo -e "Downloading ${cW}$UPDURL.sha1${cZ}" > /dev/stderr
		if wget -qO "$DLNAME.sha1" "$UPDURL.sha1" > /dev/stderr; then
			echo -e "Verifying download" > /dev/stderr
			if sha1sum "$DLNAME"|grep -iq "^$(cat "$DLNAME.sha1")"; then
				echo "$DLNAME"
				trap - INT TERM EXIT
				exit 0
			fi
		fi
	fi
	exit 1
}

function blog_update
{
	local UPDTGZ="${1:-https://wordpress.org/latest.tar.gz}"
	local BLOGDIR="$2"
	local BASEDIR="$3"
	local BLOGBASE="$BASEDIR/$BLOGDIR"
	local WPCONFIG="$BLOGBASE/wp-config.php"
	if [[ "$UPDTGZ" =~ https://(de\.)?wordpress.org/.*\.tar\.gz ]]; then # is it a URL?
		UPDTGZ=$(fetch_and_verify "$UPDTGZ")
		if [[ -z "$UPDTGZ" ]]; then
			echo -e "${cR}FATAL:${cZ} Download failed for unknown reasons."
			exit 1
		else
			echo -e "Downloaded and verified ${cW}$UPDTGZ${cZ}"
		fi
	fi
	# Make sure we clean up after ourselves
	#trap 'echo "Removing temporary download path"; ( set -x; rm -rf "'${UPDTGZ%/*}'" ); trap - INT TERM EXIT; exit $?' INT TERM EXIT
	[[ -f "$WPCONFIG" ]] || WPCONFIG="$BASEDIR/wp-config.php"
	# Import the DB credentials as variables by the same name as the defines in PHP
	eval $(perl -pe "s/define\('(DB_(?:NAME|USER|PASSWORD|HOST))', '([^']+)'\);.+/\$1='\$2';/img;" "$WPCONFIG" 2>/dev/null|grep -E '^DB_(NAME|USER|PASSWORD|HOST)')
	source <(grep -oP '^\$wp_version\s+=\s+[^;]+' "$BLOGBASE/wp-includes/version.php"|sed -e 's|\$||g;s| ||g')
	[[ -n "$wp_version" ]] || { echo -e "${cR}ERROR${cZ}: could not determine WordPress version."; exit 1; }
	local NOWDATE=$(date +"%Y-%m-%dT%H-%M-%S")
	if [[ "$UPDTGZ" != "--backup" ]] && [[ "$UPDTGZ" != "-b" ]]; then
		local NEWWPTGZ=${UPDTGZ?"ERROR: you must give the path to a .tgz with the new WordPress files as an argument to the script."}
		[[ -f "$NEWWPTGZ" ]] || { echo -e "${cR}ERROR${cZ}: '$NEWWPTGZ' is not a file."; exit 1; }
		[[ -r "$NEWWPTGZ" ]] || { echo -e "${cR}ERROR${cZ}: '$NEWWPTGZ' is not readable."; exit 1; }
	fi
	local OLDWPBKUP="$BASEDIR/${NOWDATE}_wordpress_backup_for_${DB_NAME}_wp${wp_version}.tgz"
	OLDDBBKUP="$BASEDIR/${NOWDATE}_$DB_NAME.sql"
	echo -e "Backing up ${cW}database $DB_NAME${cZ}"
	# "--host=$DB_HOST" "--user=$DB_USER" "--password=$DB_PASSWORD"
	if ( \
		sudo mysqldump --defaults-file=/etc/mysql/debian.cnf -w "comment_approved not in ('spam', 'trash')" --opt "$DB_NAME" wp_comments \
		&& \
		sudo mysqldump --defaults-file=/etc/mysql/debian.cnf --ignore-table=${DB_NAME}.wp_comments --opt "$DB_NAME" \
		) > "$OLDDBBKUP"; then
		( set -x; ( cd "${OLDDBBKUP%/*}" && sha256sum "${OLDDBBKUP##*/}" )|tee "$OLDDBBKUP.SHA256SUM" )
		echo -e "Backing up ${cW}folder${cZ}"
		if ( set -x; tar -C "$BASEDIR" -czf "$OLDWPBKUP" "${BLOGBASE#$BASEDIR/}" "${WPCONFIG#$BASEDIR/}" $(cd "$BASEDIR" && find -type f -maxdepth 1 -name 'update-blog.sh' -o -name 'update-wp-*' -o -name '.update-blog.*' -o -name '.update-wp-*') "${OLDDBBKUP##*/}" && ( cd "${OLDWPBKUP%/*}" && sha256sum "${OLDWPBKUP##*/}" )|tee "$OLDWPBKUP.SHA256SUM" ); then
			if [[ "$UPDTGZ" != "--backup" ]] && [[ "$UPDTGZ" != "-b" ]]; then
				echo -e "Removing old wp-include and wp-admin"
				rm -rf "$BLOGBASE/wp-includes" "$BLOGBASE/wp-admin" || \
					{ echo -e "ERROR: failed to remove old wp-include and wp-admin folders."; exit 1; }
				echo -e "Unpacking new WordPress release"
				if ( set -x; tar -C "$BLOGBASE" --strip-components=1 -xzf "$NEWWPTGZ" ); then
					[[ -f "$CURRABSPATH/.update-blog.post-overwrite" ]] && ( set -x; source "$CURRABSPATH/.update-blog.post-overwrite" )
					( set -x; sudo chmod -R -x,+X "$BLOGBASE" )
					( set -x; sudo chown -R $(whoami):www-data "$BLOGBASE" )
					[[ -f "$CURRABSPATH/.update-blog.post-permission-fix" ]] && ( set -x; source "$CURRABSPATH/.update-blog.post-permission-fix" )
					rm -f "$OLDDBBKUP"
					echo -e "Done."
				else
					echo -e "${cR}ERROR${cZ}: could not extract new WordPress .tgz to '$BLOGBASE' folder"
					exit 1
				fi
			else
				echo -e "${cW}INFO:${cZ} no new release tarball given, skipping actual upgrade."
				rm -f "$OLDDBBKUP" "$OLDDBBKUP.SHA256SUM"
				echo -e "Done."
			fi
		else
			rm -f "$OLDDBBKUP" "$OLDWPBKUP" "$OLDDBBKUP.SHA256SUM" "$OLDWPBKUP.SHA256SUM" 2> /dev/null
			echo -e "${cR}ERROR${cZ}: could not back up old WordPress folder"
			exit 1
		fi
	else
			rm -f "$OLDDBBKUP" "$OLDWPBKUP" "$OLDDBBKUP.SHA256SUM" "$OLDWPBKUP.SHA256SUM" 2> /dev/null
			echo -e "${cR}ERROR${cZ}: could not back up old WordPress database"
			exit 1
	fi
}

find "$CURRABSPATH" -name 'wp-login.php' -printf '%h\n' 2> /dev/null|while read name; do
	BLOGDIR=${name#$CURRABSPATH/}
	echo "BLOGDIR=$BLOGDIR BASEDIR=$CURRABSPATH"
	( blog_update "$1" "$BLOGDIR" "$CURRABSPATH" )
done
