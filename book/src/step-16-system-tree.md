# Step 16 — the system tree

**Files to write:** `lfs-distro/sysenv/`, `lfs-distro/etc/` and `lfs-distro/init/`,
each with a `default.nix`

**Do:** write three derivations.

1. **`sysenv`** (`lfs-final-sysenv`): a `buildEnv` with
   `pathsToLink = [ "/bin" "/sbin" ];` and these paths:
   - the `lfs-final-*` GNU tools from step 11 (bash, coreutils, findutils,
     grep, sed, gawk, tar, gzip, xz, make, diffutils, patch);
   - `lfsStdenvFinal.cc` and `lfs-final-binutils` (for step 19);
   - `(lib.lowPrio busybox)`: busybox also has `ls`, `cat` and so on.
     `lowPrio` makes the GNU tools win each collision.

2. **`etc`** (`lfs-final-etc`): a `runCommand` that writes:

   | File | Content |
   |---|---|
   | `passwd` | `root:x:0:0:root:/root:/bin/bash` |
   | `group` | `root:x:0:` |
   | `hostname` | `lfs` |
   | `profile` | `export PATH=/bin:/sbin` and `PS1='\u@\h:\w\$ '` |
   | `inittab` | see below |
   | `rc` (mode 0755) | see below |

   `inittab`:

   ```
   ::sysinit:/etc/rc
   ttyAMA0::respawn:-/bin/bash -l
   ::ctrlaltdel:/sbin/reboot
   ::shutdown:/bin/umount -a -r
   ```

   `rc`:

   ```sh
   #!/bin/sh
   mkdir -p /proc /sys /dev /tmp /root
   mountpoint -q /proc || mount -t proc proc /proc
   mountpoint -q /sys  || mount -t sysfs sysfs /sys
   mountpoint -q /dev  || mount -t devtmpfs devtmpfs /dev
   hostname -F /etc/hostname
   echo "lfs: rc done"
   ```

   The `-` in `-/bin/bash` makes it a login shell. The `ttyAMA0` field gives
   it a controlling terminal, so job control works.

3. **`init`** (`lfs-final-init`), for the initramfs only. Use
   `pkgs.writeScript`, with the shebang `#!${final.bash}/bin/bash`:

   ```sh
   mkdir -p /dev
   mount -t devtmpfs devtmpfs /dev
   exec </dev/console >/dev/console 2>&1
   exec /sbin/init
   ```

   In an initramfs, the kernel does not mount `/dev` for you. Without a console,
   busybox init has no output.

**Verify:**

```console
$ nix build .#sysenv -o result-sysenv
$ readlink -f result-sysenv/bin/ls                 # ...-lfs-final-coreutils-.../bin/ls (GNU wins)
$ readlink -f result-sysenv/sbin/init              # ...-lfs-final-busybox-.../bin/busybox
$ readlink -f result-sysenv/bin/gcc                # ...-gcc-wrapper-.../bin/gcc
$ nix build .#etc -o result-etc && cat result-etc/inittab
$ result-sysenv/bin/bash -n result-etc/rc && echo syntax ok    # syntax ok
```

**Nix concepts:** [trivial builders](appendix-nix-concepts.md#trivial-builders-runcommand-buildenv-symlinkjoin),
[`buildEnv` priorities](appendix-nix-concepts.md#buildenv-priorities).
