#!/usr/bin/env bash
# vim: set autoindent smartindent ts=4 sw=4 sts=4 noet filetype=sh:
source /etc/lsb-release
[[ -n "$DISTRIB_CODENAME" ]] || { echo "ERROR: failed to retrieve info about distro I'm running on."; exit 1; }
[[ -n "$DISTRIB_RELEASE" ]] || { echo "ERROR: failed to retrieve info about distro I'm running on."; exit 1; }
UBUCODENAME=${UBUCODENAME:-$DISTRIB_CODENAME}
DNSIP=${DNSIP:-"8.8.8.8"}
RESOLVCONF=/etc/resolv.conf
DEBSRC="" # could also be deb-src to enable source packages in APT
[[ -L "$RESOLVCONF" ]] && rm "$RESOLVCONF"
(set -x; echo "nameserver $DNSIP"|tee "$RESOLVCONF")
(set -x; echo "Acquire::ForceIPv4 true;"|tee "/etc/apt/apt.conf.d/00preferIPv4")

# We only care about LTS versions
case "$DISTRIB_RELEASE" in
	6.06|8.04|10.04|12.04|14.04)
		SERVERNAME="old-releases.ubuntu.com"
		GITPKG="git-core"
		;;
	16.04)
		SERVERNAME="archive.ubuntu.com"
		GITPKG="git-core"
		;;
	*)
		SERVERNAME="archive.ubuntu.com"
		GITPKG="git"
		;;
esac

cat > /etc/apt/sources.list <<EOF
# Required
deb http://$SERVERNAME/ubuntu/ $UBUCODENAME main restricted universe multiverse
deb http://$SERVERNAME/ubuntu/ $UBUCODENAME-updates main restricted universe multiverse
deb http://$SERVERNAME/ubuntu/ $UBUCODENAME-security main restricted universe multiverse
${DEBSRC:-"# deb-src"} http://$SERVERNAME/ubuntu/ $UBUCODENAME main restricted universe multiverse
${DEBSRC:-"# deb-src"} http://$SERVERNAME/ubuntu/ $UBUCODENAME-updates main restricted universe multiverse
${DEBSRC:-"# deb-src"} http://$SERVERNAME/ubuntu/ $UBUCODENAME-security main restricted universe multiverse

# Optional
#deb http://$SERVERNAME/ubuntu/ $UBUCODENAME-backports main restricted universe multiverse
${DEBSRC:-"# deb-src"} http://$SERVERNAME/ubuntu/ $UBUCODENAME-backports main restricted universe multiverse
EOF

if [[ -z "$NOINSTALL" ]]; then
	(set -x; apt-get -y update)
	(set -x; apt-get -y dist-upgrade)

	cat > /etc/locale.nopurge <<-EOF
	####################################################
	# This is the configuration file for localepurge(8).
	####################################################

	####################################################
	# Uncommenting this string enables removal of localized 
	# man pages based on the configuration information for
	# locale files defined below:

	MANDELETE

	####################################################
	# Uncommenting this string causes localepurge to simply delete
	# locales which have newly appeared on the system without
	# bothering you about it:

	DONTBOTHERNEWLOCALE

	####################################################
	# Uncommenting this string enables display of freed disk
	# space if localepurge has purged any superfluous data:

	SHOWFREEDSPACE

	#####################################################
	# Commenting out this string enables faster but less
	# accurate calculation of freed disk space:

	#QUICKNDIRTYCALC

	#####################################################
	# Commenting out this string disables verbose output:

	#VERBOSE

	#####################################################
	# Following locales won't be deleted from this system
	# after package installations done with apt-get(8):

	en_US.UTF-8
	EOF

	(set -x; apt-get -y --no-install-recommends install build-essential $GITPKG bison flex texinfo language-pack-en apt-file autoconf automake texlive texlive-font-utils ghostscript texlive-generic-recommended gawk ncurses-dev deborphan debsums gettext)

	for tool in addr2line ar nm objcopy objdump ranlib readelf strip; do
		if [[ ! -e "$(uname -m)-linux-gnu-${tool}" ]]; then
			(set -x; cd /usr/bin && ln -s "$tool" "$(uname -m)-linux-gnu-${tool}")
		fi
	done
fi
chmod u+r /var/run/crond.reboot
# Disable all other English locales
sed -i -e 's|^|#|g' /var/lib/locales/supported.d/en
cat > /var/lib/locales/supported.d/local <<-EOF
	en_US ISO-8859-1
	en_US.UTF-8 UTF-8
	EOF
locale-gen --purge
echo Cleaning a bit
if type deborphan > /dev/null 2>&1; then
	ORPHANED=$(deborphan)
	if [[ -n "$ORPHANED" ]]; then
		apt-get -y -f autoremove $ORPHANED
		ORPHANED=$(deborphan)
		if [[ -n "$ORPHANED" ]]; then
			apt-get -y -f autoremove $ORPHANED
			ORPHANED=$(deborphan)
			if [[ -n "$ORPHANED" ]]; then
				apt-get -y -f autoremove $ORPHANED
			fi
		fi
	fi
fi
if type localepurge > /dev/null 2>&1; then
	localepurge
fi
apt-get --purge autoremove
rm -f /var/cache/apt/srcpkgcache.bin /var/cache/apt/pkgcache.bin /var/log/vmbuilder-install.log /var/log/bootstrap.log /var/log/apt/history.log /var/log/apt/term.log /var/log/aptitude /var/log/boot /var/log/btmp /var/log/dmesg /var/log/dpkg.log /var/log/faillog /var/log/fsck/checkfs /var/log/fsck/checkroot /var/log/lastlog /var/log/pycentral.log /var/log/wtmp
rmdir /lost+found /selinux
for i in /etc/.pwd.lock /var/log/*.{0..9} /var/log/*.{0..9}.gz /var/cache/apt/archives/partial/* /var/cache/debconf/*.dat-old; do
	[[ -e "$i" ]] && (set -x; rm -f "$i")
done
find /etc -type f -name '*.dpkg-old' -delete
