# Some build scripts

The build scripts in this directory aim to provide some extra value over the usual business of building the particular software in question. Only the ones for CMake and Ninja don't really do much in particular. However, they can still be used to get a tarball with the repo bundle and some such (use `--help`).

## Clang/LLVM

This one is dearest to me, but also the most complex and it's still growing in complexity and sheer size.

Its purpose is, obviously, to build a Clang/LLVM from the sources and it includes everything to build accompanying Binutils (although this is more of a relic, because LLD wasn't around when I originally started this script).

## musl libc

The musl libc is a C runtime library that will oftentimes be smaller than _dynamically_ linking to glibc, even if you link to musl libc statically.

Its main benefit is that it allows to create statically linked binaries for utilities, such that there is no need to take care of the compatibility with the system libraries. Basically the kernel ABI and the architecture are the only thing that could affect on how old a system you can run this.

## dropbear

Dropbear is an SSH server and client and so on and this script builds a statically linked `dropbearmulti` binary. This can act as standin for all the programs that normally encompass `dropbear`, much like those symlinks do with `busybox`.

## Rust CLI tools

Rust is an up and coming language which I am in the process of acquiring and these are some CLI tools I found useful. They are linked against the musl libc (via Rust's own toolchain/target mechanism) and most stand for themselves. However, I have noticed that some have _minor_ dependencies on the system and these are the ones listed in `warnings.txt` once the script was successful.
