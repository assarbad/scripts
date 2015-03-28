#!/usr/bin/env bash
pushd $(dirname $0) > /dev/null; CURRABSPATH=$(readlink -nf "$(pwd)"); popd > /dev/null; # Get the directory in which the script resides
MUSLURL="http://www.musl-libc.org/releases/musl-0.9.10.tar.gz"
BZIPURL="http://www.bzip.org/1.0.6/bzip2-1.0.6.tar.gz"
PYTHURL="http://www.python.org/ftp/python/2.7.4/Python-2.7.4.tar.bz2"
MUSLPKG="$CURRABSPATH/musl-0.9.10.tar.gz"
BZIPPKG="$CURRABSPATH/bzip2-1.0.6.tar.gz"
PYTHPKG="$CURRABSPATH/Python-2.7.4.tar.bz2"
TEMPDIR="$CURRABSPATH/tmp"

[[ -d "$TEMPDIR" ]] || mkdir "$TEMPDIR" || { echo "FATAL: Could not create $TEMPDIR."; exit 1; }

for i in musl bzip python; do
	[[ -d "$TEMPDIR/$i" ]] && rm -rf "$TEMPDIR/$i"
	[[ -d "$TEMPDIR/$i" ]] || mkdir "$TEMPDIR/$i" || { echo "FATAL: Could not create $TEMPDIR/$i."; exit 1; }
done
(
	[[ -f "$MUSLPKG" ]] || curl -o "$MUSLPKG" "$MUSLURL" || wget -qO "$MUSLPKG" "$MUSLURL" || exit 1
	[[ -f "$BZIPPKG" ]] || curl -o "$BZIPPKG" "$BZIPURL" || wget -qO "$BZIPPKG" "$BZIPURL" || exit 1
	[[ -f "$PYTHPKG" ]] || curl -o "$PYTHPKG" "$PYTHURL" || wget -qO "$PYTHPKG" "$PYTHURL" || exit 1
	echo "Unpacking musl" && tar --strip-components=1 -C "$TEMPDIR/musl" -xvf "$MUSLPKG" && mkdir "$TEMPDIR/musl/tempinstall" && \
		echo "Unpacking bzip2" && tar --strip-components=1 -C "$TEMPDIR/bzip" -xvf "$BZIPPKG" && mkdir "$TEMPDIR/bzip/tempinstall"
		echo "Unpacking Python" && tar --strip-components=1 -C "$TEMPDIR/python" -xvf "$PYTHPKG" && mkdir "$TEMPDIR/python/tempinstall"
) || { echo "FATAL: Could not unpack one of the required source packages. Check above output for clues."; exit 1; }
echo "Configuring and building musl"
(
	cd "$TEMPDIR/musl" && \
		./configure --disable-shared "--prefix=$TEMPDIR/musl/tempinstall" && \
		make -j8 && \
		make install
) || { echo "FATAL: musl failed to build. Check above output for clues."; exit 1; }
# Configure GCC for our purpose
export CC="$TEMPDIR/musl/tempinstall/bin/musl-gcc"
export LDFLAGS="-Wl,--gc-sections"
export CFLAGS="-ffunction-sections -fdata-sections"
# proceed ...
echo "Configuring and building bzip2"
(
	cd "$TEMPDIR/bzip" && \
		make -j 8 && \
		make PREFIX="$TEMPDIR/bzip/tempinstall" install
) || { echo "FATAL: bzip2 failed to build. Check above output for clues."; exit 1; }
echo "Configuring and building Python"
(
	export LDFLAGS="-Wl,--gc-sections -static -static-libgcc"
	cd "$TEMPDIR/python" && \
		./configure --disable-shared "--prefix=$TEMPDIR/python/tempinstall" && \
		make -j 8 && \
		make install
) || { echo "FATAL: Python failed to build. Check above output for clues."; exit 1; }
#rm -rf "$TEMPDIR"
