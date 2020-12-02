# CSL clone fixups

## `fix-scripts.sh`

This script contains a lengthy `sed` command to replace several remnants from the build performed by Code Mentor as well as an AWK (specifically `mawk`!) script which mutates the build script to bring it into a shape that is easier to handle for humans 😉

## Actual source code and binary toolchains

This repository contains only the cryptographic hashes for the tarballs (and re-packaged tarballs) with the Code Bench Lite sources and the binary tarballs.

* `arm-*-arm-none-linux-gnueabi-i686-pc-linux-gnu.tar.bz2`  
  These are the pristine **binary** packages as downloaded from Code Mentor (the caveat being that these require a 32-bit runtime to work on a modern x86-64 Linux):
  * [`arm-2012.03-57-arm-none-linux-gnueabi-i686-pc-linux-gnu.tar.bz2`](https://sourcery.mentor.com/public/gnu_toolchain/arm-none-linux-gnueabi/arm-2012.03-57-arm-none-linux-gnueabi-i686-pc-linux-gnu.tar.bz2)
  * [`arm-2012.09-64-arm-none-linux-gnueabi-i686-pc-linux-gnu.tar.bz2`](https://sourcery.mentor.com/public/gnu_toolchain/arm-none-linux-gnueabi/arm-2012.09-64-arm-none-linux-gnueabi-i686-pc-linux-gnu.tar.bz2)
  * [`arm-2013.05-24-arm-none-linux-gnueabi-i686-pc-linux-gnu.tar.bz2`](https://sourcery.mentor.com/public/gnu_toolchain/arm-none-linux-gnueabi/arm-2013.05-24-arm-none-linux-gnueabi-i686-pc-linux-gnu.tar.bz2)
  * [`arm-2013.11-33-arm-none-linux-gnueabi-i686-pc-linux-gnu.tar.bz2`](https://sourcery.mentor.com/public/gnu_toolchain/arm-none-linux-gnueabi/arm-2013.11-33-arm-none-linux-gnueabi-i686-pc-linux-gnu.tar.bz2)
  * [`arm-2014.05-29-arm-none-linux-gnueabi-i686-pc-linux-gnu.tar.bz2`](https://sourcery.mentor.com/public/gnu_toolchain/arm-none-linux-gnueabi/arm-2014.05-29-arm-none-linux-gnueabi-i686-pc-linux-gnu.tar.bz2)
* `arm-*-arm-none-linux-gnueabi.src.tar.bz2`  
  These are the pristine **source** packages downloaded from Code Mentor:
  * [`arm-2012.03-57-arm-none-linux-gnueabi.src.tar.bz2`](https://sourcery.mentor.com/public/gnu_toolchain/arm-none-linux-gnueabi/arm-2012.03-57-arm-none-linux-gnueabi.src.tar.bz2)
  * [`arm-2012.09-64-arm-none-linux-gnueabi.src.tar.bz2`](https://sourcery.mentor.com/public/gnu_toolchain/arm-none-linux-gnueabi/arm-2012.09-64-arm-none-linux-gnueabi.src.tar.bz2)
  * [`arm-2013.05-24-arm-none-linux-gnueabi.src.tar.bz2`](https://sourcery.mentor.com/public/gnu_toolchain/arm-none-linux-gnueabi/arm-2013.05-24-arm-none-linux-gnueabi.src.tar.bz2)
  * [`arm-2013.11-33-arm-none-linux-gnueabi.src.tar.bz2`](https://sourcery.mentor.com/public/gnu_toolchain/arm-none-linux-gnueabi/arm-2013.11-33-arm-none-linux-gnueabi.src.tar.bz2)
  * [`arm-2014.05-29-arm-none-linux-gnueabi.src.tar.bz2`](https://sourcery.mentor.com/public/gnu_toolchain/arm-none-linux-gnueabi/arm-2014.05-29-arm-none-linux-gnueabi.src.tar.bz2)
