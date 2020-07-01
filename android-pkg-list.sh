#!/usr/bin/env bash
set +e
AAPT=/data/local/tmp/aapt-arm-pie
#wget -O "${AAPT##*/}" https://github.com/Calsign/APDE/blob/master/APDE/src/main/assets/aapt-binaries/aapt-arm-pie
#adb push "${AAPT##*/}" "${AAPT%/*}/"
#adb shell chmod 0755 "$AAPT"

# Sorted list of _all_ installed packages in the format: "package:/path/to/apk.apk=com.vendor.app.shorthand"
for pkg in $(adb shell pm list packages -f|sed 's|^package:||'|sort -t = -k 2); do
	APPID=${pkg##*=}
	APKPATH=${pkg%%=*}
	APPNAME="$(adb shell $AAPT d badging "$APKPATH" 2> /dev/null|awk -F: '$1 ~ /^application-label-en-GB$/ {print $2; exit;} $1 ~ /^application-label$/ {print $2; exit; }'|sed "s|'||g")"
	echo "$APPID: ${APPNAME:-UNKNOWN} ($APKPATH)"
done
