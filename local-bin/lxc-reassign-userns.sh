#!/usr/bin/env bash

function syntax
{
	echo "SYNTAX: ${0##*/} <from-user> <to-user> <container-name>"
	[[ -n "$1" ]] && echo -e "\nERROR: ${1}."
	exit 1
}

# Checks
[[ -n "$1" ]] || syntax "<from-user> is not set"
[[ -n "$2" ]] || syntax "<to-user> is not set"
[[ -n "$3" ]] || syntax "<container-name> is not set"
[[ "$UID" -eq "0" ]] || syntax "${0##*/}" "You must be superuser to make use of this script"
# Constants with stuff we need
readonly USERFROM=$1
readonly USERTO=$2
shift; shift
readonly CONTAINER=${1:-*}
LXCLOCAL=".local/share/lxc"
readonly HOMEFROM=$(eval echo ~$USERFROM)
readonly HOMETO=$(eval echo ~$USERTO)
readonly LXCFROM="$HOMEFROM/$LXCLOCAL"
readonly LXCTO="$HOMETO/$LXCLOCAL"
readonly GIDBASEFROM=$(awk -F : "\$1 ~/$USERFROM/ {print \$2}" /etc/subgid)
readonly UIDBASEFROM=$(awk -F : "\$1 ~/$USERFROM/ {print \$2}" /etc/subuid)
readonly GIDSIZEFROM=$(awk -F : "\$1 ~/$USERFROM/ {print \$3}" /etc/subgid)
readonly UIDSIZEFROM=$(awk -F : "\$1 ~/$USERFROM/ {print \$3}" /etc/subuid)
readonly GIDBASETO=$(awk -F : "\$1 ~/$USERTO/ {print \$2}" /etc/subgid)
readonly UIDBASETO=$(awk -F : "\$1 ~/$USERTO/ {print \$2}" /etc/subuid)
readonly GIDSIZETO=$(awk -F : "\$1 ~/$USERTO/ {print \$3}" /etc/subgid)
readonly UIDSIZETO=$(awk -F : "\$1 ~/$USERTO/ {print \$3}" /etc/subuid)
unset LXCLOCAL
# More checks
[[ -d "$LXCFROM" ]] || syntax "Could not locate '$LXCFROM'. It is not a directory as expected"
[[ -e "$LXCTO" ]] && syntax "Destination '$LXCTO' already exists. However, it must not"
for i in GIDBASEFROM UIDBASEFROM GIDBASETO UIDBASETO; do
	(($i > 0)) || syntax "Could not determine base/offset of subordinate UID/GID range"
done
for i in GIDSIZEFROM UIDSIZEFROM GIDSIZETO UIDSIZETO; do
	(($i > 0)) || syntax "Could not determine length of subordinate UID/GID range"
done

echo "Going to migrate container: $CONTAINER"
echo -e "\tfrom user $USERFROM ($HOMEFROM): subUID=${UIDBASEFROM}..$((UIDBASEFROM+UIDSIZEFROM)); subGID=${GIDBASEFROM}..$((GIDBASEFROM+GIDSIZEFROM))"
echo -e "\tto user $USERTO ($HOMETO): subUID=${UIDBASETO}..$((UIDBASETO+UIDSIZETO)); subGID=${GIDBASETO}..$((GIDBASETO+GIDSIZETO))"
while read -p "Do you want to continue? (y/N) "; do
	case ${REPLY:0:1} in
		y|Y)
			break;
			;;
		*)
			echo "User asked to abort."
			exit 1
			;;
	esac
done

# Find the UIDs and GIDs in use in the container
readonly SUBGIDSFROM=$(find -H "$LXCFROM" -printf '%G\n'|sort -u)
readonly SUBUIDSFROM=$(find -H "$LXCFROM" -printf '%U\n'|sort -u)

# Change group
for gid in $SUBGIDSFROM; do
	let GIDTO=$(id -g "$USERTO")
	if ((gid == $(id -g "$USERFROM"))); then
		echo "Changing group from $USERFROM ($gid) to $USERTO ($GIDTO)"
		find -H "$LXCFROM/$CONTAINER" -gid $gid -exec chgrp $GIDTO {} +
	elif ((gid >= GIDBASEFROM )) && ((gid <= GIDBASEFROM+GIDSIZEFROM)); then
		let GIDTO=$((gid-GIDBASEFROM+GIDBASETO))
		echo "Changing group $gid -> $GIDTO"
		find -H "$LXCFROM/$CONTAINER" -gid $gid -exec chgrp $GIDTO {} +
	else
		echo "ERROR: Some file/folder inside '$LXCFROM/$CONTAINER' has a group not assigned to $USERFROM (assigned subordinate GIDs)."
		echo -e "Use:\n\tfind -H '$LXCFROM/$CONTAINER' -gid $gid\nto list those files/folders."
		exit 1
	fi
done

# Change owner
for uid in $SUBUIDSFROM; do
	let UIDTO=$(id -u "$USERTO")
	if ((uid == $(id -u "$USERFROM"))); then
		echo "Changing owner from $USERFROM ($uid) to $USERTO ($UIDTO)"
		find -H "$LXCFROM/$CONTAINER" -uid $uid -exec chown $UIDTO {} +
	elif ((uid >= UIDBASEFROM )) && ((uid <= UIDBASEFROM+UIDSIZEFROM)); then
		let UIDTO=$((uid-UIDBASEFROM+UIDBASETO))
		echo "Changing owner $uid -> $UIDTO"
		find -H "$LXCFROM/$CONTAINER" -uid $uid -exec chown $UIDTO {} +
	else
		echo "ERROR: Some file/folder inside '$LXCFROM/$CONTAINER' has an owner not assigned to $USERFROM (assigned subordinate UIDs)."
		echo -e "Use:\n\tfind -H '$LXCFROM/$CONTAINER' -uid $uid\nto list those files/folders."
		exit 1
	fi
done
mv "$LXCFROM/$CONTAINER" "$LXCTO/" || { echo "ERROR: failed to move to destination: ${LXCTO}/${CONTAINER}."; exit 1; }
