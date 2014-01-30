#!/usr/bin/env bash
WKPKG=redhat-lsb
WKDIR=$HOME/$WKPKG
[[ -d "$WKDIR" ]] && [[ "x$1" != "x-f" ]] && { echo "ERROR: not removing $WKDIR. Use -f to force it."; exit 1; }
(
	[[ -d "$WKDIR" ]] &&  rm -rf "$WKDIR"
	mkdir "$WKDIR" && \
		cd "$WKDIR" && \
		yumdownloader $WKPKG && \
		cd / && \
		rpm2cpio "$WKDIR"/redhat-lsb-*.$(uname -m).rpm | cpio -idmv
)
