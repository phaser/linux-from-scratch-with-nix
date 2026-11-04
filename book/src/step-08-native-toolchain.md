# Step 8 — glibc for the store, native binutils, native gcc

**Files to write:** `lfs-temp/glibc/`, `lfs-temp/binutils/` and `lfs-temp/gcc/`,
each with a `default.nix`

Step 4's glibc uses `/usr/lib` paths, which only work through a sysroot. A Nix
stdenv has no sysroot: the cc-wrapper passes store paths to gcc. So you need a
second glibc with the Nix layout.

## 8a — `lfs-temp-glibc`

**Do:** copy your `lfs-toolchain/glibc/default.nix`, then change it:

- `pname = "lfs-temp-glibc"`. Use `stdenv.mkDerivation`, not `mkTemp`.
  `mkTemp` sets `LDFLAGS = "-static"`, and glibc must build shared libraries.
- Built by gcc stage 2. Replace `gccStage1` with `gccStage2` in the arguments,
  in `PATH`, and in the `-fdebug-prefix-map` flag.
- Keep the default `--prefix=$out`. Remove these lines from the copy:

  | Line | Where |
  |---|---|
  | `dontAddPrefix = true;` | top level |
  | `echo "rootsbindir=/usr/sbin" > configparms` | `preConfigure` |
  | `"--prefix=/usr"` | `configureFlags` |
  | `"libc_cv_slibdir=/usr/lib"` | `configureFlags` |
  | `installFlags = [ "DESTDIR=${placeholder "out"}" ];` | top level |
- In `postInstall`, copy the kernel headers into `$out/include`, without
  `scsi`. glibc installs its own `scsi` headers.

  ```nix
  postInstall = ''
    for d in ${headers}/usr/include/*; do
      [ "$(basename $d)" = scsi ] || cp -r $d $out/include/
    done
  '';
  ```

  nixpkgs glibc makes symlinks (`ln -s`), not copies
  (`pkgs/development/libraries/glibc/default.nix`). There, the headers go in
  the separate `dev` output. This derivation has only one output. A symlink is a
  store path reference, so the closure then gets the headers too.
- `dontStrip`, `dontPatchELF`, `dontPatchShebangs`.

Then add the attribute to `lfs-temp/default.nix`. glibc needs other toolchain
arguments than the tools of step 7, so do not use `call`:

```nix
glibc = pkgs.callPackage ./glibc {
    inherit (toolchain) triple binutils gccStage2 headers;
};
```

Do not add `glibc` to `tools`. Step 9 uses `temp.glibc` directly.

A flake sees only the files that git tracks. Before the first build, run
`git add lfs-temp/glibc`. If you do not, `nix build` cannot find the file.

**Verify:**

```console
$ nix build .#temp.glibc -o result-temp-glibc -L
$ cat result-temp-glibc/lib/libc.so                # GROUP ( /nix/store/...-lfs-temp-glibc-2.40/lib/libc.so.6 ... )
$ result-temp-glibc/lib/ld-linux-aarch64.so.1 --version | head -1    # ... version 2.40.
$ ls result-temp-glibc/include/{stdio.h,linux/types.h}               # both exist
$ nix path-info -r ./result-temp-glibc             # ONE line
```

Compare the `libc.so` output with step 4: store paths instead of `/usr/lib`.
This is the Nix answer to the old LFS "adjusting the toolchain" chapter.

## 8b — `lfs-temp-binutils` (native)

**Do:** `--host=${triple} --target=${triple}`, static (the helper from step 7),
plus `--disable-plugins --disable-gprofng`. A static `ld` cannot load plugins.

**Verify:**

```console
$ ls result-temp-binutils/bin                      # ld, as, ar ... WITHOUT the triple prefix (host = target)
$ file result-temp-binutils/bin/ld                 # statically linked
$ result-temp-binutils/bin/ld --verbose | grep SEARCH_DIR
                                                   # /usr/lib and /lib appear: a native ld searches them
```

The last check matters. Inside the sandbox those directories do not exist. In
`nix develop` on the VM they do. The cc-wrapper and the bintools-wrapper hide
them in step 9.

## 8c — `lfs-temp-gcc` (native)

**Do:**

- `--host=${triple} --target=${triple}`, static.
- Unpack the gmp, mpfr and mpc sources into the gcc source tree, as LFS does.
  Do not use the nixpkgs copies: those were built by the host.
- `--enable-languages=c,c++ --disable-multilib --disable-bootstrap`
  `--disable-lto --disable-plugin --disable-libsanitizer`.
- Apply the nixpkgs patch `pkgs/development/compilers/gcc/patches/gcc-12-no-sys-dirs.patch`.
  It stops gcc searching `/usr/include` and `/usr/lib`.

**Verify:**

```console
$ nix build .#temp.gcc -o result-temp-gcc -L
$ result-temp-gcc/bin/gcc -v 2>&1 | grep -E '^(Target|Configured)'
                                                   # Target: aarch64-lfs-linux-gnu, --host=aarch64-lfs-linux-gnu
$ file result-temp-gcc/bin/gcc $(result-temp-gcc/bin/gcc -print-prog-name=cc1)
                                                   # both statically linked
$ echo | result-temp-gcc/bin/gcc -E -v - 2>&1 | sed -n '/search starts/,/End of search/p'
                                                   # no /usr/include (the patch works)
```

**Nix concepts:** [multiple outputs](appendix-nix-concepts.md#multiple-outputs-libgetdev-libgetlib),
[patches](appendix-nix-concepts.md#stdenvmkderivation-and-phases).
