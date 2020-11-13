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

Given the cloud image (which only really came as image, not as tarball) I mounted (`kpartx -a`) and extracted the whole rootfs. Extracting that into a subfolder `rootfs` I then used `bin/enter-proot`.

On the root shell I executed a helper script (`bin/clean-lucid-10.04.sh`) which removes some non-essential stuff from the rootfs (after all we're running on hardware, but that doesn't matter inside an unprivileged chroot environment).

**NB:** this will show some "scary" warnings which you should heed on real hardware, but for our purpose we can simply confirm we _really_ want to remove all that stuff. This saved me more than 150 MiB overall.
