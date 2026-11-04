# Step 8 — glibc for the store, native binutils, native gcc

**Files to write:** `lfs-temp/glibc/`, `lfs-temp/binutils/` and `lfs-temp/gcc/`,
each with a `default.nix`

## What this step makes, and why

Step 9 makes a Nix stdenv from your own tools. A stdenv needs a libc, binutils
and a C compiler, and all three must run on the target. The toolchain of steps
1 to 6 does not have them:

| Package | Step | Host (where it runs) | Target | Problem for step 9 |
|---|---|---|---|---|
| glibc | 4 | `aarch64-lfs-linux-gnu` | — | It uses `/usr/lib` paths, which work only in a sysroot. |
| binutils | 1 | `aarch64-unknown-linux-gnu` | `aarch64-lfs-linux-gnu` | It runs on the nixpkgs platform and uses the nixpkgs glibc. |
| gcc stage 2 | 6 | `aarch64-unknown-linux-gnu` | `aarch64-lfs-linux-gnu` | It runs on the nixpkgs platform, uses the nixpkgs gmp, mpfr and mpc, and finds glibc through `--with-sysroot`. |

`aarch64-unknown-linux-gnu` is the nixpkgs platform, and the host gcc 16
builds for it. Step 8 builds the three packages again, with
host = target = `aarch64-lfs-linux-gnu`. The step 1 and step 6 tools compile
them, as in step 7. At run time, the results use no nixpkgs package.

| Result | build | host | target |
|---|---|---|---|
| gcc stage 2 (step 6) | `unknown` | `unknown` | `lfs` |
| `lfs-temp-gcc` (8c) | `unknown` | `lfs` | `lfs` |

When host = target, the tool is a native tool. A native tool behaves
differently from a cross tool:

- The programs have no triple prefix: `bin/ld`, not `bin/aarch64-lfs-linux-gnu-ld`.
- It has no sysroot. It searches the system directories (`/usr/include`,
  `/lib`, `/usr/lib`). In Nix, these directories must point to store paths.

These two points are why you cannot copy the step 1 or step 6 file. 8b and 8c
show each line that changes, and the reason.

