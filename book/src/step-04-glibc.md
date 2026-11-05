# Step 4 — glibc (FHS layout, for the sysroot)

**File to write:** `lfs-toolchain/glibc/default.nix`, attribute `glibc`

LFS installs glibc into the shared `$LFS` directory. Nix store paths are
immutable, so you cannot install into one and add to it later. This step
builds glibc into its own path with an FHS layout (`/usr/lib`,
`/usr/include`). Step 5 merges it with the headers.

**Nix concepts for this step**

New in this step:

- **Platforms.** `stdenv.buildPlatform.config` is the triple of the machine
  that runs the build. stdenv adds `--build` and `--host` itself.
  `configurePlatforms = [ ];` stops that, and you give the flags.
  [More](appendix-nix-concepts.md#platforms-build-host-target).
- **`stdenv` and `stdenvNoCC`.** `stdenvNoCC` has no C compiler. glibc needs a
  build compiler for its helper programs, so use `stdenv`.
  [More](appendix-nix-concepts.md#stdenvmkderivation-and-phases).
- **The variables of stdenv.** stdenv exports `CC=gcc`, `AR=ar` and other tool
  variables for each build. They name the host tools. [More](appendix-nix-concepts.md#attributes-and-environment-variables).
- **`installFlags` and `placeholder "out"`.**
  `installFlags = [ "DESTDIR=${placeholder "out"}" ];` adds the flag to
  `make install` only. [More](appendix-nix-concepts.md#out-and-placeholder-out).
- **The fixup phase.** After the install, stdenv strips binaries, shrinks
  `RPATH` and rewrites `#!` lines. `dontStrip`, `dontPatchELF` and
  `dontPatchShebangs` turn each part off.
  [More](appendix-nix-concepts.md#the-fixup-phase-strip-patchelf-patchshebangs).
- **References in any byte.** The reference scan reads all bytes, also debug
  sections. A store path in debug info is a reference.
  [More](appendix-nix-concepts.md#references-and-closures).

From earlier steps: [`$out`](appendix-nix-concepts.md#out-and-placeholder-out) (step 1), [`nativeBuildInputs`](appendix-nix-concepts.md#nativebuildinputs-buildinputs-and-path) (step 1), [a package in a string](appendix-nix-concepts.md#nix-language) (step 2).

---

**Do:** write a derivation with these parts:

- The file is a function of
  `{ stdenv, fetchurl, bison, python3, perl, binutils, gccStage1, headers, triple }`.
  Add the attribute:
  `glibc = callPackage ./glibc { inherit triple binutils gccStage1 headers; };`.
- `pname = "lfs-glibc"`, version `2.40`, source
  `mirror://gnu/glibc/glibc-2.40.tar.xz`.
- `stdenv`, not `stdenvNoCC`. When `build` differs from `host`, glibc
  configure looks for a build compiler (`BUILD_CC`) for helper programs.
- `nativeBuildInputs = [ bison python3 perl ];`.
- `preConfigure`: put `${gccStage1}/tools/bin` and `${binutils}/tools/bin` on
  `PATH`, as in step 2. Then `mkdir build && cd build`, and
  `echo "rootsbindir=/usr/sbin" > configparms` (from LFS).
- Also in `preConfigure`, after the `PATH` line:

  ```sh
  unset CC CXX AR AS LD NM OBJCOPY OBJDUMP RANLIB READELF STRIP
  export CFLAGS="-g -O2 -fdebug-prefix-map=${gccStage1}=/gcc-stage1 -fdebug-prefix-map=${headers}=/linux-headers"
  ```

  `stdenv` exports `CC=gcc` (the host gcc), `AR=ar`, and the other tool
  variables. glibc configure uses these values before it looks for
  `aarch64-lfs-linux-gnu-*` on `PATH`. If you do not unset them, the host gcc
  builds glibc.

  `dontStrip` keeps the debug info. The `.debug_line_str` section records the
  include directories of gcc stage 1 and of the headers as store paths. Nix
  then finds them as references, and the closure gets gcc stage 1 and its host
  libraries. `-fdebug-prefix-map` replaces these paths with plain names. glibc
  does not build without optimisation, so `CFLAGS` must keep `-O2`.
- `configureScript = "../configure";`, `dontAddPrefix = true;`,
  `configurePlatforms = [ ];`.
- `configureFlags`:

  ```
  --prefix=/usr
  --host=${triple}
  --build=${stdenv.buildPlatform.config}
  --enable-kernel=4.19
  --with-headers=${headers}/usr/include
  --disable-nscd
  libc_cv_slibdir=/usr/lib
  ```

- `installFlags = [ "DESTDIR=${placeholder "out"}" ];`.
- `dontStrip = true; dontPatchELF = true;`. The fixup phase must not touch
  `ld.so` or `libc.so.6`.

**Verify:**

```console
$ nix build .#glibc -o result-glibc -L
$ L=$PWD/result-glibc/usr/lib
$ ls $L/{libc.so,libc.so.6,libc.a,ld-linux-aarch64.so.1,crt1.o,crti.o,crtn.o}
                                                  # all 7 exist
$ cat $L/libc.so                                  # GROUP ( /usr/lib/libc.so.6 /usr/lib/libc_nonshared.a AS_NEEDED ( /usr/lib/ld-linux-aarch64.so.1 ) )
$ $B/$T-readelf -h $L/libc.so.6 | grep Machine    # AArch64
$ $B/$T-readelf -p .comment $L/libc.so.6          # GCC: (GNU) 14.2.0  (your gcc stage 1)
$ $L/ld-linux-aarch64.so.1 --version | head -1    # ld.so (GNU libc) stable release version 2.40.
$ nix path-info -r ./result-glibc                 # see the note below
```

The `libc.so` check shows absolute paths under `/usr/lib`. The linker resolves
them inside the sysroot only when it finds the script inside the sysroot. Step 5
depends on this.

The loader check runs your `ld.so` directly. This works because the VM and the
target are both aarch64.

`nix path-info -r` can show a nixpkgs `bash`. `patchShebangs` rewrote
`#!/bin/bash` in `usr/bin/ldd` to a host store path. That is a host leak. Set
`dontPatchShebangs = true;` and check again: the closure is then glibc alone.

**If it fails:**

- `configure: error: ... C compiler cannot create executables`: `PATH` does
  not contain gcc stage 1. Check `preConfigure`.
- `makeinfo` missing: add `texinfo` to `nativeBuildInputs`.
- `zdump.c: error: standard 'reproducible' attribute can only be applied to
  function declarators`: the host gcc compiles glibc, not gcc stage 1. The
  command line starts with `gcc`, not `aarch64-lfs-linux-gnu-gcc`. Unset `CC`
  and the other tool variables in `preConfigure`.
- `nix path-info -r` shows `lfs-gcc-stage1`, `lfs-linux-headers`, or the host
  gcc: debug info holds their store paths. Check the `-fdebug-prefix-map` flags
  in `CFLAGS`. To find the section, run `readelf -p .debug_line_str` on
  `libc.so.6`.
