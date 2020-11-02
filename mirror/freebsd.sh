#!/usr/bin/env bash
FREEBSD_VERSION=${1:-12.2}
BASEURL="https://download.freebsd.org/ftp/releases"
for arch in amd64 i386; do
	DIRNAME="FreeBSD-$FREEBSD_VERSION.$arch"
	[[ -d "$DIRNAME" ]] || mkdir -p "$DIRNAME"
	for url in $BASEURL/$arch/$arch/ISO-IMAGES/$FREEBSD_VERSION/FreeBSD-${FREEBSD_VERSION}-RELEASE-${arch}-{bootonly,disc1,dvd1}.iso.xz $BASEURL/$arch/$arch/ISO-IMAGES/$FREEBSD_VERSION/CHECKSUM.SHA{256,512}-FreeBSD-${FREEBSD_VERSION}-RELEASE-${arch}; do
		( cd "$DIRNAME"; set -x; curl -O "$url" )
	done
done
