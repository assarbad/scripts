#!/usr/bin/env bash
pushd $(dirname $0) > /dev/null; CURRABSPATH=$(readlink -nf "$(pwd)"); popd > /dev/null; # Get the directory in which the script resides
set -x
MUSLPKG="musl:musl.tgz:http://www.musl-libc.org/releases/musl-1.0.0.tar.gz"
LEVTPKG="libevent:libevent2.tgz:https://github.com/downloads/libevent/libevent/libevent-2.0.21-stable.tar.gz"
TMUXPKG="tmux:tmux.tgz:http://downloads.sourceforge.net/project/tmux/tmux/tmux-1.9/tmux-1.9a.tar.gz?r=&use_mirror=heanet"
NCRSPKG="ncurses:ncurses.tgz:NONE"
TEMPDIR="$CURRABSPATH/tmp"
TMPLIB="tempinstall/lib"
TMPINC="tempinstall/include"
MUSLCC="$TEMPDIR/musl/tempinstall/bin/musl-gcc"
[[ -d "$TEMPDIR" ]] || mkdir "$TEMPDIR" || { echo "FATAL: Could not create $TEMPDIR."; exit 1; }
[[ -f "$CURRABSPATH/ncurses.tgz" ]] || ( cd "$TEMPDIR" && apt-get source ncurses && cp "$TEMPDIR"/ncurses*.orig.tar.gz "$CURRABSPATH/ncurses.tgz" )
for i in "$MUSLPKG" "$NCRSPKG" "$LEVTPKG" "$TMUXPKG"; do
	NAME=${i%%:*}
	i=${i#*:}
	TGZ=${i%%:*}
	URL=${i#*:}
	[[ -d "$TEMPDIR/$NAME" ]] && rm -rf "$TEMPDIR/$NAME"
	[[ -d "$TEMPDIR/$NAME" ]] || mkdir  "$TEMPDIR/$NAME" || { echo "FATAL: Could not create $TEMPDIR/$NAME."; exit 1; }
	[[ -f "$CURRABSPATH/$TGZ" ]] || curl -o "$CURRABSPATH/$TGZ" "$URL" || wget -O "$CURRABSPATH/$TGZ" "$URL" || { echo "FATAL: failed to fetch $URL."; exit 1; }
	echo "Unpacking $NAME" && tar --strip-components=1 -C "$TEMPDIR/$NAME" -xf "$TGZ" && mkdir "$TEMPDIR/$NAME/tempinstall" \
		|| { echo "FATAL: Could not unpack one of the required source packages. Check above output for clues."; exit 1; }
	echo "Building $NAME (this may take some time)"
	(
		PREFIX="$TEMPDIR/$NAME/tempinstall"
		case $NAME in
			musl )
				(cd "$TEMPDIR/$NAME" && ./configure --enable-gcc-wrapper --prefix="$PREFIX") && \
				make -C "$TEMPDIR/$NAME" && make -C "$TEMPDIR/$NAME" install
				;;
			ncurses )
				(cd "$TEMPDIR/$NAME" && ./configure --without-ada --without-cxx --without-progs --without-manpages --disable-db-install --without-tests --with-default-terminfo-dir=/usr/share/terminfo --with-terminfo-dirs="/etc/terminfo:/lib/terminfo:/usr/share/terminfo" --prefix="$PREFIX" CC="$MUSLCC") && \
				make -C "$TEMPDIR/$NAME" && make -C "$TEMPDIR/$NAME" install
				;;
			libevent )
				(cd "$TEMPDIR/$NAME" && ./configure --enable-static --enable-shared --disable-openssl --prefix="$PREFIX" CC="$MUSLCC") && \
				make -C "$TEMPDIR/$NAME" && make -C "$TEMPDIR/$NAME" install
				;;
			tmux )
				(cd "$TEMPDIR/$NAME" && ./configure --enable-static --prefix="$PREFIX" CC="$MUSLCC" CPPFLAGS="-I$TEMPDIR/libevent/$TMPINC -I$TEMPDIR/ncurses/$TMPINC -I$TEMPDIR/ncurses/$TMPINC/ncurses" LDFLAGS="-L$TEMPDIR/libevent/$TMPLIB -L$TEMPDIR/ncurses/$TMPLIB" LIBS=-lncurses) && \
				make -C "$TEMPDIR/$NAME" && make -C "$TEMPDIR/$NAME" install
				;;
		esac
	) 2>&1 |tee "$TEMPDIR/${NAME}.log" > /dev/null || { echo "FATAL: failed to build $NAME. Consult $TEMPDIR/${NAME}.log for details."; exit 1; }
	unset CC
done
