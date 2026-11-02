# Step 5 — the sysroot

**File to write:** `lfs-toolchain/sysroot/default.nix`, attribute `sysroot`

The sysroot is the `$LFS` directory of the original recipe, made explicit:
headers and glibc in one tree.

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

**Nix concepts:** [trivial builders](appendix-nix-concepts.md#trivial-builders-runcommand-buildenv-symlinkjoin),
[immutability of the store](appendix-nix-concepts.md#the-store).
