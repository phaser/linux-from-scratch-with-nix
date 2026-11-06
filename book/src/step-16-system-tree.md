# Step 16 — the system tree

**Files to write:** `lfs-distro/sysenv/`, `lfs-distro/etc/` and `lfs-distro/init/`,
each with a `default.nix`

**Nix concepts for this step**

New in this step:

- **`buildEnv` and priorities.** `buildEnv { name; paths; pathsToLink; }`
  makes a tree of symlinks from several packages. When two packages have the
  same file, the one with the higher priority wins. `lib.lowPrio` lowers the
  priority. [More](appendix-nix-concepts.md#buildenv-priorities).
- **`writeScript`.** `pkgs.writeScript "name" "text"` writes one executable
  file. [More](appendix-nix-concepts.md#trivial-builders-runcommand-buildenv-symlinkjoin).
- **The parts of a stdenv.** `lfsStdenvFinal.cc` is the wrapped gcc of the
  stdenv. [More](appendix-nix-concepts.md#stdenv-internals-setupsh-initialpath-cc-wrapper).

From earlier steps: [`runCommand`](appendix-nix-concepts.md#trivial-builders-runcommand-buildenv-symlinkjoin) (step 5), [multi-line strings](appendix-nix-concepts.md#nix-language) (step 3).

---

**Do:** write three derivations.

1. **`sysenv`** (`lfs-final-sysenv`): a `buildEnv` with
   `pathsToLink = [ "/bin" "/sbin" ];` and these paths:
   - the `lfs-final-*` GNU tools from step 11 (bash, coreutils, findutils,
     grep, sed, gawk, tar, gzip, xz, make, diffutils, patch);
   - `lfsStdenvFinal.cc` and `lfs-final-binutils` (for step 19);
   - `(lib.lowPrio busybox)`: busybox also has `ls`, `cat` and so on.
     `lowPrio` makes the GNU tools win each collision.

   `sysenv` is not a stdenv. A stdenv builds packages: it has `setup.sh`,
   the cc wrapper and `mkDerivation`. `sysenv` builds nothing. It is one
   directory with `bin/` and `sbin/`, and each file in it is a symlink to a
   program in one of your packages. Steps 17 and 18 use it as `/bin` and
   `/sbin` of the new system.

   `lfs-distro/sysenv/default.nix`:

   ```nix
   { lib, buildEnv, final, busybox, cc }:

   buildEnv {
     name = "lfs-final-sysenv";

     paths = with final; [
       # the GNU tools from step 11
       bash coreutils findutils gnugrep gnused gawk
       gnutar gzip xz gnumake diffutils gnupatch

       # a compiler and binutils, so that the system can build a program (step 19)
       cc          # lfsStdenvFinal.cc: the wrapped gcc
       binutils    # lfs-final-binutils

       # busybox also has ls, cat, awk, ...; lowPrio makes the GNU tools win
       (lib.lowPrio busybox)
     ];

     # link only bin/ and sbin/, not include/, share/, lib/ ...
     pathsToLink = [ "/bin" "/sbin" ];
   }
   ```

   In `lfs-distro/default.nix`, add the attribute after `busybox`:

   ```nix
   sysenv = pkgs.callPackage ./sysenv {
     inherit final busybox;
     cc = lfsStdenvFinal.cc;
   };
   ```

   - `callPackage` gives `lib` and `buildEnv` from `pkgs`. You give `final`,
     `busybox` and `cc`.
   - `busybox` is the attribute of step 15, because the set is `rec`.
   - Without `lowPrio`, the build stops at the first collision, for example
     `bin/ls` from coreutils and from busybox.
   - Only busybox has `sbin/init`, so that link goes to `busybox`.

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

   **Starting point.** `etc` is not a `mkDerivation`. `runCommand name env
   script` is a derivation with one shell script and no phases. The script
   must create `$out`. Here `$out` is a directory, and each file of the table
   is a file in it. `lfs-distro/etc/default.nix`:

   ```nix
   { runCommand }:

   runCommand "lfs-final-etc" { } ''
     mkdir -p $out
     echo 'root:x:0:0:root:/root:/bin/bash' > $out/passwd
     # ... the other files of the table
     cat > $out/rc <<'EOF'
     #!/bin/sh
     # ... the rc script above
     EOF
     chmod 0755 $out/rc
   ''
   ```

   In `lfs-distro/default.nix`: `etc = pkgs.callPackage ./etc { };`

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

   **Starting point.** `init` is not a `mkDerivation` either.
   `writeScript name text` is a derivation whose `$out` is one executable
   file, not a directory. `${final.bash}` puts the store path of your bash in
   the shebang. `lfs-distro/init/default.nix`:

   ```nix
   { writeScript, final }:

   writeScript "lfs-final-init" ''
     #!${final.bash}/bin/bash
     # ... the four lines above
   ''
   ```

   In `lfs-distro/default.nix`: `init = pkgs.callPackage ./init { inherit final; };`

In `flake.nix`, add the three attributes:
`inherit (distro) kernel busybox sysenv etc init;`

**Verify:**

```console
$ nix build .#sysenv -o result-sysenv
$ readlink -f result-sysenv/bin/ls                 # ...-lfs-final-coreutils-.../bin/ls (GNU wins)
$ readlink -f result-sysenv/sbin/init              # ...-lfs-final-busybox-.../bin/busybox
$ readlink -f result-sysenv/bin/gcc                # ...-gcc-wrapper-.../bin/gcc
$ nix build .#etc -o result-etc && cat result-etc/inittab
$ result-sysenv/bin/bash -n result-etc/rc && echo syntax ok    # syntax ok
```
