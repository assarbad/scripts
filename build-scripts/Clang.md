# Clang/LLVM

## Researching toward a standalone Clang/LLVM toolchain

The goal would be to build a Clang/LLVM toolchain (>= 9.x) which does not depend on `libstdc++` and depends only on older versions of the glibc and can otherwise stand by itself. Alternatively (but not yet sure if this is at all possible), I would like to make it build against musl-libc (and while at it, I'd also like to include the respective musl-libc libraries in the toolchain for the targets).

* In the Clang source one can find:
    * `clang/cmake/caches/Fuchsia-stage2.cmake` and `clang/cmake/caches/Fuchsia.cmake`
    * ... similarly for Android and for building a toolchain targeting Linux from Windows
* [Options mentioned for building Fuchsia](https://fuchsia.dev/fuchsia-src/development/build/toolchain) also tend to be helpful

## Non-default choices for Clang

* Compiler runtime: `--rtlib=compiler-rt` vs. `--rtlib=libgcc`
* C++ runtime library: `--stdlib=libc++` vs. `--stdlib=libstdc++`
* Linker: `-fuse-ld=lld`, `-fuse-ld=bfd`, `-fuse-ld=gold`
* C library affects target triple (e.g. musl-libc)

## How the components correspond to GCC with Binutils:

| **Component**  | **Clang/LLVM**            | **GCC with Binutils**    |
|----------------|---------------------------|--------------------------|
| C/C++ compiler | `clang` / `clang++`       | `gcc` / `g++`            |
| Assembler      | (integrated)              | `as`                     |
| Linker         | `ld.lld`                  | `ld.bfd`, `ld.gold`      |
| Runtime        | `compiler-rt`             | `libgcc`                 |
| Unwinder       | `libunwind`               | `libgcc_s`               |
| C++ runtime    | `libc++abi`, `libc++`     | `libsupc++`, `libstdc++` |
| Utilities      | `llvm-ar`, `llvm-objdump` | `ar`, `objdump`          |
| C runtime      | `libc`                    | `glibc`                  |

## Further reading

* [How to cross compile with LLVM based tools](https://archive.fosdem.org/2018/schedule/event/crosscompile/attachments/slides/2107/export/events/attachments/crosscompile/slides/2107/How_to_cross_compile_with_LLVM_based_tools.pdf)
* Official Clang/LLVM documentation (and resources):
    * [How To Cross-Compile Clang/LLVM using Clang/LLVM](https://llvm.org/docs/HowToCrossCompileLLVM.html)
    * [The Clang Universal Driver Project](https://clang.llvm.org/UniversalDriver.html)
    * [Advanced Build Configurations](https://llvm.org/docs/AdvancedBuilds.html) (seemingly somewhat dated)
        * [related mailing list thread](https://lists.llvm.org/pipermail/llvm-dev/2019-January/128866.html)
* Linux from Scratch:
    * [Re-adjusting the Toolchain](http://www.linuxfromscratch.org/lfs/view/6.8/chapter06/readjusting.html)
    * [Building LLVM](http://www.linuxfromscratch.org/blfs/view/svn/general/llvm.html)
* [Building LLVM](https://wiki.musl-libc.org/building-llvm.html) (musl Wiki, somewhat dated)
    * Losely related: [Alternatives to "canonical" programs and libraries](https://wiki.musl-libc.org/alternatives.html)
* [How to build LLVM from source, monorepo version](https://quuxplusone.github.io/blog/2019/11/09/llvm-from-scratch/) (macOS only?)
* [Clang](https://wiki.gentoo.org/wiki/Clang) on the Gentoo Wiki
* [BobSteagall/clang-builder](https://github.com/BobSteagall/clang-builder)
* [Bootstrapping Clang on Linux](https://web.archive.org/web/20180925002851/http://www.omniprog.info/clang_bootstrap.html)
* [How to Use Clang without GCC on Linux](https://web.archive.org/web/20181014103429/http://www.omniprog.info/clang_no_gcc.html)
* [Compiling Clang from Scratch](https://shaharmike.com/cpp/build-clang/)
* [Cling-related forum topic](https://root-forum.cern.ch/t/building-root-with-clang-libc-on-ubuntu/32972/2) ... (yeah, [Cling is actually a thing](https://github.com/root-project/cling))
* [Comparison of Clang/LLVM and GCC](https://alibabatech.medium.com/gcc-vs-clang-llvm-an-in-depth-comparison-of-c-c-compilers-899ede2be378)
