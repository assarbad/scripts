#!/usr/bin/env bash

function conv_date
{
	local DATE="$1" day month year
	echo "$DATE"|tr -d '.'|while read -r day month year; do
		case $month in
			Jan*)
				month="Jan"
				;;
			Feb*)
				month="Feb"
				;;
			Mär*|Mar*)
				month="Mar"
				;;
			Apr*)
				month="Apr"
				;;
			Ma[iy]*)
				month="May"
				;;
			Jun[ie])
				month="Jun"
				;;
			Jul[iy])
				month="Jul"
				;;
			Aug*)
				month="Aug"
				;;
			Sep*)
				month="Sep"
				;;
			O[ck]t*)
				month="Oct"
				;;
			Nov*)
				month="Nov"
				;;
			De[cz]*)
				month="Dec"
				;;
		esac
		DATE=$(date --date="$day $month $year" +%Y-%m-%d)
		(($? == 0)) || return 1
		echo "$DATE"
	done
	return 0
}

for i in *.pdf; do
	if rga --quiet 'NachDenkSeiten' "$i" > /dev/null 2>&1; then
		SNIPPET=$(rga --color never -UIH 'NachDenkSeiten - ([^\|]+)\|\s+?Veröffentlicht am:\s+?([^\|]+)\|' -r '$1|$2' \
			"$i"| \
				grep ':Page 1:'| \
				cut -d : -f 3-| \
				tr -d '\n'| \
				awk '{$1=$1;print}'| \
				sed -e 's|:|：|g;s|\?|？|g;'| \
				rg '^([^|]+)\|\s*?(\d+\.\s+?\w+\s+?\d+)\s+?1' -r '$1:$2'| \
				awk -F : '{$1=$1;$2=$2;printf "TITLE=\"%s\"; DATE=\"%s\";", $1, $2}'| \
				sed -e 's|[ \t]*";|";|g;s|="[ \t]*|="|g' \
		)
		if [[ -n "$SNIPPET" ]]; then
			echo "$i"
			eval "$SNIPPET"
			if [[ -n "$TITLE" && -n "$DATE" ]]; then
				DATE=$(conv_date "$DATE")
				if [[ $? -ne 0 ]]; then
					echo "WARNING: skipping $i"
					continue
				fi
				NEWNAME="$DATE $TITLE.${i##*.}"
				if [[ "$NEWNAME" != "$i" ]]; then
					( set -x; mv "$i" "$NEWNAME" )
				fi
			fi
		fi
	fi
done
