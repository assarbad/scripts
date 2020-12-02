# The helper scripts

There are two helper scripts here:

```
.
└── bin
    ├── enter-proot
    └── prepare-clang-build.sh
```

As the name suggests `enter-proot` will let you enter the chroot environment using `proot`.

This script, will also "bind-mount" (see: `man proot`) the `bin` and `src` subdirectories into `/root` inside the chroot.

This also means in order to run the `bin/prepare-clang-build.sh` script _inside_ the chroot you could run:

```
bin/enter-proot /usr/bin/env NOINSTALL=1 /root/bin/prepare-clang-build.sh
```

In this case setting `NOINSTALL` to a non-empty value will skip updating the package cache and installing a few basic packages that would normally be required to build either Clang/LLVM or Binutils or both.

# Version-specific hints

## Ubuntu 10.04 (Lucid)

Given the cloud image (which only really came as image, not as tarball) I mounted (`kpartx -a`) and extracted the whole rootfs. Extracting that into a subfolder `rootfs`. The outcome of which was a compressed tarball `ubuntu-10.04-server-cloudimg-amd64.rootfs.txz` and an accompanying `.SHA256SUM`. All subsequent work was based on that.

The next step was to develop and use `reinit-lucid.sh` which would take that tarball, unpack it and then use `proot` via `bin/enter-proot` to prepare and clean that rootfs. In particular packages like `build-essential` get installed.

I then manually added `automake` 1.16 and `autoconf` 2.69. The latter was required when I attempted to rebuild CodeBench Lite 2012.03. The outcome is roughly 600 MiB uncompressed and 140 MiB when compressed with `xz` (a Git bundle comes in at approximately 200 MiB).

**NB:** this will show some "scary" warnings which you should heed on real hardware, but for our purpose we can simply confirm we _really_ want to remove all that stuff. This saved me more than 150 MiB overall. With `xz -9e` I am getting down to ~80 MiB.
