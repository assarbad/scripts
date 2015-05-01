#!/usr/bin/env bash
pushd $(dirname $0) > /dev/null; CURRABSPATH=$(readlink -nf "$(pwd)"); popd > /dev/null; # Get the directory in which the script resides
[[ -n "$DEBUG" ]] && set -x
TEMPDIR="$CURRABSPATH/tmp"
SRCPDIR="$CURRABSPATH/srcpkgs"

MUSLURL="http://www.musl-libc.org/releases/musl-1.1.8.tar.gz"
ZLIBURL="http://zlib.net/zlib-1.2.8.tar.gz"
DRPBURL="https://matt.ucc.asn.au/dropbear/dropbear-2015.67.tar.bz2"

MUSLPKG="$SRCPDIR/${MUSLURL##*/}"
ZLIBPKG="$SRCPDIR/${ZLIBURL##*/}"
DRPBPKG="$SRCPDIR/${DRPBURL##*/}"

[[ -d "$TEMPDIR" ]] || mkdir "$TEMPDIR" || { echo "FATAL: Could not create $TEMPDIR."; exit 1; }
[[ -d "$SRCPDIR" ]] || mkdir "$SRCPDIR" || { echo "FATAL: Could not create $SRCPDIR."; exit 1; }

for i in musl zlib dropbear; do
	[[ -d "$TEMPDIR/$i" ]] && rm -rf "$TEMPDIR/$i"
	[[ -d "$TEMPDIR/$i" ]] || mkdir "$TEMPDIR/$i" || { echo "FATAL: Could not create $TEMPDIR/$i."; exit 1; }
done
(
	[[ -f "$MUSLPKG" ]] || wget -O "$MUSLPKG" "$MUSLURL" || curl -o "$MUSLPKG" "$MUSLURL" || exit 1
	[[ -f "$ZLIBPKG" ]] || wget -O "$ZLIBPKG" "$ZLIBURL" || curl -o "$ZLIBPKG" "$ZLIBURL" || exit 1
	[[ -f "$DRPBPKG" ]] || wget -O "$DRPBPKG" "$DRPBURL" || curl -o "$DRPBPKG" "$DRPBURL" || exit 1
	echo "Unpacking musl" && tar --strip-components=1 -C "$TEMPDIR/musl" -xvf "$MUSLPKG" && mkdir "$TEMPDIR/musl/tempinstall" && \
		echo "Unpacking zlib" && tar --strip-components=1 -C "$TEMPDIR/zlib" -xvf "$ZLIBPKG" && mkdir "$TEMPDIR/zlib/tempinstall" && \
		echo "Unpacking dropbear" && tar --strip-components=1 -C "$TEMPDIR/dropbear" -xvf "$DRPBPKG"
) || { echo "FATAL: Could not unpack one of the required source packages. Check above output for clues."; exit 1; }
echo "Configuring and building musl"
(
	cd "$TEMPDIR/musl" && \
		./configure --disable-shared "--prefix=$TEMPDIR/musl/tempinstall" && \
		make -j8 && \
		make install
) || { echo "FATAL: musl failed to build. Check above output for clues."; exit 1; }
# Configure GCC for our purpose
export CC="musl-gcc"
export LDFLAGS="-Wl,--gc-sections"
export CFLAGS="-ffunction-sections -fdata-sections"
# proceed ...
echo "Configuring and building zlib"
(
	export PATH="$TEMPDIR/musl/tempinstall/bin:$PATH"
	cd "$TEMPDIR/zlib" && \
		./configure --static "--prefix=$TEMPDIR/zlib/tempinstall" && \
		make -j 8 && \
		make install
) || { echo "FATAL: zlib failed to build. Check above output for clues."; exit 1; }
echo "Configuring and building dropbear"
(
	export PATH="$TEMPDIR/musl/tempinstall/bin:$PATH"
	export CC="$CC -nostdinc -isystem $TEMPDIR/musl/tempinstall/include -isystem /usr/include/$(gcc -dumpmachine) -isystem /usr/include"
	cd "$TEMPDIR/dropbear" && \
		./configure "--with-zlib=$TEMPDIR/zlib/tempinstall" --disable-syslog --disable-lastlog --without-pam --enable-bundled-libtom && \
		make -j8 PROGRAMS="dropbear dbclient scp dropbearkey dropbearconvert" MULTI=1 STATIC=1 SCPPROGRESS=1 strip && \
		DBVER=$(./dropbearmulti 2>&1|grep -oE 'v[[:digit:]]+\.[[:digit:]]+'||echo -n 'unknown')
		tar -czvf "$CURRABSPATH/dropbear-$DBVER-static.tgz" $(find -maxdepth 1 -type l) dropbearmulti
) || { echo "FATAL: dropbear failed to build. Check above output for clues."; exit 1; }
[[ -n "$NO_REMOVE_TEMPDIR" ]] || rm -rf "$TEMPDIR"
