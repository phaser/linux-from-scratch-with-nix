# Step 8 — glibc for the store, native binutils, native gcc

**Files to write:** `lfs-temp/glibc/`, `lfs-temp/binutils/` and `lfs-temp/gcc/`,
each with a `default.nix`

Step 4's glibc uses `/usr/lib` paths, which only work through a sysroot. A Nix
stdenv has no sysroot: the cc-wrapper passes store paths to gcc. So you need a
second glibc with the Nix layout.

## 8a — `lfs-temp-glibc`

**Do:** as in step 4, but:

- Built by gcc stage 2 (`PATH` to `${gccStage2}/tools/bin`).
- Keep the default `--prefix=$out`. Remove `libc_cv_slibdir`, `DESTDIR` and
  `rootsbindir`.
- In `postInstall`, link the kernel headers into `$out/include`, without
  `scsi`. nixpkgs glibc does the same (`pkgs/development/libraries/glibc/default.nix`).
- `dontStrip`, `dontPatchELF`, `dontPatchShebangs`.

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