Do not change the build platform: `mkTemp` keeps `--build` at the nixpkgs
platform. Some programs run during the build (for example, gcc's `genmodes`).
These programs are compiled by the host gcc 16, not by gcc stage 2.

## 8a — `lfs-temp-glibc`

**Goal:** a glibc with store paths. A Nix stdenv has no sysroot: the
cc-wrapper gives gcc the store paths of glibc. The step 4 glibc has `/usr/lib`
paths, so it cannot work there.

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

**Goal:** `ld`, `as`, `ar` and the other tools, as static programs that run on
the target. In step 9, the bintools-wrapper wraps them.

**Do:** copy your `lfs-toolchain/binutils/default.nix`, then change it as this
table shows:

| Step 1 file | 8b file | Why |
|---|---|---|
| `stdenv.mkDerivation` | `mkTemp`, `pname = "binutils"` | `mkTemp` gives `--host=${triple}`, the cross tools on `PATH`, and `-static`. Without `--host`, the host gcc 16 builds a second copy of step 1. |
| `--target=${triple}` | keep it | With `--host` the same, the tools are native, without a triple prefix. |
| `--prefix=$out/tools`, `dontAddPrefix` | remove both | The bintools-wrapper expects `$out/bin/ld`. The `/tools` prefix kept the cross tools apart from the target files. |
| — | `--disable-shared` | No `libbfd.so`. The programs link `libbfd.a` into themselves. |
| — | `--disable-plugins --disable-gprofng` | A static `ld` cannot load plugins, and gprofng needs shared libraries. |
| — | `preBuild` and `makeFlags`, see below | `-static` alone gives dynamic programs. |

**libtool and `-static`.** binutils links its programs with libtool. libtool
reads `-static` in `LDFLAGS` as "use no shared libtool libraries", and it does
not give the flag to gcc. The programs are then dynamic, with the interpreter
`/lib/ld-linux-aarch64.so.1` from the sysroot. That path does not exist in the
store. The libtool flag for a static program is `-all-static`. gcc does not
know this flag, so a configure script with it fails. The top-level `make`
configures each subdirectory, so configure them all before the build:

```nix
preBuild = "make configure-host";
makeFlags = [ "LDFLAGS=-all-static" ];
```

The step 7 tools do not use libtool, so `-static` was sufficient there.

Add the attribute: `binutils = pkgs.callPackage ./binutils { inherit mkTemp; inherit (toolchain) triple; };`.

**Verify:**

```console
$ nix build .#temp.binutils -o result-temp-binutils -L
$ ls result-temp-binutils/bin                      # ld, as, ar ... WITHOUT the triple prefix (host = target)
$ file result-temp-binutils/bin/ld                 # statically linked
$ nix path-info -r ./result-temp-binutils          # ONE line
$ result-temp-binutils/bin/ld --verbose | grep SEARCH_DIR
                                                   # /usr/lib and /lib appear: a native ld searches them
```

The `SEARCH_DIR` check matters. Inside the sandbox those directories do not
exist. In `nix develop` on a normal Linux system they do. The cc-wrapper and
the bintools-wrapper hide them in step 9.

**If it fails:**

- `file` shows `dynamically linked, interpreter /lib/ld-linux-aarch64.so.1`:
  `makeFlags` does not have `-all-static`.
- `configure: error: C compiler cannot create executables` in a subdirectory:
  `-all-static` reached a configure script. Check `preBuild`.

## 8c — `lfs-temp-gcc` (native)

**Goal:** a static gcc that runs on the target and compiles for it. In step 9,
the cc-wrapper wraps it, and it compiles every package after that.

**Do:** copy your `lfs-toolchain/gcc-stage2/default.nix`, then change it as
this table shows:

| Stage 2 file | 8c file | Why |
|---|---|---|
| `stdenv.mkDerivation` | `mkTemp`, `pname = "gcc"` | `mkTemp` gives `--host=${triple}`, gcc stage 2 and the step 1 binutils on `PATH`, and `-static`. gcc stage 2 then compiles this gcc. Without `--host`, the host gcc 16 builds a second cross compiler. |
| `--target=${triple}` | keep it | With `--host` the same, gcc is native. |
| `--prefix=$out/tools`, `dontAddPrefix` | remove both | The cc-wrapper expects `$out/bin/gcc`. |
| `--with-as`, `--with-ld` | remove both | They store the step 1 binutils paths in gcc. Those programs run on the nixpkgs platform. In step 9, the bintools-wrapper gives `as` and `ld`. |
| `--with-sysroot=${sysroot}` | remove it, and the `sysroot` argument | A native gcc has no sysroot. With one, gcc looks for headers in `${sysroot}${glibc}/include`, which does not exist. |
| `--with-native-system-header-dir=/usr/include` | `=${glibc}/include`, and a `glibc` argument | See "Patch gcc", item 4. |
| `buildInputs` gmp, mpfr, libmpc, isl, and the eight `--with-gmp...` flags | the gmp, mpfr and mpc sources in the gcc tree | See "Libraries in the gcc tree". |
| `export CXX="g++ -std=gnu++17"` | `export CXX_FOR_BUILD="g++ -std=gnu++17"` | gcc stage 2 (gcc 14) compiles gcc now. Only the programs that run during the build use the host g++ 16. |
| — | `export LDFLAGS_FOR_BUILD=` | `LDFLAGS_FOR_BUILD` defaults to `LDFLAGS`, which is `-static`. The nixpkgs glibc in stdenv has no `libc.a`, so the build programs cannot link. An empty value stops the default. |
| — | `--disable-lto --disable-plugin --disable-libsanitizer` | A static gcc cannot load plugins, and LTO needs the linker plugin. The temp tools do not need the sanitizers. |
| — | `patches` | See "Patch gcc". |
| — | `postInstall` | See "`limits.h`". |
| `hardeningDisable = [ "format" ]` | keep it | It applies to the host-built programs. |

Add the attribute. It is in the same `rec` set as `glibc`:

```nix
gcc = pkgs.callPackage ./gcc { inherit mkTemp glibc; inherit (toolchain) triple; };
```

### Libraries in the gcc tree

gcc needs gmp, mpfr and mpc. Stage 2 used the nixpkgs packages. Those are
built for the nixpkgs platform, and a static gcc for the target cannot link
them. If gcc finds the sources in `gmp/`, `mpfr/` and `mpc/` in its source
tree, it builds them first, with gcc stage 2. LFS chapter 6 does the same.

```nix
let
  gmp  = fetchurl { url = "mirror://gnu/gmp/gmp-6.3.0.tar.bz2";
                    hash = "sha256-rCghGnz7YJuuLiyNYFjWbI/pZDT3QM9v4uR7AA0cIMs="; };
  mpfr = fetchurl { url = "mirror://gnu/mpfr/mpfr-4.2.2.tar.xz";
                    hash = "sha256-tnugOD736KhWNzTi6InvXsPDuJigHQD6CmhprYHGzgE="; };
  mpc  = fetchurl { url = "mirror://gnu/mpc/mpc-1.4.1.tar.xz";
                    hash = "sha256-kSBM0y8WS9O3yZLUpqjOZRlRGq2rMPeLaYLQv41z6TE="; };
in
mkTemp rec {
  # ...
  postUnpack = ''
    tar -xf ${gmp}  -C $sourceRoot && mv $sourceRoot/gmp-*  $sourceRoot/gmp
    tar -xf ${mpfr} -C $sourceRoot && mv $sourceRoot/mpfr-* $sourceRoot/mpfr
    tar -xf ${mpc}  -C $sourceRoot && mv $sourceRoot/mpc-*  $sourceRoot/mpc
  '';
}
```

`postUnpack` runs after the gcc source is unpacked, in the directory above it.
`$sourceRoot` is the name of the gcc directory. These versions are the ones in
the pinned nixpkgs, so the binary cache has the files. LFS 12.2 uses mpfr 4.2.1
and mpc 1.3.1. isl is optional, and LFS does not use it.

### `limits.h`

gcc installs its own `limits.h`. When gcc finds the glibc `limits.h` at build
time, its copy includes the glibc copy. Without that, values such as
`PATH_MAX` are missing. gcc looks for it in `BUILD_SYSTEM_HEADER_DIR`. When
build ≠ host and there is no `--with-build-sysroot`, that is
`$out/aarch64-lfs-linux-gnu/sys-include`, which does not exist.

LFS chapter 6 uses `--with-build-sysroot=$LFS`. That does not work here:
configure puts the value in front of the header directory, and
`${sysroot}${glibc}/include` does not exist. Write the full `limits.h` after
the install, as LFS chapter 5 does:

```nix
postInstall = ''
  cat ../gcc/limitx.h ../gcc/glimits.h ../gcc/limity.h \
    > $out/lib/gcc/${triple}/${version}/include/limits.h
  rm -r $out/libexec/gcc/${triple}/${version}/install-tools
'';
```

The `rm` line removes `fixincl` and `mkheaders`. These programs run
fixincludes again after the install. They store the paths of the host `sh` and
`sed`, so without the `rm` line the closure gets the nixpkgs bash, sed and
glibc. nixpkgs gcc also removes this directory.

### Patch gcc

This is the first patch in the book. A patch is a diff file. The
`patchPhase` of stdenv runs after `unpackPhase` and before `configurePhase`.
It applies each file in the `patches` list with `patch -p1`. `-p1` removes the
first directory (`a/` or `b/`) from each file name in the diff.

**Why this gcc needs it.** gcc stage 1 and stage 2 are cross compilers
(host ≠ target), and they use a sysroot. A cross compiler does not search
`/usr/local/include`, `/lib` or `/usr/lib`. This gcc has host = target, so it
is a native compiler, and it searches all of them. In the Nix sandbox these
directories do not exist. In `nix develop` on a normal Linux system they do,
and gcc then finds the host libraries.

1. Copy the patch from the nixpkgs revision in your `flake.lock`:

   ```console
   $ NP=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.nixpkgs.outPath')
   $ cp $NP/pkgs/development/compilers/gcc/patches/gcc-12-no-sys-dirs.patch lfs-temp/gcc/no-sys-dirs.patch
   $ git add lfs-temp/gcc/no-sys-dirs.patch
   ```

   A copy in your tree does not change when you update nixpkgs. You can also
   use the nixpkgs file directly: add `path` to the arguments, then write
   `"${path}/pkgs/development/compilers/gcc/patches/gcc-12-no-sys-dirs.patch"`.
   `callPackage` gives `path`, the nixpkgs source.

2. Read the patch. It has two parts:

   | File | Change | Effect |
   |---|---|---|
   | `gcc/cppdefault.cc` | `#undef LOCAL_INCLUDE_DIR` | No `/usr/local/include` |
   | `gcc/gcc.cc` | `STANDARD_STARTFILE_PREFIX_1` and `_2` become `""` | No `/lib/` or `/usr/lib/` for `crt*.o` and libraries |

3. Add it to the derivation. `./no-sys-dirs.patch` is a path, not a string.
   Nix copies the file into the store and gives the store path to the build.

   ```nix
   patches = [ ./no-sys-dirs.patch ];
   ```

4. The patch does not remove `/usr/include`. That directory comes from
   `NATIVE_SYSTEM_HEADER_DIR`, a configure setting. Point it at the glibc of
   8a. nixpkgs does the same (`pkgs/development/compilers/gcc/common/configure-flags.nix`).
   Add `glibc` to the arguments, and give it in `lfs-temp/default.nix`.

   ```nix
   "--with-native-system-header-dir=${glibc}/include"
   ```

5. Test the patch before the full build. A test takes seconds, and a gcc
   build takes much longer. Run this in the container:

   ```console
   $ cd $(mktemp -d)
   $ tar xf $(nix build --no-link --print-out-paths /work#temp.gcc.src) gcc-14.2.0/gcc/cppdefault.cc gcc-14.2.0/gcc/gcc.cc
   $ cd gcc-14.2.0
   $ nix shell nixpkgs#gnupatch -c patch -p1 --dry-run < /work/lfs-temp/gcc/no-sys-dirs.patch
   checking file gcc/cppdefault.cc
   checking file gcc/gcc.cc
   Hunk #1 succeeded at 1604 (offset 442 lines).
   ```

   An offset is correct. The patch was made for an older gcc, so the lines
   moved. `FAILED` is an error.

In the build log, look for `applying patch /nix/store/...-no-sys-dirs.patch`,
then `patching file gcc/cppdefault.cc` and `patching file gcc/gcc.cc`.

**Verify:**

```console
$ nix build .#temp.gcc -o result-temp-gcc -L
$ result-temp-gcc/bin/gcc -v 2>&1 | grep -E '^(Target|Configured)'
                                                   # Target: aarch64-lfs-linux-gnu, --host=aarch64-lfs-linux-gnu
$ file result-temp-gcc/bin/gcc $(result-temp-gcc/bin/gcc -print-prog-name=cc1)
                                                   # both statically linked
$ echo | result-temp-gcc/bin/gcc -E -v - 2>&1 | sed -n '/search starts/,/End of search/p'
                                                   # no /usr/local/include (the patch), no /usr/include
                                                   # (the header directory flag), the glibc include directory
$ result-temp-gcc/bin/gcc -print-search-dirs | grep ^libraries | tr : '\n'
                                                   # no entry starts with /lib/ or /usr/lib/ (the patch)
$ printf '#include <limits.h>\nint x = PATH_MAX;\n' | result-temp-gcc/bin/gcc -fsyntax-only -x c -
                                                   # no output (the full limits.h)
$ nix path-info -r ./result-temp-gcc               # two lines: gcc and lfs-temp-glibc
```

The closure contains glibc because gcc stores the header directory path.
`-fsyntax-only` stops after the parse, so gcc does not need `as`. A full
compile and link needs the wrappers of step 9.

**If it fails:**

- `cannot find -lc` when gcc links a program such as `genmodes`:
  `LDFLAGS_FOR_BUILD` is not empty, so the host programs link with `-static`.
- `error: 'PATH_MAX' undeclared`: the `postInstall` step did not run, or it
  wrote the wrong file.
- `nix path-info -r` shows `bash`, `gnused` or a nixpkgs `glibc`: find the
  file with `nix why-depends ./result-temp-gcc /nix/store/...-bash-...`. If it
  is in `install-tools`, check the `rm` line.

- `Hunk #1 FAILED at ...`: the patch does not match this gcc version. Look in
  `pkgs/development/compilers/gcc/patches/default.nix` for the patch that
  nixpkgs uses with your gcc version.
- `error: path '.../no-sys-dirs.patch' does not exist`: git does not track the
  file. Run `git add`.

**Nix concepts:** [multiple outputs](appendix-nix-concepts.md#multiple-outputs-libgetdev-libgetlib),
[patches](appendix-nix-concepts.md#patches).
