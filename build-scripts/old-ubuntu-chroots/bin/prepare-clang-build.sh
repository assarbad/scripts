#!/usr/bin/env bash
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
	(set -x; apt-get -y install build-essential $GITPKG bison flex texinfo ccache language-pack-en apt-file autoconf automake)

	for tool in addr2line ar nm objcopy objdump ranlib readelf strip; do
		if [[ ! -e "$(uname -m)-linux-gnu-${tool}" ]]; then
			(set -x; cd /usr/bin && ln -s "$tool" "$(uname -m)-linux-gnu-${tool}")
		fi
	done
fi
chmod u+r /var/run/crond.reboot
echo Cleaning a bit
apt-get --purge autoremove
rm -f /var/cache/apt/srcpkgcache.bin /var/cache/apt/pkgcache.bin
for i in /etc/.pwd.lock /var/log/*.{0..9} /var/log/*.{0..9}.gz /var/cache/apt/archives/partial/* /var/cache/debconf/*.dat-old; do
	[[ -e "$i" ]] && (set -x; rm -f "$i")
done
find /etc -type f -name '*.dpkg-old' -delete
