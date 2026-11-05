# Step 5 — the sysroot

**File to write:** `lfs-toolchain/sysroot/default.nix`, attribute `sysroot`

The sysroot is the `$LFS` directory of the original recipe, made explicit:
headers and glibc in one tree.

**Nix concepts for this step**

New in this step:

- **The store is read-only.** You cannot add files to the glibc path of step 4.
  You make a new path. Files copied from the store keep their read-only mode, so
  the script runs `chmod -R u+w`. [More](appendix-nix-concepts.md#the-store).
- **Trivial builders.** `runCommand "name" { } '' script ''` runs one shell
  script, and the script writes `$out`. `buildEnv` and `symlinkJoin` make a tree
  of symlinks. [More](appendix-nix-concepts.md#trivial-builders-runcommand-buildenv-symlinkjoin).

From earlier steps: [multi-line strings](appendix-nix-concepts.md#nix-language) (step 3), [a package in a string](appendix-nix-concepts.md#nix-language) (step 2).

---

**Do:** use `runCommand` and **copy** the files. Do not use `buildEnv` or
`symlinkJoin`.

```nix
{ runCommand, headers, glibc }:

runCommand "lfs-sysroot" { } ''
  mkdir -p $out
  cp -r ${headers}/. $out/
  chmod -R u+w $out
  cp -r ${glibc}/. $out/
''
```

Why copy: `ld` decides whether a linker script such as `libc.so` is inside the
sysroot with `realpath`. A `buildEnv` file is a symlink, its real path is in
the glibc store path, and `ld` then looks for `/usr/lib/libc.so.6` on the
*host*. (An earlier version of this guide suggested `buildEnv`. That was
wrong.)

**Verify:**

```console
$ nix build .#sysroot -o result-sysroot
$ S=$(readlink -f result-sysroot)
$ find $S -type l | wc -l                         # small: only glibc's own symlinks
$ [ "$(readlink -f $S/usr/lib/libc.so)" = "$S/usr/lib/libc.so" ] && echo ok    # ok
$ ls $S/usr/include/{stdio.h,linux/types.h}      # both exist
```
