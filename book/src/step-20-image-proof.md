# Step 20 — the proof for the image

Run these checks in the VM, not in the guest.

```console
# 1. The closure of everything in the image: only your packages and their wrappers.
$ nix path-info -r ./result-sysenv ./result-etc | grep -v -E -- '-lfs-final-|-(gcc|bintools)-wrapper-|-lfs-stdenv'
                                                   # no output, or only setup-hook files

# 2. Exactly one glibc, and it is yours.
$ nix path-info -r ./result-sysenv | grep -E -- '-glibc-[0-9]'
                                                   # only ...-lfs-final-glibc-2.40

# 3. Every ELF file in the image was built by your gcc.
$ nix path-info -r ./result-sysenv \
    | xargs -I{} find {} -type f \
    | xargs $B/$T-readelf -p .comment 2>/dev/null \
    | grep -o 'GCC: ([^)]*) [0-9.]*' | sort | uniq -c
                                                   # only "GCC: (GCC) 14.2.0" (16.2.0 would be nixpkgs)

# 4. The kernel too.
$ grep CONFIG_CC_VERSION_TEXT result-kernel/config # 14.2.0
```

The limits of this proof: the image *builders* (mkfs, cpio, gzip) and QEMU come
from nixpkgs. They shape the bytes of the image file but add no program to it.

**Out of scope here, and the next steps if you want them:** networking
(`-nic user` in QEMU, `udhcpc` from busybox), users and `login`, a bootloader
for real hardware (QEMU's `-kernel` skips it), and a package manager in the
guest.
