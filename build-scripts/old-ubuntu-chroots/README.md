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
